MZJobsService = MZJobsService or {}

local function operationResult(operation)
  if type(operation) ~= 'table' then return nil end
  if operation.status == 'applied' then
    local ok, result = pcall(json.decode, tostring(operation.result_json or ''))
    if ok and type(result) == 'table' then
      result.replayed = true
      return result
    end
  end
  return nil
end

function MZJobsService.AcceptOffer(source, rawIntent)
  local context, policyError = MZJobsPolicy.AuthorizeAccept(source, rawIntent)
  if not context then return { ok = false, error = policyError } end

  local fingerprint = MZJobsContracts.AcceptFingerprint(context.intent, context.identity.citizenid)
  local existing = MZJobsRepository.GetOperation(context.identity.citizenid, context.intent.operationKey)
  if existing then
    if tostring(existing.request_fingerprint or '') ~= fingerprint
        or tostring(existing.operation_type or '') ~= 'accept_offer' then
      return { ok = false, error = 'idempotency_conflict' }
    end
    local replay = operationResult(existing)
    if replay then return replay end
    if existing.status == 'rejected' then
      return { ok = false, error = MZJobsContracts.SanitizeError(existing.error_code) }
    end
  end

  local offer = MZJobsRepository.GetOffer(context.intent.offerId)
  if not offer then return { ok = false, error = 'offer_not_found' } end
  local decodeOk, definition = pcall(json.decode, tostring(offer.definition_json or ''))
  if not decodeOk then return { ok = false, error = 'invalid_offer_definition' } end
  local normalized, capabilityError = MZJobsPolicy.CheckOfferCapabilities(definition)
  if not normalized then return { ok = false, error = capabilityError } end

  local result, acceptError = MZJobsRepository.AcceptOfferAtomic({
    offer = offer,
    intent = context.intent,
    identity = context.identity,
    fingerprint = fingerprint,
    definition = normalized,
    executionPublicId = existing and existing.aggregate_id or MZJobsContracts.NewPublicId('exec')
  })
  if not result then return { ok = false, error = MZJobsContracts.SanitizeError(acceptError) } end
  return result
end

function MZJobsService.GetReadiness()
  return MZJobsState.Snapshot()
end

function MZJobsService.GetCapabilities()
  return {
    schemaVersion = MZJobsContracts.SchemaVersion,
    enabled = MZJobsState.enabled == true,
    ready = MZJobsState.ready == true,
    offerExecutionFoundation = MZJobsState.ready == true,
    publicMutationApi = false,
    playableJobs = false,
    economy = MZJobsEconomyAdapter.Capabilities(),
    inventory = MZJobsInventoryAdapter.Capabilities(),
    core = MZJobsCoreAdapter.Capabilities()
  }
end
