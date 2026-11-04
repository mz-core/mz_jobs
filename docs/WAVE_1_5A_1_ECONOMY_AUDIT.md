# MZ Framework — Wave 1.5A-1 — auditoria de contratos financeiros

**Data da inspeção:** 2026-10-25  
**Escopo:** `mz_economy` atual e desenho de financiamento de contratos para `mz_jobs`  
**Alteração de runtime:** nenhuma  
**DDL/dados financeiros:** não executados  
**Wave 1.5A-2:** não iniciada

## 1. Classificação e conclusão

- `VERIFICADO`: presente no source atual ou observado por teste local executado nesta auditoria.
- `PROPOSTO`: desenho candidato; não é export, tabela ou comportamento existente.
- `BLOQUEADO`: depende de decisão, contrato ou evidência ausente e não deve ser contornado.
- `NOT RUN`: não houve comprovação em FiveM/MySQL real.

### Conclusão executiva

`VERIFICADO` — `mz_economy` já é o owner e writer canônico de contas pessoais, contas organizacionais, ledger e mutações financeiras (`mz_economy/docs/README.md:3-30`). Ele já possui os blocos que devem ser reutilizados:

- `mz_player_accounts` para saldo do Character;
- `mz_org_accounts` para saldo finito de Organization;
- `mz_economy_transactions` como ledger canônico;
- operações idempotentes, fingerprints e receipts em dois modelos existentes;
- transferências atômicas `Organization -> Character` no payroll;
- autenticação por `GetInvokingResource` nos contratos tipados.

`BLOQUEADO` — ainda não existe lifecycle de `reserve -> settle/release`, orçamento municipal configurado, consulta de hold, expiração/reconciliação de holds ou export apropriado a `mz_jobs`. Os exports genéricos `AddMoney`/`RemoveMoney` não resolvem isso e não devem ser usados como settlement.

`PROPOSTO` — o piloto deve usar uma conta organizacional municipal dedicada como fonte finita, sem nova tabela de saldo e sem ledger paralelo. A extensão mínima no owner financeiro é:

1. programa de funding que aponta para uma `mz_org_accounts` existente;
2. hold durável debitado da conta fonte no `reserve`;
3. operação idempotente que liquida o hold para `mz_player_accounts.bank` ou o devolve à fonte;
4. todas as pernas no ledger existente;
5. receipts consultáveis e reconciliação economy-owned.

O adapter de `mz_jobs` deve continuar fail-closed até a implementação ser aprovada, concluída e validada.

## 2. Método e estado do workspace

`VERIFICADO` — os cinco documentos obrigatórios de `mz_jobs` foram lidos integralmente. O Graphify foi usado primeiro para descoberta; o resultado amplo trouxe ruído de referências e documentos históricos, portanto todas as conclusões abaixo foram verificadas nos sources reais.

`VERIFICADO` — `mz_economy` possui mudanças locais em andamento: manifest, prepare, repository, service e docs estão modificados; `server/accounts/` e testes aparecem como conteúdo ainda não rastreado no repositório interno. Esta auditoria descreve exatamente o workspace atual, não um commit histórico. Nenhum desses arquivos foi alterado.

## 3. Arquitetura financeira real

### 3.1 Tabelas existentes

| Tabela real | Papel verificado | Reuso no funding |
|---|---|---|
| `mz_player_accounts` | saldo `wallet`, `bank`, `dirty`, único por `citizenid` (`server/prepare.lua:12-21`) | destino do settlement; não criar saldo de jogador em jobs |
| `mz_account_idempotency` | chave por `source_resource + actor_citizenid + idempotency_key`, fingerprint, correlation e resultado (`prepare.lua:23-36`) | padrão útil, mas schema inadequado para reserve sem beneficiário/actor |
| `mz_org_accounts` | saldo único e finito por `org_id` (`prepare.lua:38-45`) | fonte do orçamento municipal e de futuros contratos organizacionais |
| `mz_org_account_operations` | spend/refund, fingerprint, status, receipt e reversal (`prepare.lua:47-75`) | padrão mais próximo; não suporta hold/settle/release |
| `mz_economy_transactions` | ledger com before/after, categoria, caller, flags e referências (`prepare.lua:77-102`) | ledger único de reserve, settlement e release |
| `mz_economy_daily_player_stats` | projeção/reporting diário (`prepare.lua:104-142`) | recebe o income do beneficiário via ledger, sem write próprio de jobs |

`VERIFICADO` — o runtime atual executa seus próprios `CREATE TABLE IF NOT EXISTS` no boot (`server/prepare.lua:177-190`). Isso é comportamento existente, não recomendação para a extensão: a solicitação desta Wave exige que o novo SQL seja CREATE-only e aplicado manualmente.

### 3.2 Contas e mutações

`VERIFICADO` — contas de jogador aceitam somente `wallet`, `bank` e `dirty` no repository (`server/accounts/repository.lua:3,77-95`). O cache `player.money` é uma projeção do banco, carregada por `citizenid` canônico (`server/accounts/core_adapter.lua:20-83`).

`VERIFICADO` — mutações idempotentes persistem, na mesma chamada de `MySQL.transaction.await`, o resultado idempotente, a atualização de saldo e as pernas do ledger (`server/accounts/repository.lua:5-61,85-95`). Chaves genéricas têm 16–64 caracteres e o scope deriva do caller real (`server/accounts/service.lua:247-298`; `server/accounts/exports.lua:16-39`).

`VERIFICADO` — `AddMoney` e `RemoveMoney` validam inteiro positivo e saldo, mas retornam apenas `true` no sucesso ou replay (`server/accounts/service.lua:680-728,747-779`). Eles operam sobre jogador carregado e não debitam uma fonte de orçamento. Portanto:

- não provam conservação entre orçamento e jogador;
- não retornam receipt financeiro suficiente ao `mz_jobs`;
- não suportam beneficiário offline;
- não reservam obrigação antes da execução.

`VERIFICADO` — `TransferBankBetweenPlayers` é idempotente e tem duas pernas, porém exige remetente e destinatário online (`server/accounts/service.lua:921-1024`). Também não representa orçamento municipal ou hold.

### 3.3 Ledger

`VERIFICADO` — `appendLedger` grava cada perna em `mz_economy_transactions` e deriva IDs por `correlationId:leg` (`server/accounts/repository.lua:22-57`). O repository agrega categorias `legal_job` e `illegal_job` separadamente (`server/repository.lua:64-69`).

`VERIFICADO` — `RecordTransaction` é reporting, não movimentação de saldo: ele apenas insere um payload no ledger (`server/main.lua:10-12`; `server/service.lua:263-340`). Não pode ser usado como compensação de uma transferência financeira.

### 3.4 Conta organizacional e payroll

`VERIFICADO` — deposit/withdraw de Organization movem duas contas e duas pernas de ledger dentro do Economy (`server/accounts/org_accounts.lua:170-248,330-416`). O caller público deve ser `mz_org` (`org_accounts.lua:903-925`).

`VERIFICADO` — commerce organizacional já usa:

- allowlist de purposes e resources (`org_accounts.lua:497-513`);
- fingerprint fechado e receipt V1 (`org_accounts.lua:535-564`);
- operação `pending/applied/rejected` recuperável por key (`org_accounts.lua:566-587`);
- CAS pelo saldo anterior (`server/accounts/repository.lua:140-159`);
- spend/refund idempotentes (`org_accounts.lua:712-900`).

`VERIFICADO` — hoje os únicos purposes são `facility_purchase` e `furniture_purchase`, aceitos apenas para `mz_org_activities` e `mz_furniture`; os exports Economy são exclusivos de `mz_org` (`org_accounts.lua:497-513,927-938`). `mz_jobs` não está autorizado.

`VERIFICADO` — o bridge do `mz_org` repete a validação de caller, capability e Organization ativa antes de chamar Economy (`mz_org/server/account_bridge.lua:1-12,45-49,82-102`). Esse gateway é reutilizável para contratos patrocinados por Organization, mas não existe purpose de jobs.

`VERIFICADO` — payroll já executa o movimento necessário ao settlement: debita `mz_org_accounts`, credita `mz_player_accounts.bank`, persiste idempotência e duas pernas do ledger (`server/accounts/payroll.lua:174-288`; `server/accounts/repository.lua:162-175`). Também resolve Character offline pelo `citizenid`, atualizando o cache somente se estiver online (`payroll.lua:66-73,281-283`). Esse é o padrão mais próximo a reutilizar.

### 3.5 Autorização real

`VERIFICADO` — os exports genéricos injetam `GetInvokingResource` no metadata (`server/accounts/exports.lua:16-39`), mas não mantêm uma allowlist de recursos para `AddMoney`/`RemoveMoney` (`exports.lua:46-65`). Idempotência escopa o caller, mas isso não equivale a autorização da finalidade.

`VERIFICADO` — contratos especializados são mais fortes:

- commerce: caller direto deve ser `mz_org`, com purpose/resource allowlisted;
- payroll: caller direto deve ser `mz_org` (`payroll.lua:296-299`);
- cobrança policial: caller direto deve ser `mz_police` e o `citizenid` esperado deve corresponder à identidade runtime (`police_charges.lua:55-66,136-141`).

`PROPOSTO` — funding de jobs deve seguir o modelo especializado, nunca a abertura dos exports genéricos.

## 4. Mecanismos reutilizáveis

| Mecanismo | Estado | Decisão |
|---|---|---|
| `mz_player_accounts.bank` | `VERIFICADO` | destino do settlement |
| `mz_org_accounts.balance` | `VERIFICADO` | fonte finita; não criar `mz_jobs_balance` |
| `mz_economy_transactions` | `VERIFICADO` | ledger único para todas as pernas |
| `BuildFinancialLedgerBatchInternal`/entries | `VERIFICADO` | reutilizar internamente no Economy, não exportar ao jobs (`accounts/service.lua:509-521`) |
| locks ordenados por chave | `VERIFICADO` | reutilizar como proteção local, sem tratá-los como garantia DB (`service.lua:72-137`) |
| fingerprint + operation row + result JSON | `VERIFICADO` | reutilizar o padrão sem forçar schemas atuais inadequados |
| commerce receipt/reversal | `VERIFICADO` | reutilizar forma e semântica de replay |
| payroll `org -> player` | `VERIFICADO` | base do settlement, acrescida do hold |
| relatórios/categorias legal e illegal | `VERIFICADO` | alimentar com flags coerentes; não criar reporting em jobs |
| generic `AddMoney` | `BLOQUEADO` para jobs | crédito sem origem; proibido como settlement |
| `RecordTransaction` | `BLOQUEADO` para mutação | ledger não altera saldo |

## 5. Lacunas e riscos

### 5.1 Lacunas funcionais

1. `BLOQUEADO` — não há hold financeiro, release, expiração ou lookup por hold.
2. `BLOQUEADO` — não há programa municipal ou conta municipal seedada. Os defaults reais são `police`, `ambulance`, `mechanic`, `mafia` e `vip`; não há Organization `government` municipal no seed (`mz_org/server/domain/default_orgs.lua:274-552`).
3. `BLOQUEADO` — não existe mecanismo aprovado de capitalização inicial do orçamento municipal. O saldo deve começar em zero até uma fonte finita ser escolhida.
4. `BLOQUEADO` — o Economy usa inteiros chamados `amount`, mas não documenta se representam unidade inteira ou minor unit. A Wave 1.5A-2 não deve renomear para `amountMinor` sem essa decisão.
5. `BLOQUEADO` — a consulta genérica `GetOperationResult` exige `source` online e escopa por `actor_citizenid` (`accounts/service.lua:303-344`); reserve sem beneficiário e reconciliação offline precisam de consulta própria.
6. `BLOQUEADO` — não existe worker financeiro atual. O README confirma que a antiga outbox foi removida (`docs/README.md:43-49`). Holds expirados exigem reconciliação do próprio Economy.

### 5.2 Concorrência e crash

`VERIFICADO` — `AccountLocks` é uma tabela Lua no processo e o timeout é de 10 s (`accounts/service.lua:3-5,72-137`). Ela serializa o resource atual, mas desaparece em restart e não protege múltiplos processos ou writes SQL externos.

`VERIFICADO` — várias rotas calculam saldo em Lua e depois escrevem valor absoluto sem `WHERE balance = before` (`accounts/repository.lua:77-95,162-175,205-227`). A regra de single writer e os locks locais reduzem a disputa, mas não substituem CAS/row lock no banco.

`VERIFICADO` — commerce possui CAS no UPDATE da Organization (`accounts/repository.lua:140-159`), mas o helper apenas testa o boolean de `MySQL.transaction.await` e anexa ledger statements incondicionalmente (`repository.lua:22-61`).

`BLOQUEADO` — deve-se comprovar no oxmysql/MySQL real o comportamento de transação quando o UPDATE CAS afeta zero rows. Até essa prova, a Wave 1.5A-2 não deve copiar esse padrão para holds: existe risco de commit de ledger sem transição financeira correspondente. O novo repository precisa de `SELECT ... FOR UPDATE` com inspeção de resultado, ou DML condicional em que hold, operação e ledger só avancem quando o CAS realmente vencer.

`VERIFICADO` — operation `pending` de commerce é retomada quando o caller repete a mesma key, porém não há scanner de pendências/TTL (`org_accounts.lua:566-587,765-795`). Isso não basta para expiração autônoma de budget.

## 6. Modelo de orçamento municipal finito

### 6.1 Fonte

`PROPOSTO` — criar/selecionar uma Organization canônica do tipo `government`, com shared account dedicada ao piloto. O código real dessa Organization permanece `BLOQUEADO`; este relatório usa o placeholder documental `PENDING_MUNICIPAL_ORG`, não um identificador implementado.

O programa `municipal_jobs_pilot_v1` apontaria para o `org_id` dessa conta e teria:

- caller permitido: `mz_jobs`;
- finalidade: contratos legais do piloto;
- conta beneficiária: `bank`;
- valor máximo por hold;
- TTL máximo cobrindo oferta + execução + margem de settlement;
- limite opcional de holds abertos;
- status `active/paused` e versionamento.

O saldo disponível é exclusivamente `mz_org_accounts.balance`. Não haverá coluna de saldo nos programas nem no `mz_jobs`.

### 6.2 Capitalização

`BLOQUEADO` — escolher uma fonte inicial real. Opções para aprovação, em ordem de segurança:

1. receitas municipais futuras já movimentadas pelo Economy;
2. transferência/deposito canônico de uma fonte financeira existente e identificada;
3. apropriação única de staging, finita e idempotente, classificada como adjustment e auditada.

Não usar refill periódico, saldo negativo, fallback para `AddMoney` nem recriar dinheiro quando o orçamento acabar. Enquanto a decisão estiver aberta, o programa permanece sem saldo e capabilities de funding devem informar indisponibilidade.

### 6.3 Contabilidade das pernas

`PROPOSTO`:

| Operação | Perna 1 | Perna 2 | Income/expense |
|---|---|---|---|
| reserve | `org out` | `contract_hold in` | ambos `false`; é encumbrance, não despesa realizada |
| settle | `contract_hold out` | `player bank in` | hold `counts_as_expense=true`; player `counts_as_income=true` |
| release/expire | `contract_hold out` | `org in` | ambos `false`; reversão de encumbrance |

O hold fica inteiramente no owner financeiro. `mz_jobs` persiste somente `holdRef` e referências de receipts.

## 7. Arquitetura proposta

```text
mz_jobs
  reserve(programRef, relatedRef, amount, ttl) ─────┐
  settle(holdRef, beneficiaryCitizenid) ───────────┤
  release(holdRef, reason) ────────────────────────┤
  lookup(operationKey/holdRef) ────────────────────┤
                                                    v
                                              mz_economy
                                      ┌─────────────┴─────────────┐
                                      │ funding programs/holds    │
                                      │ idempotent operations     │
                                      └──────┬───────────┬────────┘
                                             │           │
                                    mz_org_accounts   mz_player_accounts
                                             └─────┬─────┘
                                                   v
                                      mz_economy_transactions
```

Para contratos patrocinados por uma Organization arbitrária, o caminho futuro deve ser:

```text
mz_jobs -> mz_org (capability/Organization authority) -> mz_economy
```

O bridge de `mz_org` continua owner de membership/capability; Economy continua owner de saldo/hold/ledger. O piloto municipal system-owned pode usar um programa previamente aprovado que não exige aprovação de um jogador a cada oferta.

## 8. Fluxos

### 8.1 Reserve e publicação

`PROPOSTO`:

1. `mz_jobs` calcula internamente o reward do template; o client não envia valor/programa.
2. Jobs chama reserve antes de publicar a oferta.
3. Economy deriva caller por `GetInvokingResource`, valida DTO fechado, programa ativo, legalidade, limites e TTL.
4. A mesma transação:
   - debita a Organization somente se houver saldo;
   - cria hold `reserved`;
   - aplica a operation idempotente;
   - grava receipt e duas pernas do ledger.
5. Jobs publica apenas após receipt `reserved` e persiste `budgetHoldRef`.

Se faltar saldo, Economy persiste a operation como `rejected/insufficient_budget`; não cria obrigação nem oferta remunerada.

### 8.2 Settle

`PROPOSTO`:

1. Após prova real do trabalho/custody, Jobs entra em `settlement_pending`.
2. Jobs envia `holdRef`, `beneficiaryCitizenid` server-resolved e nova `operationKey`; não envia amount.
3. Economy obtém amount/program/source do hold, valida Character canônico, conta `bank` e `expiresAt` sob o mesmo lock transacional.
4. Antes de `expiresAt`, a transação única muda `reserved -> settled`, credita `mz_player_accounts`, aplica operation e ledger. Em ou depois de `expiresAt`, settlement é recusado e o caminho de expiração vence, ainda que o scanner não tenha rodado.
5. Repetição retorna o mesmo receipt; outro beneficiary/fingerprint gera `idempotency_conflict`.
6. Jobs registra apenas receipt ref em event/operation e então conclui a execução/XP uma vez.

O beneficiário pode estar offline. O banco é atualizado por `citizenid`; se online, o cache é atualizado depois do commit, como no payroll.

### 8.3 Release/cancelamento

`PROPOSTO`:

- oferta cancelada/expirada antes do settlement chama release com key determinística;
- Economy muda `reserved -> released`, devolve o valor à mesma Organization e grava ledger/receipt;
- replay retorna o mesmo receipt;
- hold `settled` não pode ser released;
- release não é refund de settlement. Correção pós-settlement exige fluxo financeiro separado e aprovado.

### 8.4 Expiração e restart

`PROPOSTO`:

- Economy usa seu relógio/UTC e o `expiresAt` retornado; Jobs não decide se o hold expirou;
- scanner busca holds `reserved` vencidos com `next_reconcile_at` e lease;
- a operação interna usa key determinística `expire:<holdRef>` e o mesmo caminho de release;
- crash após claim é recuperado quando o lease expira;
- terminal nunca é reprocessado;
- erros recebem backoff limitado e código sanitizado; após limite, estado `review_required`, sem perder saldo/receipt.

Jobs também pode reconciliar sua outbox chamando lookup/replay, mas não deve liberar saldo por SQL nem possuir um segundo worker financeiro.

### 8.5 Corridas esperadas

| Corrida | Resultado obrigatório |
|---|---|
| dois reserves sobre saldo final | no máximo um vence; saldo nunca negativo |
| settle vs release | exatamente um terminal vence por CAS/version |
| settle vs expire | exatamente um vence; loser lê receipt terminal |
| resposta perdida após reserve | replay devolve mesmo hold/receipt |
| resposta perdida após settle | replay/lookup devolve mesmo receipt; zero crédito extra |
| restart com hold vencido | worker devolve uma vez e preserva auditoria |

### 8.6 Falhas e recuperação

`PROPOSTO` — respostas falhas usam envelope versionado com `ok=false`, `errorCode`, `retryable` e, quando já existe, `receiptId`/estado terminal. A taxonomia inicial é fechada: `invalid_request`, `forbidden_caller`, `program_unavailable`, `insufficient_budget`, `hold_not_found`, `hold_expired`, `terminal_conflict`, `idempotency_conflict`, `beneficiary_not_found` e `temporarily_unavailable`.

- falha de validação/autorização: zero writes;
- saldo insuficiente: operation `rejected` persistida, sem hold, ledger ou alteração de saldo;
- timeout/erro transitório: caller consulta pela mesma `operationKey` antes de repetir;
- conflito idempotente ou terminal: retorna estado persistido, sem compensação automática;
- falha SQL: rollback integral; se o resultado do commit for incerto, lookup/replay decide pelo registro durável.

## 9. APIs e DTOs propostos

Todos os nomes desta seção são `PROPOSTO`, não existem hoje e exigem aprovação.

### 9.1 Capabilities

`exports['mz_economy']:GetContractFundingCapabilities()`

```lua
{
  schemaVersion = 1,
  ready = true,
  reserve = true,
  settle = true,
  release = true,
  lookup = true,
  idempotent = true,
  receipt = true,
  offlineBeneficiary = true,
  programs = { 'municipal_jobs_pilot_v1' }
}
```

Não retornar saldos nessa capability.

### 9.2 Reserve

`exports['mz_economy']:ReserveContractFunding(request)`

```lua
{
  schemaVersion = 1,
  operationKey = 'jobs_offer_<opaque>_reserve',
  programRef = 'municipal_jobs_pilot_v1',
  relatedRef = 'offer_<opaque>',
  purpose = 'legal_job_contract',
  legality = 'legal',
  amount = 500,          -- unidade inteira canônica; decisão de minor unit pendente
  ttlSeconds = 7200
}
```

Retorno aplicado:

```lua
{
  ok = true,
  schemaVersion = 1,
  operation = 'reserve',
  receiptId = 'opaque',
  holdRef = 'opaque',
  programRef = 'municipal_jobs_pilot_v1',
  relatedRef = 'offer_<opaque>',
  status = 'reserved',
  amount = 500,
  account = 'bank',
  expiresAt = 'UTC',
  replayed = false
}
```

### 9.3 Settle

`exports['mz_economy']:SettleContractFunding(request)`

```lua
{
  schemaVersion = 1,
  operationKey = 'jobs_execution_<opaque>_settle',
  holdRef = 'opaque',
  beneficiaryCitizenid = 'server-resolved',
  relatedRef = 'execution_<opaque>'
}
```

O amount e a conta são carregados do hold, não aceitos novamente. O receipt inclui `holdRef`, `beneficiaryCitizenid`, `amount`, `account`, `status='settled'`, `settledAt` e `replayed`; balances internos podem existir no result persistido, mas não precisam atravessar para client/jobs.

### 9.4 Release

`exports['mz_economy']:ReleaseContractFunding(request)`

```lua
{
  schemaVersion = 1,
  operationKey = 'jobs_offer_<opaque>_release',
  holdRef = 'opaque',
  reason = 'offer_expired' -- enum fechado
}
```

Reasons iniciais: `offer_cancelled`, `offer_expired`, `execution_cancelled`, `execution_expired`, `operator_review`. Expiração automática usa `hold_expired` internamente.

### 9.5 Lookup

- `GetContractFundingOperation(operationKey)` — escopado pelo caller real;
- `GetContractFundingHold(holdRef)` — somente owner/caller autorizado do hold.

Ambos são read-only, retornam estado terminal/pending, receipt e erro sanitizado. Não aceitam `sourceResource` do payload.

## 10. Autorização e trust boundary

`PROPOSTO`:

1. `GetInvokingResource()` obrigatório e igual a `mz_jobs` no piloto.
2. Nenhum parâmetro `sourceResource`, balance, receipt, status ou budget account vindo do caller.
3. O client nunca chama Economy e nunca fornece amount, beneficiary, program, legality ou purpose.
4. `operationKey`, `relatedRef`, tokens e metadata usam allowlist de caracteres e limites fechados.
5. `amount` é inteiro positivo, limitado por safe integer e pelo programa.
6. `ttlSeconds` é inteiro e limitado pelo programa; `expiresAt` é calculado no Economy.
7. `beneficiaryCitizenid` só entra no settle, vem da execução server-authoritative e deve existir no Core.
8. O fingerprint cobre schema, operation, caller, program/hold, relatedRef, purpose, legality, amount/beneficiary e TTL.
9. Programs escolhem internamente a conta fonte; Jobs não envia `org_id` ou saldo.
10. Logs não contêm payload bruto, secrets ou balances desnecessários.

Para Organization-sponsored jobs, `mz_org` deve validar membership/capability e encaminhar descriptor canônico, seguindo o bridge existente. Não conceder a `mz_jobs` poder de escolher/debitar qualquer Organization.

## 11. Persistência proposta — SQL CREATE-only

Este DDL é `PROPOSTO`, não foi criado em `mz_economy`, não foi executado e não inclui seed/DML.

```sql
CREATE TABLE IF NOT EXISTS mz_contract_funding_programs (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  public_id VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  source_org_id BIGINT UNSIGNED NOT NULL,
  source_org_code VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  purpose VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  legality VARCHAR(16) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  allowed_resource VARCHAR(100) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  beneficiary_account VARCHAR(32) CHARACTER SET ascii COLLATE ascii_bin NOT NULL DEFAULT 'bank',
  max_hold_amount BIGINT UNSIGNED NOT NULL,
  max_hold_ttl_seconds INT UNSIGNED NOT NULL,
  active TINYINT(1) NOT NULL DEFAULT 0,
  version INT UNSIGNED NOT NULL DEFAULT 1,
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_mz_contract_program_public (public_id),
  KEY ix_mz_contract_program_source (source_org_id, active),
  CONSTRAINT fk_mz_contract_program_org_account FOREIGN KEY (source_org_id)
    REFERENCES mz_org_accounts (org_id) ON UPDATE RESTRICT ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS mz_contract_funding_holds (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  public_id VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  program_id BIGINT UNSIGNED NOT NULL,
  source_resource VARCHAR(100) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  related_ref VARCHAR(128) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  beneficiary_citizenid VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin NULL,
  beneficiary_account VARCHAR(32) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  amount BIGINT UNSIGNED NOT NULL,
  status VARCHAR(24) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  reserve_receipt_id VARCHAR(128) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  terminal_receipt_id VARCHAR(128) CHARACTER SET ascii COLLATE ascii_bin NULL,
  expires_at DATETIME(3) NOT NULL,
  terminal_at DATETIME(3) NULL,
  version INT UNSIGNED NOT NULL DEFAULT 1,
  reconcile_attempts INT UNSIGNED NOT NULL DEFAULT 0,
  next_reconcile_at DATETIME(3) NULL,
  lease_until DATETIME(3) NULL,
  last_error VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin NULL,
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_mz_contract_hold_public (public_id),
  UNIQUE KEY uq_mz_contract_hold_related (program_id, source_resource, related_ref),
  UNIQUE KEY uq_mz_contract_hold_reserve_receipt (reserve_receipt_id),
  UNIQUE KEY uq_mz_contract_hold_terminal_receipt (terminal_receipt_id),
  KEY ix_mz_contract_hold_reconcile (status, next_reconcile_at, lease_until, expires_at),
  CONSTRAINT fk_mz_contract_hold_program FOREIGN KEY (program_id)
    REFERENCES mz_contract_funding_programs (id) ON UPDATE RESTRICT ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS mz_contract_funding_operations (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  source_resource VARCHAR(100) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  operation_key VARCHAR(128) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  operation_type VARCHAR(24) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  hold_id BIGINT UNSIGNED NULL,
  request_fingerprint CHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  status VARCHAR(24) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  result_json JSON NULL,
  error_code VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin NULL,
  receipt_id VARCHAR(128) CHARACTER SET ascii COLLATE ascii_bin NULL,
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  applied_at DATETIME(3) NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_mz_contract_operation_scope (source_resource, operation_key),
  UNIQUE KEY uq_mz_contract_operation_receipt (receipt_id),
  KEY ix_mz_contract_operation_hold (hold_id, operation_type),
  KEY ix_mz_contract_operation_status (status, updated_at),
  CONSTRAINT fk_mz_contract_operation_hold FOREIGN KEY (hold_id)
    REFERENCES mz_contract_funding_holds (id) ON UPDATE RESTRICT ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

### Justificativa das três tabelas

- `programs` é policy/fonte aprovada; não guarda saldo.
- `holds` é a obrigação reservada e seu lifecycle; fica no owner financeiro.
- `operations` é idempotência/receipt por comando e permite registrar reserve rejeitado sem hold.

Não criar nova tabela de ledger, player balance ou org balance. O ledger continua `mz_economy_transactions`.

## 12. Compatibilidade de domínio

### Contratos legais

`PROPOSTO` — suportados pelo programa municipal legal. Settlement usa categoria `legal_job`, já reconhecida no reporting (`server/repository.lua:68`).

### Contratos ilegais

`BLOQUEADO` — não financiar com orçamento municipal. `mz_org_accounts` possui um saldo genérico e não distingue moeda legal/dirty; escolher uma gang account não resolve sozinho a proveniência. Antes de habilitar, definir sponsor, moeda, categorias e consequências de laundering/reporting. A taxonomia `illegal_job` existe apenas no ledger (`server/repository.lua:69`), não como funding policy.

### Contratos organizacionais

`PROPOSTO` — usar conta da Organization patrocinadora, mas autorização deve passar por `mz_org`, com capability própria como `contracts.fund` a ser aprovada. Economy valida caller/purpose e executa a transação; Jobs não recebe acesso genérico a org accounts.

### `mz_population`

`PROPOSTO` — Population pode produzir demanda/prioridade futura, nunca saldo, amount ou settlement. Jobs transforma demanda aprovada em oferta e chama reserve com programa server-side. Population não chama Economy diretamente.

## 13. Efeitos sobre `mz_jobs`

`VERIFICADO` — o adapter atual anuncia `budgetHold=false`, `budgetRelease=false`, `settlement=false` e `receipt=false` (`mz_jobs/server/adapters/economy.lua:3-15`). A policy bloqueia toda oferta financeira (`mz_jobs/server/policy.lua:19-25`). Isso deve permanecer inalterado nesta auditoria.

`VERIFICADO` — `JobOfferV1` estrutural já exige `budgetHoldRef` para compensation financeira (`mz_jobs/shared/contracts.lua:196-208`) e a tabela de ofertas já possui `budget_hold_ref` (`mz_jobs/sql/001_mz_jobs_baseline.sql:14-16`). Não é necessário criar escrow ou settlement table em Jobs.

`PROPOSTO` para uma Wave posterior à 1.5A-2:

1. adapter consulta capabilities reais do Economy;
2. publicação financeira só ocorre após reserve aplicado;
3. `holdRef`/reserve receipt são persistidos server-side;
4. cancel/expiry enfileiram release com key determinística;
5. conclusão cria outbox settlement com a mesma key em todos os retries;
6. Jobs registra apenas `economyReceiptRef` em operation/event e usa o receipt validado para `completed`/XP;
7. nenhum balance, org id ou amount vindo do client;
8. se Economy estiver indisponível, oferta financeira não publica e execução entregue permanece `settlement_pending`.

A superfície pública read-only e o default `Enabled=false` de Jobs não mudam nesta Wave.

## 14. Matriz de testes proposta para `mz_testkit`

Todos os casos abaixo são `PROPOSTO / NOT RUN`.

| # | Caso | Critério |
|---:|---|---|
| 1 | capability/schema ausente | `ready=false`, zero writes |
| 2 | caller diferente de jobs | `forbidden_caller`, zero writes |
| 3 | DTO extra/bounds | payload fechado; NaN, float, negativo, overflow, TTL/token inválidos recusados |
| 4 | reserve normal | um débito org, um hold, uma operation, duas ledger legs e um receipt |
| 5 | saldo insuficiente | operação rejeitada auditável, zero hold/saldo/ledger |
| 6 | replay reserve | mesmo receipt/hold, zero débito extra |
| 7 | conflito reserve | mesma key e fingerprint diferente retorna conflito |
| 8 | dois reserves concorrentes | no máximo o saldo disponível é comprometido; nunca negativo |
| 9 | settle normal | hold terminal, um crédito bank, duas ledger legs, receipt único |
| 10 | settle offline | DB por citizenid e projeção correta no próximo login |
| 11 | replay/timeout settle | mesmo receipt; um único crédito |
| 12 | release normal | valor integral volta à mesma org; receipt único |
| 13 | replay release | nenhum segundo crédito à org |
| 14 | settle vs release | exatamente um terminal vence |
| 15 | settle vs expire | exatamente um terminal vence |
| 16 | settle após `expiresAt`, antes do scanner | recusado; nenhum pagamento; expiração devolve uma vez |
| 17 | restart com lease | hold vencido é retomado e released uma vez |
| 18 | poison/retry | backoff bounded, erro sanitizado, estado `review_required` auditável |
| 19 | programa paused/errado | zero writes |
| 20 | legalidade/purpose incompatível | zero writes |
| 21 | Character inexistente | settle rejeitado sem consumir hold |
| 22 | org-sponsored sem capability | bloqueado no gateway do Org |
| 23 | flags de reporting | reserve/release não contam renda; settle conta income/expense uma vez |
| 24 | falha em cada statement | rollback total de balance/hold/operation/ledger |
| 25 | CAS afeta zero rows | nenhum ledger/receipt fantasma |
| 26 | consulta após restart | operation e hold retornam o mesmo resultado persistido |
| 27 | jobs adapter antes do rollout | continua fail-closed |

Testes unitários/mocks devem ir em `mz_testkit/tests/mz_economy_contract_funding` ou nomenclatura aprovada pelo registry. Concorrência e crash precisam também de runner MySQL real; harness Lua não prova locks/isolamento.

## 15. Evidência local executada

`VERIFICADO` — sem modificar arquivos:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\mz_testkit\runners\run-local-suite.ps1 -Suite economy
# SUMMARY total=7 pass=7 failed=0

Push-Location mz_economy
lua .\tests\police_charge_harness.lua
# PASS cases=4
```

Esses testes confirmam os contratos atuais sob mocks. Não testam o desenho proposto nem permitem declarar MySQL/FiveM runtime PASS.

## 16. Decisões pendentes

| Decisão | Estado | Gate |
|---|---|---|
| Organization municipal/código canônico | `BLOQUEADO` | definir/criar no owner `mz_org` |
| fonte de capitalização inicial | `BLOQUEADO` | aprovar origem finita e auditável |
| unidade monetária (`amount` vs minor unit) | `BLOQUEADO` | padronizar no Economy antes do DTO final |
| valores máximos e TTL do piloto | `BLOQUEADO` | balanceamento aprovado |
| transação com row lock/affected rows no oxmysql instalado | `BLOQUEADO` | spike MySQL real antes de código financeiro |
| expiração terminal após retries | `PROPOSTO` | `review_required`, sem perda ou mint |
| gateway para org-sponsored jobs | `PROPOSTO` | capability/purpose no `mz_org` |
| financiamento de contrato ilegal | `BLOQUEADO` | sponsor/moeda/proveniência aprovados |
| retenção/arquivamento de receipts | `BLOQUEADO` | política operacional antes de produção |

## 17. Escopo delimitado para Wave 1.5A-2

Somente após aprovação deste relatório:

1. confirmar unidade monetária, Organization municipal, funding inicial, limites e TTL;
2. validar a API transacional real do oxmysql e escolher row-lock/CAS seguro;
3. implementar no `mz_economy` os três schemas CREATE-only, aplicados manualmente, e readiness sem DDL runtime para essa extensão;
4. implementar repository/service/worker e exports tipados somente no Economy;
5. manter ledger e balances atuais como únicos canônicos;
6. criar testes apenas no `mz_testkit`, incluindo MySQL concurrency/crash;
7. não alterar ainda `mz_jobs` além de uma Wave de integração separada e aprovada;
8. não habilitar programa, jobs, NPC ou economia dinâmica.

Fora da 1.5A-2: custody, gameplay, UI, population writer, contratos ilegais, org-sponsored genérico, balanceamento dinâmico e ativação de Jobs.

## 18. NOT RUN

- FiveM/OneSync runtime;
- MySQL/oxmysql real e nível de isolamento;
- `SELECT ... FOR UPDATE`, affected rows e deadlocks reais;
- aplicação do DDL proposto;
- reserve/settle/release propostos;
- crash/restart/reconnect reais;
- capitalização municipal;
- integração `mz_jobs -> mz_economy`;
- contratos ilegais, organizacionais ou demanda do Population.

## 19. Impacto arquitetural desta auditoria

- contratos públicos: nenhum alterado; APIs novas são apenas propostas;
- ownership: inalterado; Economy continua único owner financeiro;
- writer/authority: inalterado;
- dependências cross-resource: nenhuma criada;
- persistência: nenhum schema/dado alterado; DDL apenas documental;
- segurança: adapter Jobs permanece fail-closed;
- exports/events/callbacks/adapters: nenhum criado;
- Graphify: consulta read-only; sincronização não aplicável a auditoria;
- validação runtime: `NOT RUN`.
