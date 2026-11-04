MZJobsReconciliation = MZJobsReconciliation or {}

local Reconciliation = MZJobsReconciliation
local running = false
local maximumAttempts = 5
local intervalMs = 30000

local function delay(attempt)
  return math.min(900, 2 ^ math.max(0, math.floor(tonumber(attempt) or 1) - 1))
end

function Reconciliation.RunOnce(repository, handlers)
  repository = repository or MZJobsRepository
  handlers = type(handlers) == 'table' and handlers or {}
  local rows = repository.ListDueOutbox(10)
  local summary = { inspected = #rows, applied = 0, retried = 0, failed = 0 }

  for _, row in ipairs(rows) do
    local attempt = (tonumber(row.attempts) or 0) + 1
    if repository.ClaimOutbox(row.id) then
      local handler = handlers[tostring(row.topic or '')]
      local ok, result, reason
      if type(handler) == 'function' then
        ok, result, reason = pcall(handler, repository.DecodePayload(row.payload_json), row)
        ok = ok and result == true
      else
        ok, reason = false, 'outbox_handler_missing'
      end
      if ok then
        repository.MarkOutboxApplied(row.id)
        summary.applied = summary.applied + 1
      elseif attempt >= maximumAttempts then
        repository.MarkOutboxFailed(row.id, reason or 'outbox_failed')
        summary.failed = summary.failed + 1
      else
        repository.MarkOutboxRetry(row.id, reason or 'outbox_retry', delay(attempt))
        summary.retried = summary.retried + 1
      end
    end
  end
  return summary
end

function Reconciliation.Start()
  if running or MZJobsState.ready ~= true then return false end
  running = true
  CreateThread(function()
    MZJobsRepository.RecoverExpiredReservations()
    while running and MZJobsState.ready == true do
      Reconciliation.RunOnce()
      Wait(intervalMs)
    end
  end)
  return true
end

function Reconciliation.Stop()
  running = false
end
