local function printStatus(message)
  print(('[mz_jobs] %s'):format(tostring(message)))
end

if MZJobsConfig.Enabled ~= true then
  MZJobsState.Set(false, false, 'disabled')
  printStatus('disabled; no schema check, writer or worker started')
else
  MySQL.ready(function()
    local core = MZJobsCoreAdapter.Capabilities()
    if core.ready ~= true then
      MZJobsState.Set(true, false, 'core_unavailable')
      printStatus('unavailable: core_unavailable')
      return
    end
    local prepared, prepareError = MZJobsRepository.Prepare()
    if not prepared then
      MZJobsState.Set(true, false, prepareError)
      printStatus(('unavailable: %s'):format(MZJobsContracts.SanitizeError(prepareError)))
      return
    end
    MZJobsState.Set(true, true, 'ready')
    MZJobsReconciliation.Start()
    printStatus('foundation ready; playable jobs and public mutations remain disabled')
  end)
end

exports('GetJobsReadiness', function()
  return MZJobsService.GetReadiness()
end)

exports('GetJobsCapabilities', function()
  return MZJobsService.GetCapabilities()
end)

AddEventHandler('onResourceStop', function(resourceName)
  if resourceName == GetCurrentResourceName() then MZJobsReconciliation.Stop() end
end)
