MZJobsCoreAdapter = MZJobsCoreAdapter or {}

local function started()
  return type(GetResourceState) == 'function' and GetResourceState('mz_core') == 'started'
end

function MZJobsCoreAdapter.Capabilities()
  return {
    ready = started(),
    identity = started(),
    playerState = started(),
    source = 'mz_core'
  }
end

function MZJobsCoreAdapter.ResolveIdentity(source)
  source = tonumber(source)
  if not source or source <= 0 then return nil, 'invalid_source' end
  if not started() then return nil, 'core_unavailable' end
  local ok, result = pcall(function()
    return exports['mz_core']:ResolvePlayerIdentity(source)
  end)
  if not ok or type(result) ~= 'table' or result.ok ~= true
      or not result.citizenid or not result.sessionId then
    return nil, type(result) == 'table' and result.error or 'identity_unavailable'
  end
  return {
    source = source,
    citizenid = tostring(result.citizenid),
    accountId = result.accountId,
    characterId = result.characterId,
    sessionId = tostring(result.sessionId)
  }
end

function MZJobsCoreAdapter.GetPlayerState(source)
  if not started() then return nil, 'core_unavailable' end
  local callOk, ok, result = pcall(function()
    return exports['mz_core']:GetPlayerState(source)
  end)
  if not callOk or ok ~= true or type(result) ~= 'table' or type(result.state) ~= 'table' then
    local reason = type(result) == 'table' and result.code or 'player_state_unavailable'
    return nil, reason
  end
  return result.state
end
