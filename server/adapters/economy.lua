MZJobsEconomyAdapter = MZJobsEconomyAdapter or {}

-- No public economy contract currently reserves finite job budgets or settles
-- them atomically. Advertising this as unavailable prevents a local escrow.
function MZJobsEconomyAdapter.Capabilities()
  local running = type(GetResourceState) == 'function'
    and GetResourceState('mz_economy') == 'started'
  return {
    resourceStarted = running,
    budgetHold = false,
    budgetRelease = false,
    settlement = false,
    receipt = false,
    reason = 'canonical_contract_missing'
  }
end
