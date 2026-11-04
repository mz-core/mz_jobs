# MZ Framework — mz_jobs Wave 1 — relatório da fundação

Data da validação local: 2026-10-25. Escopo: fundação server-authoritative, desativada por padrão, sem emprego jogável, pagamento, custódia, NPC, UI ou reward event.

## Resultado executivo

A fundação foi criada dentro de `mz_jobs` e os harnesses novos foram centralizados em `mz_testkit`. O resource é `server_only`, começa com `MZJobsConfig.Enabled=false` e, nesse estado, não consulta schema, não inicia reconciliação e não escreve. A única superfície pública é read-only (`GetJobsReadiness` e `GetJobsCapabilities`).

Não houve alteração em `mz_core`, `mz_economy`, `mz_inventory`, `mz_population`, `mz_org`, `mz_phone`, `mz_starter`, `server.cfg` ou `ref/trabalhos`. Nenhum DDL foi executado.

## VERIFIED CODE

- O manifest declara somente scripts compartilhados/server e depende dos owners reais `mz_core`, `ox_lib` e `oxmysql`.
- O adapter Core usa os exports reais `ResolvePlayerIdentity` e `GetPlayerState`; `source` e `sessionId` permanecem efêmeros e `citizenid` é a identidade persistente.
- Economy e inventory anunciam `canonical_contract_missing` e todas as capabilities de hold/settlement/custody como `false`; não chamam mutações genéricas nem fabricam receipts.
- `AcceptOffer` não é export nem evento. O intent fechado aceita só `offerId`, `operationKey` e `expectedVersion`; campos extras, inclusive `citizenid`, `money`, `amountMinor`, `item` e `coords`, são recusados.
- Oferta e execução têm máquinas distintas. Reserva usa CAS por `status + version`, expiração persistida e operação idempotente com fingerprint. A criação da execução é condicionada à posse vigente da reserva na mesma transação; há unique de execução por oferta.
- Conclusão exige prova verificada. Se a execução exigir settlement ou custody, o receipt correspondente também é obrigatório; serviço explicitamente sem essas capacidades pode concluir sem inventar efeito externo.
- A reconciliação usa rows persistidas, lease de 30 s, polling de 30 s, máximo de cinco tentativas, backoff exponencial limitado e estado terminal `failed` para poison.
- O baseline contém somente seis `CREATE TABLE IF NOT EXISTS`, sem `DROP`, `ALTER`, `TRUNCATE` ou `DELETE`: offers, executions, operations, events, outbox e reputation.
- Os 13 arquivos Lua de `mz_jobs` passaram por `luac -p`; os dois locales passaram por parse JSON.

## LOCAL PASS

| Caso local | Resultado |
|---|---|
| contracts | PASS — 18 verificações |
| estados | PASS — 6 de oferta e 7 de execução |
| repository/service/policy | PASS — 11 de aceite e 5 de schema |
| reconciliação | PASS — retry 5, restart 1 e poison 1 |
| segurança | PASS — 18 gates |
| runner canônico `-Suite jobs` | PASS — 5/5 |
| regressão `-Suite economy` | PASS — 7/7 |

Cobertura elegível do plano Wave 0:

| Critério | Classificação | Evidência/limite |
|---:|---|---|
| 1–3 | LOCAL PASS | flag OFF, fail-closed de schema e contratos fechados/versionados |
| 4–10 | LOCAL PASS com mocks | aceite, single-winner CAS, replay, conflito de fingerprint, source/citizenid não autoritativos, sessão inválida e morto |
| 23–24 | LOCAL PASS parcial | restart/outbox persistente e terminal não reprocessado; sem runtime FiveM/owners, settlement real não existe |
| 26 | LOCAL PASS estrutural | CAS/TTL e recuperação persistida; concorrência MySQL real não foi executada |
| 29–31 | LOCAL PASS | bounds/payload fechado, poison bounded e ausência de integração com canaries |

Comandos executados:

```powershell
lua mz_testkit/tests/mz_jobs/contracts_harness.lua
lua mz_testkit/tests/mz_jobs/state_machine_harness.lua
lua mz_testkit/tests/mz_jobs/repository_harness.lua
lua mz_testkit/tests/mz_jobs/reconciliation_harness.lua
lua mz_testkit/tests/mz_jobs/security_harness.lua
powershell -NoProfile -ExecutionPolicy Bypass -File .\mz_testkit\runners\run-local-suite.ps1 -Suite jobs
powershell -NoProfile -ExecutionPolicy Bypass -File .\mz_testkit\runners\run-local-suite.ps1 -Suite economy
luac -p <cada arquivo Lua de mz_jobs>
```

## Regressões observadas

A execução individual das 26 entradas `mz_core` do registry produziu 24 PASS e duas falhas preexistentes, fora do escopo e sem arquivos do owner modificados:

- `test:mz_core:weapon_authority_contract_harness`;
- `test:mz_core:inventory_item_access_harness`.

Ambas chegam a `mz_inventory/server/service.lua:2602` (`attempt to call a nil value (global 'Player')`) durante o mock de `handlePlayerDropped`. O runner canônico `-Suite core` também interrompe cedo porque `$ErrorActionPreference='Stop'` promove a saída esperada em stderr de harnesses a `NativeCommandError`; por isso a contagem acima foi obtida executando as entradas individualmente, sem alterar runner/owner para mascarar o problema.

O registry já tinha inconsistência de metadado antes desta Wave: `registeredEntries=64` para 62 entradas reais. As cinco entradas de jobs foram adicionadas (67 reais no arquivo), mas esse campo e `lastExtendedBy` foram preservados para não sobrescrever estado alheio em andamento.

## NOT RUN

- FiveM/OneSync/CEF real;
- MySQL/oxmysql real, concorrência real de transações e aplicação do baseline;
- restart/reconnect real de resource/servidor;
- chamadas reais entre `mz_jobs` e owners;
- emprego, stages espaciais, routing bucket, veículo, target/radial, NUI, NPC, crime, recompensa ou XP.

Nenhum item acima deve ser interpretado como runtime PASS.

## BLOCKED

### `mz_economy`

Falta contrato canônico do owner para hold de orçamento finito, consulta/replay, release e settlement idempotente com receipt. Até existir, ofertas financeiras ou com `requiresSettlement=true` são recusadas com `budget_contract_unavailable`.

### `mz_inventory`

Falta contrato canônico do owner para reserve/commit/cancel de custody e consulta/replay de receipt. Até existir, ofertas com `requiresInventory=true` são recusadas com `custody_contract_unavailable`.

Nenhum bridge, escrow, saldo, item ou receipt local foi criado para contornar esses bloqueios.

## ADRs

Decisões fechadas estão em `docs/DECISIONS.md`:

1. ownership restrito a oferta, execução, stages e reputação profissional;
2. ciclos separados para oferta e execução;
3. categorias/stages estruturais e capabilities opcionais;
4. reputação profissional distinta de skills;
5. redução do desenho de oito para seis tabelas;
6. SQL manual e resource OFF por padrão;
7. superfície pública somente diagnóstica/read-only.

Permanecem pendentes os contratos de budget/settlement e custody, além de população, UI e crime.

## Schema e staging

O arquivo `sql/001_mz_jobs_baseline.sql` é CREATE-only e deve ser aplicado manualmente em staging:

1. confirmar ausência de schema divergente;
2. gerar backup verificável e registrar o restore;
3. aplicar o baseline com credencial operacional autorizada;
4. conferir seis tabelas, uniques, índices e FK execução → oferta;
5. iniciar ainda com `Enabled=false` e validar os dois exports;
6. somente em staging controlado ativar a flag e conferir `ready=true`.

Rollback normal é desativar/parar o resource. Não remover tabelas, events, operations ou receipts; restore de banco exige decisão explícita do operador.

## Arquivos da Wave 1

Criados em `mz_jobs`:

- bootstrap/config/locales: `fxmanifest.lua`, `config.lua`, `locales/pt-br.json`, `locales/en.json`, `shared/locale.lua`;
- contratos: `shared/contracts.lua`;
- server: `server/state.lua`, `server/policy.lua`, `server/service.lua`, `server/repository.lua`, `server/reconciliation.lua`, `server/main.lua`;
- adapters: `server/adapters/core.lua`, `server/adapters/economy.lua`, `server/adapters/inventory.lua`;
- persistência/operação: `sql/001_mz_jobs_baseline.sql`, `docs/API.md`, `docs/OPERATIONS.md`, `docs/DECISIONS.md`.

Criados/modificados em `mz_testkit`:

- cinco harnesses em `tests/mz_jobs`;
- cinco registros em `registry/tests.json`;
- perfil `jobs` em `runners/run-local-suite.ps1`.

Mudanças preexistentes e demais arquivos de `mz_testkit` foram preservados.

## Próxima Wave 1.5 — requisitos, sem implementação

### Contrato financeiro canônico

- autenticar o caller owner e recusar valores/client identity fornecidos pelo client;
- reservar budget finito antes de criar obrigação, com fingerprint e chave idempotente;
- representar estados de hold, insuficiência, expiração, release e settlement terminal;
- transferir do budget aprovado ao `citizenid` uma única vez e emitir receipt imutável/consultável;
- permitir replay/lookup após timeout ou resposta perdida, sem mint/fallback;
- definir compensação e ownership de release em cancelamento/expiração;
- expor prova suficiente para o jobs avançar `settlement_pending -> completed`.

### Contrato de custody canônico

- autenticar `mz_jobs` e resolver item/quantidade/origem/destino somente no servidor;
- reserve/commit/cancel com fingerprint, chave idempotente, lease/timeout e CAS;
- emitir receipt imutável/consultável e replayar o mesmo resultado após resposta perdida;
- preservar custody em disconnect/restart e impedir duplicação/perda em retry;
- definir compensação/retorno quando a execução é cancelada após coleta;
- expor prova suficiente para conclusão sem repetir transferências.

### Integração e prova

- definir nomes e DTOs somente no owner após revisão conjunta; não congelar nomes propostos por `mz_jobs`;
- registrar outbox topics apenas quando handlers reais existirem;
- testar insuficiência, duplicidade, timeout, resposta perdida, restart, reconexão e compensação em MySQL/FiveM staging;
- liberar primeiro um fluxo mínimo aprovado, mantendo jobs remunerados/custódia fail-closed até todos os gates passarem.
