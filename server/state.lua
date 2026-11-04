MZJobsState = MZJobsState or {
  enabled = false,
  ready = false,
  schemaReady = false,
  reason = 'not_started',
  startedAt = os.time()
}

function MZJobsState.Set(enabled, schemaReady, reason)
  MZJobsState.enabled = enabled == true
  MZJobsState.schemaReady = schemaReady == true
  MZJobsState.ready = enabled == true and schemaReady == true and reason == 'ready'
  MZJobsState.reason = MZJobsContracts.SanitizeError(reason or 'unavailable')
end

function MZJobsState.Snapshot()
  return {
    schemaVersion = MZJobsContracts.SchemaVersion,
    enabled = MZJobsState.enabled == true,
    ready = MZJobsState.ready == true,
    schemaReady = MZJobsState.schemaReady == true,
    reason = MZJobsState.reason,
    startedAt = MZJobsState.startedAt
  }
end
