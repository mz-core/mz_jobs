MZJobsInventoryAdapter = MZJobsInventoryAdapter or {}

-- Generic AddPlayerItem/RemovePlayerItem calls are deliberately not used: they
-- do not provide the durable, owner-scoped custody receipt required by jobs.
function MZJobsInventoryAdapter.Capabilities()
  local running = type(GetResourceState) == 'function'
    and GetResourceState('mz_inventory') == 'started'
  return {
    resourceStarted = running,
    custodyReserve = false,
    custodyCommit = false,
    custodyCancel = false,
    receipt = false,
    reason = 'canonical_contract_missing'
  }
end
