MZJobsPolicy = MZJobsPolicy or {}

function MZJobsPolicy.AuthorizeAccept(source, rawIntent)
  if MZJobsState.enabled ~= true then return nil, 'feature_disabled' end
  if MZJobsState.ready ~= true then return nil, MZJobsState.reason or 'service_unavailable' end

  local intent, intentError = MZJobsContracts.ValidateAcceptIntent(rawIntent)
  if not intent then return nil, intentError end

  local identity, identityError = MZJobsCoreAdapter.ResolveIdentity(source)
  if not identity then return nil, MZJobsContracts.SanitizeError(identityError) end
  local state, stateError = MZJobsCoreAdapter.GetPlayerState(source)
  if not state then return nil, MZJobsContracts.SanitizeError(stateError) end
  if tostring(state.deathState or 'alive') ~= 'alive' then return nil, 'player_action_blocked' end

  return { intent = intent, identity = identity }
end

function MZJobsPolicy.CheckOfferCapabilities(definition)
  local normalized, definitionError = MZJobsContracts.ValidateOfferDefinition(definition)
  if not normalized then return nil, definitionError end
  if normalized.compensation.mode == 'financial'
      or normalized.capabilities.requiresSettlement == true then
    return nil, 'budget_contract_unavailable'
  end
  if normalized.capabilities.requiresInventory == true then
    return nil, 'custody_contract_unavailable'
  end
  return normalized
end
