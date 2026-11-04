MZJobsContracts = MZJobsContracts or {}

local Contracts = MZJobsContracts

Contracts.SchemaVersion = 1
Contracts.Limits = {
  publicId = 32,
  token = 64,
  operationKey = 128,
  stages = 16,
  stageCode = 64,
  ttlSeconds = 7 * 24 * 60 * 60
}

Contracts.JobCategories = {
  logistics_route = true,
  service_intervention = true,
  production_collection = true,
  clandestine_contract = true
}

Contracts.JobKinds = { autonomous = true, organization = true, virtual = true }
Contracts.Legalities = { legal = true, illegal = true }
Contracts.StageTypes = {
  pickup = true,
  transport = true,
  deliver = true,
  inspect = true,
  repair = true,
  interact = true,
  ['return'] = true
}
Contracts.CapabilityFlags = {
  requiresOrigin = true,
  requiresDestination = true,
  requiresInventory = true,
  requiresVehicle = true,
  requiresOrganization = true,
  requiresSettlement = true,
  allowsVirtualWorker = true
}
Contracts.OfferStates = {
  draft = true, published = true, reserved = true, accepted = true,
  expired = true, cancelled = true
}
Contracts.ExecutionStates = {
  accepted = true, in_progress = true, settlement_pending = true,
  completed = true, cancelled = true, failed_review = true
}

local offerTransitions = {
  draft = { published = true, cancelled = true },
  published = { reserved = true, expired = true, cancelled = true },
  reserved = { published = true, accepted = true, expired = true, cancelled = true }
}

local executionTransitions = {
  accepted = { in_progress = true, cancelled = true, failed_review = true },
  in_progress = {
    settlement_pending = true, completed = true, cancelled = true, failed_review = true
  },
  settlement_pending = { completed = true, failed_review = true }
}

local function trim(value)
  return tostring(value or ''):gsub('^%s+', ''):gsub('%s+$', '')
end

local function integer(value, minimum, maximum)
  local number = tonumber(value)
  if not number or number ~= number or number == math.huge or number == -math.huge
      or number % 1 ~= 0 or number < minimum or number > maximum then return nil end
  return math.floor(number)
end

local function token(value, minimum, maximum)
  value = trim(value)
  if #value < minimum or #value > maximum or not value:match('^[%w_.:%-]+$') then return nil end
  return value
end

local function closed(value, allowed)
  if type(value) ~= 'table' then return false end
  for key in pairs(value) do if allowed[key] ~= true then return false end end
  return true
end

local function clone(value, seen)
  if type(value) ~= 'table' then return value end
  seen = seen or {}
  if seen[value] then return nil end
  seen[value] = true
  local out = {}
  for key, item in pairs(value) do out[clone(key, seen)] = clone(item, seen) end
  seen[value] = nil
  return out
end

function Contracts.Clone(value)
  return clone(value)
end

function Contracts.Token(value, minimum, maximum)
  return token(value, minimum or 1, maximum or Contracts.Limits.token)
end

function Contracts.Integer(value, minimum, maximum)
  return integer(value, minimum or 0, maximum or 9007199254740991)
end

function Contracts.CanTransitionOffer(fromState, toState)
  return offerTransitions[tostring(fromState or '')]
    and offerTransitions[tostring(fromState or '')][tostring(toState or '')] == true
end

function Contracts.CanTransitionExecution(fromState, toState, proof)
  if not (executionTransitions[tostring(fromState or '')]
      and executionTransitions[tostring(fromState or '')][tostring(toState or '')] == true) then
    return false, 'invalid_execution_transition'
  end
  if toState == 'settlement_pending' and (type(proof) ~= 'table' or proof.verified ~= true) then
    return false, 'completion_proof_required'
  end
  if toState == 'completed' then
    if type(proof) ~= 'table' or proof.verified ~= true then
      return false, 'completion_proof_required'
    end
    if (proof.requiresSettlement == true and proof.settlementReceipt ~= true)
        or (proof.requiresCustody == true and proof.custodyReceipt ~= true) then
      return false, 'owner_receipts_required'
    end
  end
  return true
end

function Contracts.ValidateAcceptIntent(value)
  local allowed = { offerId = true, operationKey = true, expectedVersion = true }
  if not closed(value, allowed) then return nil, 'invalid_payload' end
  local offerId = token(value.offerId, 8, Contracts.Limits.publicId)
  local operationKey = token(value.operationKey, 16, Contracts.Limits.operationKey)
  local expectedVersion = integer(value.expectedVersion, 1, 2147483647)
  if not offerId then return nil, 'invalid_offer_id' end
  if not operationKey then return nil, 'invalid_operation_key' end
  if not expectedVersion then return nil, 'invalid_version' end
  return { offerId = offerId, operationKey = operationKey, expectedVersion = expectedVersion }
end

function Contracts.ValidateOfferDefinition(value)
  local allowed = {
    schemaVersion = true, templateId = true, category = true, kind = true,
    legality = true, stages = true, capabilities = true, compensation = true
  }
  if not closed(value, allowed) then return nil, 'invalid_offer_definition' end
  if value.schemaVersion ~= Contracts.SchemaVersion then return nil, 'unsupported_schema_version' end

  local normalized = {
    schemaVersion = Contracts.SchemaVersion,
    templateId = token(value.templateId, 3, Contracts.Limits.token),
    category = token(value.category, 3, Contracts.Limits.token),
    kind = token(value.kind, 3, 24),
    legality = token(value.legality, 3, 16),
    stages = {},
    capabilities = {},
    compensation = { mode = 'none' }
  }
  if not normalized.templateId or not Contracts.JobCategories[normalized.category]
      or not Contracts.JobKinds[normalized.kind] or not Contracts.Legalities[normalized.legality] then
    return nil, 'invalid_offer_definition'
  end
  if type(value.stages) ~= 'table' or #value.stages < 1 or #value.stages > Contracts.Limits.stages then
    return nil, 'invalid_stages'
  end

  local stageIds = {}
  for index, stage in ipairs(value.stages) do
    if not closed(stage, { code = true, type = true }) then return nil, 'invalid_stage' end
    local code = token(stage.code, 2, Contracts.Limits.stageCode)
    local stageType = token(stage.type, 2, 24)
    if not code or stageIds[code] or not Contracts.StageTypes[stageType] then
      return nil, 'invalid_stage'
    end
    stageIds[code] = true
    normalized.stages[index] = { code = code, type = stageType }
  end

  if value.capabilities ~= nil and type(value.capabilities) ~= 'table' then
    return nil, 'invalid_capabilities'
  end
  for key, enabled in pairs(value.capabilities or {}) do
    if not Contracts.CapabilityFlags[key] or type(enabled) ~= 'boolean' then
      return nil, 'invalid_capabilities'
    end
    normalized.capabilities[key] = enabled
  end

  if value.compensation ~= nil then
    if not closed(value.compensation, { mode = true, budgetHoldRef = true }) then
      return nil, 'invalid_compensation'
    end
    local mode = token(value.compensation.mode, 3, 16)
    if mode ~= 'none' and mode ~= 'financial' then return nil, 'invalid_compensation' end
    normalized.compensation.mode = mode
    if mode == 'financial' then
      normalized.compensation.budgetHoldRef = token(value.compensation.budgetHoldRef, 8, 128)
      if not normalized.compensation.budgetHoldRef then return nil, 'budget_hold_required' end
      normalized.capabilities.requiresSettlement = true
    elseif value.compensation.budgetHoldRef ~= nil then
      return nil, 'invalid_compensation'
    end
  end

  return normalized
end

function Contracts.AcceptFingerprint(intent, citizenid)
  return ('offer=%s;version=%d;citizenid=%s'):format(
    tostring(intent.offerId), tonumber(intent.expectedVersion), tostring(citizenid)
  )
end

function Contracts.NewPublicId(prefix)
  prefix = token(prefix, 2, 8) or 'job'
  local timer = type(GetGameTimer) == 'function' and GetGameTimer() or 0
  return ('%s_%08x%08x%08x'):format(
    prefix, os.time() % 0xffffffff, timer % 0xffffffff, math.random(0, 0xffffffff)
  ):sub(1, Contracts.Limits.publicId)
end

function Contracts.SanitizeError(value)
  return token(value, 2, 64) or 'internal_error'
end
