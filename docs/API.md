# MZ Jobs — API da fundação

## Contratos públicos reais

### `exports['mz_jobs']:GetJobsReadiness()`

Retorna:

```lua
{
  schemaVersion = 1,
  enabled = false,
  ready = false,
  schemaReady = false,
  reason = 'disabled',
  startedAt = 0
}
```

Read-only. Não aceita payload e não publica trabalhos.

### `exports['mz_jobs']:GetJobsCapabilities()`

Retorna capacidades efetivas. `publicMutationApi` e `playableJobs` são sempre `false` nesta Wave. Economy anuncia `budgetHold=false`/`settlement=false`; inventory anuncia `custody*=false`. Esses valores não simulam sucesso.

## API interna server-side

`MZJobsService.AcceptOffer(source, intent)` existe para compor/testar a fundação, mas não é export nem evento. O intent fechado contém somente:

```lua
{ offerId = 'opaque', operationKey = '16..128 token', expectedVersion = 1 }
```

`source`, `citizenid`, `sessionId`, estado vital, definição, compensation e capabilities são resolvidos no servidor. Chaves extras — inclusive `money`, `amountMinor`, `item`, `coords` e `citizenid` — retornam `invalid_payload`.

## APIs futuras — não existem

| Owner | Capacidade necessária | Estado |
|---|---|---|
| `mz_economy` | hold/release de budget finito e settlement atômico com receipt | `BLOCKED` |
| `mz_inventory` | reserve/commit/cancel de custody com receipt | `BLOCKED` |
| `mz_population` | demanda mutável/trabalho virtual | `NOT IMPLEMENTED` |
| `mz_org` | elegibilidade de contrato organizacional | `NOT IMPLEMENTED` |

Não usar `AddMoney`, `RemoveMoney`, `AddPlayerItem` ou `RemovePlayerItem` como substitutos.

## Estados

- oferta: `draft`, `published`, `reserved`, `accepted`, `expired`, `cancelled`;
- execução: `accepted`, `in_progress`, `settlement_pending`, `completed`, `cancelled`, `failed_review`.

`completed` sempre exige prova de conclusão verificada. Recibos canônicos são obrigatórios somente quando a execução declara `requiresInventory`/`requiresSettlement`; por isso serviço explicitamente sem contraprestação e sem custódia possui semântica própria. Como não há endpoint público de conclusão nesta Wave, nenhum desses caminhos concede recompensa ou XP.
