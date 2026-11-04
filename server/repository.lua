MZJobsRepository = MZJobsRepository or {}

local Repository = MZJobsRepository
local state = { ready = false, reason = 'not_prepared' }

local expectedColumns = {
  mz_jobs_offers = {
    'id', 'public_id', 'schema_version', 'template_id', 'category', 'kind', 'legality',
    'status', 'definition_json', 'compensation_mode', 'budget_hold_ref',
    'reserved_by_citizenid', 'reservation_operation_key', 'reserved_until',
    'accept_until', 'expires_at', 'version', 'created_at', 'updated_at'
  },
  mz_jobs_executions = {
    'id', 'public_id', 'offer_id', 'citizenid', 'accepted_session_id', 'status',
    'stage_code', 'requires_custody', 'requires_settlement', 'snapshot_json',
    'version', 'accepted_at', 'expires_at', 'completed_at', 'created_at', 'updated_at'
  },
  mz_jobs_operations = {
    'id', 'source_resource', 'actor_citizenid', 'operation_key', 'operation_type',
    'request_fingerprint', 'aggregate_type', 'aggregate_id', 'status', 'result_json',
    'error_code', 'created_at', 'updated_at'
  },
  mz_jobs_events = {
    'id', 'aggregate_type', 'aggregate_id', 'sequence_no', 'event_type',
    'actor_citizenid', 'operation_key', 'payload_json', 'created_at'
  },
  mz_jobs_outbox = {
    'id', 'topic', 'dedupe_key', 'aggregate_type', 'aggregate_id', 'payload_json',
    'status', 'attempts', 'next_attempt_at', 'lease_until', 'processed_at',
    'last_error', 'created_at', 'updated_at'
  },
  mz_jobs_reputation = {
    'citizenid', 'track_id', 'xp', 'level', 'version', 'updated_at'
  }
}

local function encode(value)
  local ok, result = pcall(json.encode, type(value) == 'table' and value or {})
  return ok and result or '{}'
end

local function decode(value)
  local ok, result = pcall(json.decode, tostring(value or ''))
  return ok and type(result) == 'table' and result or nil
end

local function mysqlReady()
  return type(MySQL) == 'table'
    and type(MySQL.query) == 'table' and type(MySQL.query.await) == 'function'
    and type(MySQL.single) == 'table' and type(MySQL.single.await) == 'function'
    and type(MySQL.update) == 'table' and type(MySQL.update.await) == 'function'
    and type(MySQL.insert) == 'table' and type(MySQL.insert.await) == 'function'
    and type(MySQL.transaction) == 'table' and type(MySQL.transaction.await) == 'function'
end

function Repository.Status()
  return { ready = state.ready == true, reason = state.reason }
end

function Repository.Prepare()
  state.ready = false
  if MZJobsConfig.Enabled ~= true then state.reason = 'disabled' return false, state.reason end
  if not mysqlReady() then state.reason = 'mysql_unavailable' return false, state.reason end

  local names = {}
  for name in pairs(expectedColumns) do names[#names + 1] = name end
  table.sort(names)
  local placeholders = {}
  for index = 1, #names do placeholders[index] = '?' end
  local ok, rows = pcall(MySQL.query.await, ([[
    SELECT TABLE_NAME AS table_name, COLUMN_NAME AS column_name
    FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME IN (%s)
  ]]):format(table.concat(placeholders, ', ')), names)
  if not ok or type(rows) ~= 'table' then
    state.reason = 'schema_check_failed'
    return false, state.reason
  end

  local found = {}
  for _, row in ipairs(rows) do
    local tableName, columnName = tostring(row.table_name or ''), tostring(row.column_name or '')
    found[tableName] = found[tableName] or {}
    found[tableName][columnName] = true
  end
  for tableName, columns in pairs(expectedColumns) do
    if not found[tableName] then state.reason = 'schema_unavailable' return false, state.reason end
    for _, columnName in ipairs(columns) do
      if not found[tableName][columnName] then
        state.reason = 'schema_invalid'
        return false, state.reason
      end
    end
  end

  state.ready, state.reason = true, 'ready'
  return true
end

local function requireReady()
  return state.ready == true
end

function Repository.GetOffer(publicId)
  if not requireReady() then return nil end
  return MySQL.single.await([[
    SELECT * FROM mz_jobs_offers WHERE public_id = ? LIMIT 1
  ]], { tostring(publicId or '') })
end

function Repository.GetOperation(citizenid, operationKey)
  if not requireReady() then return nil end
  return MySQL.single.await([[
    SELECT * FROM mz_jobs_operations
    WHERE source_resource = 'mz_jobs' AND actor_citizenid = ? AND operation_key = ?
    LIMIT 1
  ]], { tostring(citizenid or ''), tostring(operationKey or '') })
end

local function ensureOperation(input)
  MySQL.insert.await([[
    INSERT IGNORE INTO mz_jobs_operations
      (source_resource, actor_citizenid, operation_key, operation_type,
       request_fingerprint, aggregate_type, aggregate_id, status)
    VALUES ('mz_jobs', ?, ?, 'accept_offer', ?, 'execution', ?, 'pending')
  ]], {
    input.identity.citizenid, input.intent.operationKey,
    input.fingerprint, input.executionPublicId
  })
  return Repository.GetOperation(input.identity.citizenid, input.intent.operationKey)
end

local function rejectOperation(input, reason)
  MySQL.update.await([[
    UPDATE mz_jobs_operations SET status = 'rejected', error_code = ?
    WHERE source_resource = 'mz_jobs' AND actor_citizenid = ?
      AND operation_key = ? AND status = 'pending'
  ]], { reason, input.identity.citizenid, input.intent.operationKey })
end

local function decodeApplied(operation)
  if type(operation) ~= 'table' or operation.status ~= 'applied' then return nil end
  local result = decode(operation.result_json)
  if result then result.replayed = true end
  return result
end

local function reserveOffer(input)
  local affected = MySQL.update.await([[
    UPDATE mz_jobs_offers
    SET status = 'reserved', reserved_by_citizenid = ?, reservation_operation_key = ?,
      reserved_until = DATE_ADD(UTC_TIMESTAMP(3), INTERVAL 30 SECOND), version = version + 1
    WHERE public_id = ? AND status = 'published' AND version = ?
      AND accept_until > UTC_TIMESTAMP(3) AND expires_at > UTC_TIMESTAMP(3)
  ]], {
    input.identity.citizenid, input.intent.operationKey,
    input.intent.offerId, input.intent.expectedVersion
  })
  return (tonumber(affected) or 0) == 1
end

local function ownsReservation(offer, input)
  return type(offer) == 'table' and offer.status == 'reserved'
    and tostring(offer.reserved_by_citizenid or '') == input.identity.citizenid
    and tostring(offer.reservation_operation_key or '') == input.intent.operationKey
end

local function finalizeAcceptance(input, offer)
  local execution = {
    publicId = input.executionPublicId,
    offerId = tonumber(offer.id),
    citizenid = input.identity.citizenid,
    sessionId = input.identity.sessionId,
    status = 'accepted',
    stage = input.definition.stages[1].code,
    requiresCustody = input.definition.capabilities.requiresInventory == true,
    requiresSettlement = input.definition.capabilities.requiresSettlement == true,
    snapshotJson = encode(input.definition),
    expiresAt = offer.expires_at
  }
  local result = {
    ok = true,
    replayed = false,
    execution = {
      publicId = execution.publicId,
      offerId = input.intent.offerId,
      status = execution.status,
      stage = execution.stage,
      version = 1
    }
  }
  local resultJson = encode(result)
  local eventJson = encode({
    offerId = input.intent.offerId,
    status = execution.status,
    stage = execution.stage,
    version = 1
  })

  local ok, committed = pcall(MySQL.transaction.await, {
    {
      query = [[
        INSERT INTO mz_jobs_executions
          (public_id, offer_id, citizenid, accepted_session_id, status, stage_code,
           requires_custody, requires_settlement, snapshot_json, version,
           accepted_at, expires_at)
        SELECT ?, id, ?, ?, 'accepted', ?, ?, ?, ?, 1, UTC_TIMESTAMP(3), expires_at
        FROM mz_jobs_offers
        WHERE id = ? AND status = 'reserved' AND reserved_by_citizenid = ?
          AND reservation_operation_key = ? AND reserved_until > UTC_TIMESTAMP(3)
      ]],
      parameters = {
        execution.publicId, execution.citizenid, execution.sessionId,
        execution.stage, execution.requiresCustody and 1 or 0,
        execution.requiresSettlement and 1 or 0, execution.snapshotJson,
        execution.offerId, execution.citizenid, input.intent.operationKey
      }
    },
    {
      query = [[
        UPDATE mz_jobs_offers
        SET status = 'accepted', reserved_until = NULL, version = version + 1
        WHERE id = ? AND status = 'reserved' AND reserved_by_citizenid = ?
          AND reservation_operation_key = ?
          AND EXISTS (SELECT 1 FROM mz_jobs_executions WHERE public_id = ?)
      ]],
      parameters = {
        execution.offerId, execution.citizenid, input.intent.operationKey, execution.publicId
      }
    },
    {
      query = [[
        UPDATE mz_jobs_operations SET status = 'applied', result_json = ?, error_code = NULL
        WHERE source_resource = 'mz_jobs' AND actor_citizenid = ?
          AND operation_key = ? AND request_fingerprint = ? AND status = 'pending'
          AND EXISTS (SELECT 1 FROM mz_jobs_executions WHERE public_id = ?)
      ]],
      parameters = {
        resultJson, execution.citizenid, input.intent.operationKey, input.fingerprint,
        execution.publicId
      }
    },
    {
      query = [[
        INSERT INTO mz_jobs_events
          (aggregate_type, aggregate_id, sequence_no, event_type,
           actor_citizenid, operation_key, payload_json)
        SELECT 'execution', public_id, 1, 'execution_accepted', ?, ?, ?
        FROM mz_jobs_executions WHERE public_id = ? AND offer_id = ?
      ]],
      parameters = {
        execution.citizenid, input.intent.operationKey, eventJson,
        execution.publicId, execution.offerId
      }
    }
  })
  local operation = Repository.GetOperation(execution.citizenid, input.intent.operationKey)
  if not ok or committed ~= true then
    local replay = decodeApplied(operation)
    if replay then return replay end
    return nil, 'operation_pending'
  end
  if type(operation) ~= 'table' or operation.status ~= 'applied' then
    return nil, 'operation_pending'
  end
  local applied = decode(operation.result_json)
  if applied then return applied end
  return nil, 'operation_pending'
end

function Repository.AcceptOfferAtomic(input)
  if not requireReady() then return nil, 'repository_unavailable' end
  local operation = ensureOperation(input)
  if not operation then return nil, 'operation_unavailable' end
  if tostring(operation.operation_type or '') ~= 'accept_offer'
      or tostring(operation.request_fingerprint or '') ~= input.fingerprint then
    return nil, 'idempotency_conflict'
  end
  local replay = decodeApplied(operation)
  if replay then return replay end
  if operation.status == 'rejected' then return nil, operation.error_code or 'operation_rejected' end

  input.executionPublicId = tostring(operation.aggregate_id or input.executionPublicId)
  local offer = Repository.GetOffer(input.intent.offerId)
  if not ownsReservation(offer, input) then
    if not reserveOffer(input) then
      operation = Repository.GetOperation(input.identity.citizenid, input.intent.operationKey)
      replay = decodeApplied(operation)
      if replay then return replay end
      rejectOperation(input, 'offer_unavailable')
      return nil, 'offer_unavailable'
    end
    offer = Repository.GetOffer(input.intent.offerId)
  end
  if not ownsReservation(offer, input) then return nil, 'operation_pending' end
  return finalizeAcceptance(input, offer)
end

function Repository.RecoverExpiredReservations()
  if not requireReady() then return false, 'repository_unavailable' end
  local ok, committed = pcall(MySQL.transaction.await, {
    {
      query = [[
        UPDATE mz_jobs_operations op
        INNER JOIN mz_jobs_offers offer
          ON offer.reservation_operation_key = op.operation_key
          AND offer.reserved_by_citizenid = op.actor_citizenid
        SET op.status = 'rejected', op.error_code = 'worker_restarted'
        WHERE op.source_resource = 'mz_jobs' AND op.status = 'pending'
          AND offer.status = 'reserved' AND offer.reserved_until <= UTC_TIMESTAMP(3)
      ]]
    },
    {
      query = [[
        UPDATE mz_jobs_offers
        SET status = CASE
            WHEN accept_until <= UTC_TIMESTAMP(3) OR expires_at <= UTC_TIMESTAMP(3)
              THEN 'expired' ELSE 'published' END,
          reserved_by_citizenid = NULL, reservation_operation_key = NULL,
          reserved_until = NULL, version = version + 1
        WHERE status = 'reserved' AND reserved_until <= UTC_TIMESTAMP(3)
      ]]
    },
    {
      query = [[
        UPDATE mz_jobs_offers SET status = 'expired', version = version + 1
        WHERE status = 'published'
          AND (accept_until <= UTC_TIMESTAMP(3) OR expires_at <= UTC_TIMESTAMP(3))
      ]]
    }
  })
  return ok == true and committed == true
end

function Repository.ListDueOutbox(limit)
  if not requireReady() then return {} end
  limit = math.max(1, math.min(50, math.floor(tonumber(limit) or 10)))
  return MySQL.query.await(([=[
    SELECT * FROM mz_jobs_outbox
    WHERE (
        status IN ('pending', 'retry')
        AND (next_attempt_at IS NULL OR next_attempt_at <= UTC_TIMESTAMP(3))
        AND (lease_until IS NULL OR lease_until <= UTC_TIMESTAMP(3))
      ) OR (status = 'processing' AND lease_until <= UTC_TIMESTAMP(3))
    ORDER BY id ASC LIMIT %d
  ]=]):format(limit)) or {}
end

function Repository.ClaimOutbox(id)
  local affected = MySQL.update.await([[
    UPDATE mz_jobs_outbox
    SET status = 'processing', attempts = attempts + 1,
      lease_until = DATE_ADD(UTC_TIMESTAMP(3), INTERVAL 30 SECOND)
    WHERE id = ? AND (
        (status IN ('pending', 'retry')
          AND (next_attempt_at IS NULL OR next_attempt_at <= UTC_TIMESTAMP(3))
          AND (lease_until IS NULL OR lease_until <= UTC_TIMESTAMP(3)))
        OR (status = 'processing' AND lease_until <= UTC_TIMESTAMP(3))
      )
  ]], { tonumber(id) })
  return (tonumber(affected) or 0) == 1
end

function Repository.MarkOutboxApplied(id)
  return (tonumber(MySQL.update.await([[
    UPDATE mz_jobs_outbox
    SET status = 'applied', processed_at = UTC_TIMESTAMP(3), lease_until = NULL,
      last_error = NULL
    WHERE id = ? AND status = 'processing'
  ]], { tonumber(id) })) or 0) == 1
end

function Repository.MarkOutboxFailed(id, reason)
  return (tonumber(MySQL.update.await([[
    UPDATE mz_jobs_outbox
    SET status = 'failed', lease_until = NULL, last_error = ?
    WHERE id = ? AND status = 'processing'
  ]], { MZJobsContracts.SanitizeError(reason), tonumber(id) })) or 0) == 1
end

function Repository.MarkOutboxRetry(id, reason, delaySeconds)
  delaySeconds = math.max(1, math.min(3600, math.floor(tonumber(delaySeconds) or 1)))
  local query = ([=[
    UPDATE mz_jobs_outbox
    SET status = 'retry', lease_until = NULL, last_error = ?,
      next_attempt_at = DATE_ADD(UTC_TIMESTAMP(3), INTERVAL %d SECOND)
    WHERE id = ? AND status = 'processing'
  ]=]):format(delaySeconds)
  return (tonumber(MySQL.update.await(query, {
    MZJobsContracts.SanitizeError(reason), tonumber(id)
  })) or 0) == 1
end

function Repository.DecodePayload(value)
  return decode(value)
end
