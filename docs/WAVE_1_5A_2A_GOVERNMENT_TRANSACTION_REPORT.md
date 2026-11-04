# MZ Framework — Wave 1.5A-2A — governo e segurança transacional

**Data da inspeção:** 2026-10-25  
**Escopo:** `mz_org`, `mz_economy` e consumidores reais de Organization  
**Relatório-base:** `mz_jobs/docs/WAVE_1_5A_1_ECONOMY_AUDIT.md`  
**Alteração de runtime:** nenhuma  
**DDL/dados financeiros:** não executados  
**Migração `job -> government`:** não executada  
**Funding API:** não implementada  
**Próxima implementação:** não iniciada

## 1. Classificação e conclusão

- `VERIFICADO`: confirmado no source atual, no ambiente local ou por harness local executado nesta auditoria.
- `PROPOSTO`: arquitetura ou procedimento futuro; não existe como contrato implementado.
- `BLOQUEADO`: depende de decisão ou evidência obrigatória ainda ausente.
- `NOT RUN`: teste real não executado; não há alegação de sucesso.

### Conclusão executiva

`VERIFICADO` — `mz_org` já possui os tipos canônicos `job`, `business` e `government`, todos independentes dos flags persistidos `has_salary`, `has_shared_account` e `has_storage` (`mz_org/shared/config.lua:51-58`; `mz_org/server/domain/schema.lua:16-33`). Entretanto, os seeds atuais classificam `police`, `ambulance` e `mechanic` como `job`; nenhuma Organization padrão usa `government` ou `business` (`mz_org/server/domain/default_orgs.lua:274-456`).

`VERIFICADO` — mudar apenas o `type_id` de `police` ou `ambulance` preserva `mz_orgs.id`, código, grades, permissions, memberships e `mz_org_accounts`, pois essas estruturas são ligadas por `org_id`. Duty, liderança, banco, storage e salário aceitam `government`. A mudança não é semanticamente neutra, porém: a projeção legada `player.job` só é preenchida para `type='job'`, o menu muda de perfil, os atalhos passam a filtrar outro tipo e ao menos `mz_transport` contém um gate explícito por `organization.type == 'job'` (`mz_org/server/domain/service.lua:1100-1159`; `mz_transport/server/services/driver_service.lua:138-147`).

`PROPOSTO` — separar:

- `organization_type`: modelo operacional/administrativo (`job`, `business`, `government`, `gang`, `vip`, `event`);
- `institutional_role`: função institucional estável (`police`, `medical`, `municipal` etc.);
- capabilities: única fonte para autorização de ações.

O role não concede poder e não substitui capabilities. `police` e `ambulance` podem receber roles enquanto ainda são `job`; a troca para `government` só ocorre após todos os consumidores deixarem de depender de `player.job` ou do tipo `job`.

`VERIFICADO` — o Economy representa valores como inteiros em colunas `BIGINT`, rejeita frações e exibe esses inteiros como unidades completas de `R$` (`mz_economy/server/prepare.lua:12-17,38-45,77-85`; `mz_economy/server/accounts/service.lua:755-779`; `mz_org/client/menu/common.lua:195-205`).

`PROPOSTO` — manter, na primeira implementação governamental, a unidade atual: **uma unidade inteira do campo `amount` equivale a uma unidade monetária exibida**. Não renomear para `amountMinor` nem multiplicar saldos por 100 silenciosamente.

`NOT RUN` — não foi possível validar `SELECT ... FOR UPDATE`, zero affected rows, rollback, deadlock, concorrência ou crash após commit. O workspace não contém o resource/versionamento de `oxmysql`; o host não possui cliente/serviço MySQL ou MariaDB e não disponibiliza Docker/Podman. A implementação financeira continua bloqueada até o procedimento descartável da seção 9 ser executado.

## 2. Método e estado do workspace

`VERIFICADO` — o Graphify foi consultado primeiro para localizar relações entre Organization, duty, menus, payroll e Economy. O grafo atual possui 48.462 nodes e retornou documentação histórica e referências; todas as conclusões deste relatório foram conferidas no source real.

`VERIFICADO` — foram inspecionados:

- schema, seeds, repository, services, exports e staff mutations do `mz_org`;
- profiles/features/mutations dos menus, session, duty points e bridge financeiro;
- contas, operações, ledger, cobrança policial e payroll do `mz_economy`;
- policies reais de `mz_police` e `mz_medical`;
- consumidores runtime de `GetPlayerOrgContext`/`GetPlayerOrgs` e checks explícitos de tipo;
- manifestos e disponibilidade local de `oxmysql`, MySQL/MariaDB e containers;
- registry e runners atuais do `mz_testkit`.

`VERIFICADO` — `mz_org`, `mz_economy`, `mz_testkit` e `mz_police` possuem alterações locais preexistentes extensas. Elas foram preservadas. Este relatório descreve o workspace atual, não um commit histórico.

## 3. Estrutura governamental real

### 3.1 Persistência e tipos

`VERIFICADO` — a classificação é normalizada por `mz_org_types`; cada Organization guarda `type_id`, enquanto seus flags operacionais ficam diretamente em `mz_orgs` (`mz_org/server/domain/schema.lua:8-33`). O tipo não é o ID nem o código da Organization.

| Conceito | Owner/tabela real | Efeito de uma troca de tipo |
|---|---|---|
| tipo | `mz_org.mz_org_types` + `mz_orgs.type_id` | muda somente a classificação quando atualizada corretamente |
| identidade da Organization | `mz_orgs.id` + `mz_orgs.code` | deve permanecer intacta |
| cargos/salários | `mz_org_grades.org_id` | preservados pelo mesmo `org_id` |
| capabilities | `mz_org_permissions.org_id/grade_id` | preservadas; tipo não deve conceder autorização |
| memberships/duty | `mz_player_orgs.org_id` | preservados pelo mesmo `org_id` |
| conta financeira | `mz_economy.mz_org_accounts.org_id` | preservada pelo mesmo `org_id` |
| ledger | `mz_economy_transactions.related_org_code` | histórico preservado pelo código estável |

`VERIFICADO` — os tipos aceitos e seedados são `job`, `gang`, `vip`, `business`, `government` e `event` (`mz_org/shared/config.lua:51-58`). `staff` não é um tipo operacional aceito pelos templates (`mz_org/server/domain/service.lua:856-864`).

### 3.2 Semântica atual de `job`, `business` e `government`

| Dimensão | `job` | `business` | `government` | Evidência |
|---|---|---|---|---|
| template com salário | sim | sim | sim | `mz_org/server/domain/service.lua:701-728,754-801` |
| shared account obrigatória no template | sim | sim | sim | mesmas linhas |
| storage no template | sim | sim | sim | mesmas linhas |
| duty | sim | sim | sim | `mz_org/server/duty_points.lua:3-9` |
| liderança | sim | sim | sim | `mz_org/server/domain/service.lua:33-53` |
| banco no menu | aplicável | aplicável | aplicável | `mz_org/shared/menu_features.lua:24-29` |
| profile visual | Organization | Empresa | Governo | `mz_org/shared/menu_profiles.lua:22-65` |
| recruitment default visual | ligado | ligado | desligado | `mz_org/shared/menu_profiles.lua:29-65` |
| projeção `player.job` | sim, se primary | não | não | `mz_org/server/domain/service.lua:1154-1155` |
| módulo/atalho legado | `legal` | `business` | `government` | `mz_org/shared/modules.lua:9-48`; `mz_org/server/session.lua:327-345` |

`VERIFICADO` — flags reais da Organization prevalecem sobre inferência de tipo. `mz_orgs` persiste `has_salary`, `has_shared_account` e `has_storage`; uma troca de tipo não os reescreve automaticamente (`mz_org/server/domain/schema.lua:21-26`; `mz_org/server/domain/staff_mutation_repository.lua:91-97`).

### 3.3 Classificação atual das organizações padrão

| Código | Nome | Tipo atual | Salário | Shared account | Role institucional real |
|---|---|---|---:|---:|---|
| `police` | Polícia Militar | `job` | sim | sim | ausente |
| `ambulance` | Hospital | `job` | sim | sim | ausente |
| `mechanic` | Mecânica | `job` | sim | sim | ausente |
| `mafia` | Máfia | `gang` | não | sim | ausente |
| `vip` | VIP | `vip` | não | não | ausente |

Evidência: `mz_org/server/domain/default_orgs.lua:274-552`.

`VERIFICADO` — não há Organization padrão do tipo `government` nem `business`. O tipo e o template existem, mas não há entidade governamental seedada.

### 3.4 Separação recomendada de função institucional

`PROPOSTO` — adicionar no owner `mz_org`, em Wave própria, um campo canônico nullable `institutional_role`. Ele deve ser parte do DTO server-side da Organization, validado por enum/versionamento e indexável. Não usar `config_json.public.metadata.category` como autoridade: esse campo é apresentação editável e hoje aceita somente `category`/`locale` (`mz_org/server/domain/staff_mutations.lua:450-473`).

| Organization | `organization_type` futuro | `institutional_role` | Autorização efetiva |
|---|---|---|---|
| Tesouro Municipal | `government` | `municipal` | capabilities financeiras específicas |
| `police` | `government` após migração | `police` | `police.*`, `mdt.open`, account capabilities |
| `ambulance` | `government` após migração | `medical` | `ambulance.*`, account capabilities |
| empresa privada | `business` | `NULL` ou role de domínio aprovado | capabilities da empresa |
| emprego genérico | `job` | `NULL` | capabilities do emprego |

Regras propostas:

1. role classifica; capability autoriza;
2. código identifica a Organization; role não substitui `orgCode` em ledger/jurisdiction;
3. múltiplas Organizations podem compartilhar um role;
4. role desconhecido falha fechado em integrações que o exigem;
5. `gang` e organizações criminosas não recebem role governamental.

## 4. Matriz de impacto `job -> government`

| Superfície | Estado | Impacto esperado | Gate de migração |
|---|---|---|---|
| `mz_orgs.id`/`code` | `VERIFICADO` | nenhum se mudar somente `type_id` | proibir recriação da Organization |
| grades e salários | `VERIFICADO` | IDs, levels, codes e valores permanecem | snapshot antes/depois |
| members e primary flag | `VERIFICADO` | linhas continuam ligadas ao mesmo `org_id` | contagem/hash antes/depois |
| duty persistido | `VERIFICADO` | `government` é tipo suportado | revalidar pontos e jogadores online |
| capabilities | `VERIFICADO` | continuam por org/grade; role/tipo não concede poder | testes de cada capability crítica |
| conta/ledger | `VERIFICADO` | conta continua por `org_id`; histórico por `orgCode` | saldo e ledger invariantes |
| payroll | `VERIFICADO` | código atual usa membership flags, duty e salary, não o tipo | harness + staging tick sem pagamento real |
| `player.job` | `BLOQUEADO` | deixa de ser preenchido para `government` | inventariar consumidores externos ou remover contrato conscientemente |
| `player.gang` | `VERIFICADO` | não afetado | nenhum |
| `/org` e hub | `VERIFICADO` | Organization continua acessível | smoke de session/menu |
| `/government` | `VERIFICADO` | passa a selecionar polícia/hospital | validar UX e entry guard |
| módulo legado `legal` | `VERIFICADO` | deixa de incluir a Organization migrada | consumidores legados devem usar contexto canônico |
| profile visual | `VERIFICADO` | muda para Governo; recruitment default fica desligado | decidir overrides antes da troca |
| UI overrides | `VERIFICADO` | `changeType` trata `ui.profile` como incompatível | snapshot e decisão `dropIncompatible` |
| banco/menu financeiro | `VERIFICADO` | continua aplicável a `government` | capability + flag shared account |
| duty interaction | `VERIFICADO` | continua via `mz_interact`; cor/tema pode mudar | smoke visual/funcional |
| `mz_target`/`mz_radialmenu` do Org | `VERIFICADO` | não existem integrações diretas no runtime atual | nenhuma migração direta |
| target/radial policial | `VERIFICADO` | actions chegam à policy por código/capability/duty, sem gate por tipo | suíte policial |
| `mz_police` | `VERIFICADO` | autoriza allowlist `police`, active, duty e capability; tipo só aparece no snapshot | manter código/capabilities |
| `mz_medical` | `VERIFICADO` | autoriza código `ambulance`, grade, duty e capability | manter código/capabilities |
| `mz_transport` | `BLOQUEADO` | quando `RequireJob=true`, exige `type='job'` | migrar gate para role/capability antes de qualquer org relevante |
| ferramentas Staff/Admin | `PROPOSTO` | filtros/labels mudarão; IDs permanecem | smoke de list/filter/type change |
| recursos externos fora do workspace | `BLOQUEADO` | podem ler `player.job` ou assumir `job` | inventário do deployment real |

### 4.1 Polícia

`VERIFICADO` — `mz_police` autoriza apenas Organizations cujo código está em `MZPoliceConfig.AuthorizedOrganizations`, atualmente `police`, e exige active, duty e capability via `mz_org` (`mz_police/config/server.lua:6-9`; `mz_police/server/policy.lua:76-138`). Ele não exige `type='job'`.

`VERIFICADO` — MDT, tracker, armory e records carregam o `orgCode` autorizado. Manter o código `police` preserva jurisdiction, records e ledger. A troca de tipo não deve renomear esse código.

### 4.2 Hospital

`VERIFICADO` — `mz_medical` aceita o código `ambulance`, grade mínima, duty e capability `ambulance.revive.basic`; não verifica tipo (`mz_medical/config.lua:39-55`; `mz_medical/server/service.lua:246-266`).

`VERIFICADO` — billing hospitalar está desativado (`mz_medical/config.lua:72-79`). Nenhuma receita hospitalar canônica deve ser presumida como existente.

### 4.3 Menus, target e radial

`VERIFICADO` — `government` possui profile, features, filtros e comando próprios. A mudança altera apresentação e agrupamento, não a autoridade (`mz_org/shared/menu_profiles.lua:56-65`; `mz_org/client/main.lua:119-127`; `mz_org/client/menu/router.lua:8-17`).

`VERIFICADO` — o `mz_org` atual não possui `client/target.lua` nem `client/radialmenu.lua`; seus pontos de duty usam `mz_interact` (`mz_org/client/duty_points.lua:5-68`). `mz_police` possui integrações próprias de target/radial, mas a autorização final continua server-side na policy.

## 5. Plano reversível de migração — não executado

### 5.1 Pré-condições

1. `BLOQUEADO` — decidir e implementar o contrato de `institutional_role` no `mz_org`.
2. `BLOQUEADO` — resolver a projeção `player.job` e consumidores externos.
3. `BLOQUEADO` — obter PASS transacional no ambiente descartável.
4. `PROPOSTO` — criar harnesses de regressão em `mz_testkit`, sem testes novos dentro dos resources.
5. `PROPOSTO` — congelar mudanças administrativas de `police`/`ambulance` durante o cutover.

### 5.2 Sequência futura

`PROPOSTO`:

1. capturar backup e baseline de `mz_orgs`, grades, permissions, memberships, contas e saldos;
2. adicionar role `police`/`medical` mantendo `type='job'`;
3. expor role nos DTOs e substituir gates de tipo por role/capability onde necessário;
4. validar polícia, medicina, duty, menus, payroll read-only e integrações;
5. mudar somente `mz_orgs.type_id` pelo caminho auditado/revisionado do `mz_org`;
6. preservar `id`, `code`, flags, config aprovada, grades e memberships;
7. recarregar contextos dos membros online; o fluxo atual já invalida sessions e reidrata membros após mutação (`mz_org/server/domain/staff_mutations.lua:182-198`);
8. comparar baseline e executar smoke tests;
9. manter rollback disponível até a observação terminar.

`VERIFICADO` — o seed não sobrescreve o tipo de uma Organization existente: `ensureOrg` retorna a row quando encontra o código e só usa `def.type` no INSERT inicial (`mz_org/server/domain/default_orgs.lua:96-128`). Logo, a futura migração não será revertida automaticamente pelo seed atual.

### 5.3 Rollback futuro

`PROPOSTO` — rollback deve usar a mesma mutação auditada/revisionada para restaurar `type_id=job`, restaurar overrides de UI/config capturados e reidratar os membros. Não recriar Organizations, contas, grades ou memberships; não renumerar IDs; não compensar saldo.

Gates de rollback:

- saldo e quantidade de ledger rows inalterados pela troca de tipo;
- mesmos `org_id`, grade IDs e membership IDs;
- `player.job` volta a ser projetado após reload;
- duty, capabilities e sessões passam novamente pelos checks canônicos.

## 6. Contratos financeiros reais relevantes

### 6.1 Contas e ledger

`VERIFICADO` — `mz_economy` é owner de:

- saldos pessoais em `mz_player_accounts`;
- um saldo organizacional finito por `org_id` em `mz_org_accounts`;
- idempotência genérica em `mz_account_idempotency`;
- spend/refund organizacional em `mz_org_account_operations`;
- ledger único em `mz_economy_transactions`.

Evidência: `mz_economy/server/prepare.lua:12-102`.

`VERIFICADO` — não existe saldo de Tesouro, transfer entre Organizations, hold governamental, payable de salário ou programa municipal implementado.

### 6.2 Multas

`VERIFICADO` — a cobrança policial atual move `player bank -> police org account`, com duas pernas de ledger e idempotência, e aceita somente caller `mz_police` (`mz_economy/server/accounts/police_charges.lua:44-140`). Essa é uma receita institucional real reutilizável; não é receita automática do Tesouro central.

`BLOQUEADO` — a operação ainda usa locks Lua e writes absolutos do repository. Sua atomicidade sob múltiplos processos/MySQL real não foi certificada nesta Wave.

### 6.3 Payroll

`VERIFICADO` — o scheduler do `mz_org` envia memberships ao Economy; o Economy paga somente memberships com `has_salary`, salary positivo, duty quando exigido e shared account (`mz_org/server/payroll.lua:1-55`; `mz_economy/server/accounts/payroll.lua:66-122`).

`VERIFICADO` — payroll debita a conta da Organization e credita o banco do Character, inclusive offline, com idempotência por Organization/cidadão/bucket (`mz_economy/server/accounts/payroll.lua:174-293`). O tipo da Organization não participa da decisão.

`VERIFICADO` — saldo insuficiente produz `insufficient_org_funds`, adiciona o item à lista `skipped` e gera log detalhado; não existe obrigação salarial persistente nem fila de recuperação (`mz_economy/server/accounts/payroll.lua:98-143,190-212`).

`PROPOSTO` — salário devido e não pago deve futuramente gerar uma obrigação idempotente `pending_budget`, ligada a `org_id + citizenid + payroll_period + salary_fingerprint`. Ela não é saldo nem crédito; permanece passivo financeiro até a conta institucional receber repasse e o Economy efetuar um único pagamento. O payroll atual não será alterado nesta Wave.

## 7. Arquitetura de Tesouro Municipal

### 7.1 Princípio

`PROPOSTO` — usar exclusivamente `mz_org_accounts` como saldos:

```text
Organization municipal_treasury (government/municipal)
  └─ mz_org_accounts: orçamento central finito
       ├─ repasse auditável -> police mz_org_accounts
       ├─ repasse auditável -> ambulance mz_org_accounts
       └─ reserva -> hold Economy-owned -> settlement/release

Receitas tipadas
  player bank -> institution account ou treasury account

Despesas tipadas
  institution/treasury account -> player/vendor/hold

Toda movimentação -> mz_economy_transactions
```

Não criar:

- `government_balance`;
- saldo em `mz_jobs`;
- ledger municipal paralelo;
- moeda implícita em config;
- refill automático.

### 7.2 Contas

| Conta | Implementação | Responsabilidade |
|---|---|---|
| Tesouro central | `mz_org_accounts` de uma Organization `government/municipal` | orçamento geral e programas municipais |
| Polícia | `mz_org_accounts` da Organization `police` existente | multas aprovadas, equipamentos, manutenção e payroll policial |
| Hospital | `mz_org_accounts` da Organization `ambulance` existente | atendimentos/taxas aprovados, equipamentos, manutenção e payroll médico |
| outras instituições | conta canônica por `org_id` | somente após criação/aprovação no `mz_org` |
| holds | obrigação persistente no `mz_economy`, não conta livre | fundos já retirados da disponibilidade e ainda não realizados |

### 7.3 Repasses

`PROPOSTO` — repasse `Treasury -> Institution` deve ser uma transferência Organization-to-Organization tipada no Economy:

1. caller e policy server-side escolhem source/destination; client não envia contas arbitrárias;
2. ambas as contas são lockadas em ordem crescente de `org_id`;
3. saldo do Tesouro é validado;
4. débito, crédito, operation, receipt e duas pernas de ledger são uma transação;
5. replay retorna o mesmo receipt;
6. saldo insuficiente cria rejeição auditável, sem writes financeiros;
7. transferência não conta como income/expense econômico agregado; é realocação interna.

### 7.4 Receitas públicas

| Receita | Situação | Destino recomendado |
|---|---|---|
| multas policiais | `VERIFICADO` existente | conta `police`; split com Tesouro só após policy aprovada |
| atendimentos hospitalares | `BLOQUEADO`/billing desligado | conta `ambulance` via cobrança tipada futura |
| taxas municipais | `PROPOSTO` | Tesouro central via contrato tipado |
| serviços públicos | `PROPOSTO` | instituição prestadora ou Tesouro conforme policy explícita |
| capitalização inicial | `BLOQUEADO` | ver seção 7.6 |

Nenhuma receita deve usar `AddMoney`, `RecordTransaction` isolado ou amount vindo do client.

### 7.5 Despesas públicas

| Despesa | Fonte | Mecanismo |
|---|---|---|
| salários | conta da instituição | payroll atual; pendência futura quando faltar saldo |
| equipamentos | conta da instituição | spend tipado/receipt, após purpose aprovado |
| manutenção | Tesouro ou instituição | contrato tipado com destination/purpose fixos |
| contratos `mz_jobs` | programa ligado ao Tesouro/instituição | reserve/settle/release Economy-owned |
| repasses | Tesouro | org-to-org transfer auditável |

### 7.6 Capitalização finita

`PROPOSTO` — ordem de preferência:

1. receitas públicas reais já liquidadas pelo Economy;
2. transferência de uma fonte canônica existente e identificada;
3. somente em staging limpo, apropriação inicial única, finita, idempotente, com valor aprovado, receipt, ledger `municipal_capitalization`, actor e ambiente registrados.

A opção 3 cria oferta monetária e, portanto, exige decisão humana explícita. Deve ser impossível repetir a mesma appropriation key, estar desabilitada por padrão e não possuir timer de recarga. Depois do bootstrap, o Tesouro cresce apenas por receitas e transferências reais.

`BLOQUEADO` — código da Organization do Tesouro, valor inicial, fonte contábil e aprovadores ainda não foram definidos.

### 7.7 Autorização

`PROPOSTO`:

- `mz_org` continua owner de Organization, membership, role e capabilities;
- `mz_economy` continua owner de saldos, operações, holds, receipts e ledger;
- cada fluxo financeiro tem caller/purpose allowlisted;
- role ajuda a escolher policy, mas nunca autoriza sozinho;
- transferências administrativas exigem capability dedicada e actor resolvido server-side;
- programas system-owned de `mz_jobs` apontam para contas aprovadas; Jobs não escolhe `org_id`;
- nenhum endpoint aceita saldo, before/after, source resource ou receipt fornecido pelo client.

## 8. Segurança transacional observada

### 8.1 Source atual

`VERIFICADO` — o resource importa `@oxmysql/lib/MySQL.lua` e declara dependency `oxmysql`, mas não fixa versão no manifest (`mz_economy/fxmanifest.lua:14-33`). O pacote `oxmysql` não está presente neste workspace.

`VERIFICADO` — `runTransaction` anexa ledger e retorna apenas o boolean de `MySQL.transaction.await` (`mz_economy/server/accounts/repository.lua:22-62`).

`VERIFICADO` — commerce faz UPDATE condicional da conta/operação e anexa ledger incondicionalmente no batch (`mz_economy/server/accounts/repository.lua:140-159`). Depois relê a operation e detecta `balance_conflict`, mas isso não prova que o ledger tenha sido revertido quando o UPDATE afetou zero rows (`mz_economy/server/accounts/org_accounts.lua:678-695`).

`VERIFICADO` — player/org, payroll e transferências de jogador usam valores absolutos calculados antes da transação, sem DB CAS (`mz_economy/server/accounts/repository.lua:77-95,162-227`). Locks Lua reduzem concorrência dentro do processo, mas somem em restart e não protegem outro writer/processo (`mz_economy/server/accounts/service.lua:72-137`).

`VERIFICADO` — não há uso de `SELECT ... FOR UPDATE`, `MySQL.startTransaction`, affected rows, deadlock code ou retry transacional em `mz_economy`, `mz_org` ou `mz_testkit`.

### 8.2 Contrato upstream, não prova do instalado

`VERIFICADO` apenas para a documentação/source upstream consultados:

- `MySQL.transaction.await` retorna boolean e faz rollback quando uma query falha; não expõe affected rows por statement ([documentação oficial](https://overextended.dev/oxmysql/Functions/transaction));
- `MySQL.update.await` retorna affected rows quando chamado diretamente ([documentação oficial](https://overextended.dev/oxmysql/Functions/update));
- o source upstream atual expõe `MySQL.startTransaction`, que mantém queries no contexto de uma transação ([source oficial](https://github.com/overextended/oxmysql/blob/main/lib/MySQL.lua));
- releases recentes incluem correções de commit/rollback em dispose, tornando a versão instalada um gate obrigatório ([releases oficiais](https://github.com/overextended/oxmysql/releases)).

`BLOQUEADO` — não inferir que o resource instalado possui exatamente esse comportamento. É necessário registrar versão/hash do artefato realmente usado pelo FXServer.

### 8.3 Decisão transacional recomendada

`PROPOSTO` — após validação da versão instalada, usar uma transação de conexão única capaz de:

1. buscar operation/hold com lock;
2. lockar contas em ordem determinística;
3. inspecionar `affectedRows`/resultado de cada transição;
4. retornar `false` ou lançar erro antes de inserir ledger quando o CAS perder;
5. gravar balance, hold, operation, receipt e ledger antes do commit;
6. responder somente após commit confirmado;
7. recuperar resposta perdida por `operationKey`/receipt.

Não copiar para funding o padrão atual de batch booleano enquanto o caso zero affected rows não estiver provado.

`PROPOSTO` — deadlock e lock timeout recebem retry somente para códigos DB explicitamente reconhecidos, no máximo três tentativas, com jitter pequeno e a mesma idempotency key. Validação, autorização, saldo insuficiente e conflito idempotente não são retryable.

## 9. Resultados dos testes transacionais

### 9.1 Disponibilidade do ambiente

| Verificação | Resultado |
|---|---|
| resource/source/version de `oxmysql` no workspace | `NOT RUN` — não presente |
| cliente `mysql`/`mariadb` no PATH | `NOT RUN` — não encontrado |
| serviço MySQL/MariaDB local | `NOT RUN` — não encontrado |
| Docker/Podman para DB efêmero | `NOT RUN` — não disponível |
| connection string de staging utilizável | `NOT RUN` — não fornecida/encontrada |

Não foi aberta conexão, criado schema ou alterado saldo.

### 9.2 Matriz solicitada

| Caso | Resultado | Evidência necessária para PASS |
|---|---|---|
| `SELECT ... FOR UPDATE` | `NOT RUN` | segunda sessão bloqueia/serializa e lê saldo atualizado |
| UPDATE condicional com zero rows | `NOT RUN` | affected rows observado; ledger/receipt não commitam |
| rollback | `NOT RUN` | falha injetada deixa todas as tabelas idênticas ao baseline |
| duas reservas concorrentes | `NOT RUN` | no máximo uma vence; saldo nunca negativo |
| settlement vs release | `NOT RUN` | exatamente um terminal e um receipt vencem |
| deadlock | `NOT RUN` | erro identificado, retry bounded, sem duplicação |
| timeout/crash antes do commit | `NOT RUN` | rollback e replay seguro |
| timeout/crash depois do commit | `NOT RUN` | lookup retorna receipt; replay não repete saldo/ledger |

### 9.3 Procedimento reproduzível para staging descartável

`PROPOSTO` — executar em Wave posterior, pelo `mz_testkit`:

1. provisionar MySQL/MariaDB efêmero sem acesso de rede à base real;
2. criar usuário restrito a um schema `mz_tx_lab_<run_id>`;
3. registrar `SELECT VERSION()`, engine, isolation level, sql mode, timezone e versão/hash do `oxmysql`;
4. subir FXServer mínimo com somente `oxmysql` e um resource test-only do `mz_testkit`;
5. criar no schema descartável contas, holds, operations e ledger mínimos;
6. seedar duas contas artificiais, por exemplo Treasury 100 e Player 0;
7. abrir duas conexões/transações coordenadas por barriers do harness;
8. executar cada cenário abaixo, consultar invariantes e salvar resultados sanitizados em `mz_testkit/results/mz_economy`;
9. derrubar resource/conexão nos pontos de crash definidos;
10. ao final, dropar exclusivamente o schema cujo nome foi validado contra o prefixo `mz_tx_lab_`.

Casos obrigatórios:

1. **FOR UPDATE:** A locka Treasury; B tenta lock/update; A debita e commita; B continua com saldo novo.
2. **Zero rows no batch atual:** CAS propositalmente perde; observar se `MySQL.transaction.await` retorna true e se ledger indevido persiste.
3. **Zero rows no primitivo candidato:** affected rows zero força rollback antes do ledger.
4. **Rollback statement N:** injetar unique violation/erro em cada posição da transação.
5. **Reserve race:** duas operações distintas disputam o último saldo.
6. **Idempotency race:** duas chamadas com mesma key/fingerprint retornam o mesmo receipt.
7. **Settle/release race:** barriers liberam ambas simultaneamente; somente uma transição vence.
8. **Deadlock:** duas transferências lockam contas em ordem inversa para provar detecção; produção deve sempre ordenar.
9. **Timeout:** manter lock além do limite e verificar classificação/retry.
10. **Crash before commit:** encerrar resource/conexão antes do commit.
11. **Crash after commit/before response:** commitar, encerrar antes do retorno e repetir a mesma key.
12. **Restart:** subir novamente e consultar operation/hold persistidos.

Critérios globais:

- conservação de valor entre contas + holds;
- exatamente um receipt por operação lógica;
- ledger somente quando a mutação correspondente venceu;
- nenhuma resposta `PASS` baseada apenas em mock;
- nenhum uso de schema ou credencial de produção;
- cleanup confirmado do schema descartável.

## 10. Unidade monetária

### 10.1 Estado atual

`VERIFICADO`:

- balances e amounts persistem como `BIGINT`;
- serviços normalizam com `math.floor` ou exigem `% 1 == 0`;
- comandos e menu rejeitam frações;
- `currency='R$'` é apresentação;
- um salary seed `1200` aparece como `R$ 1.200,00`, não `R$ 12,00`.

### 10.2 Decisão recomendada

`PROPOSTO` — padronizar explicitamente nesta geração:

```text
MoneyAmountV1 = integer de unidade monetária inteira, sem casas fracionárias
campo canônico = amount
currency de apresentação = R$
```

Motivos:

- é compatível com todos os saldos e seeds atuais;
- evita multiplicação silenciosa e corrupção de histórico;
- preserva ledger, limits e relatórios;
- o gameplay atual não exige centavos.

Se centavos forem necessários no futuro, criar `MoneyAmountV2` e uma migração global explícita de escala; não reinterpretar rows antigas.

Limites propostos:

- inteiro positivo nas entradas financeiras;
- cálculo intermediário limitado ao safe integer Lua/JSON;
- saldo persistido nunca negativo;
- limites por purpose/program menores que o limite técnico.

## 11. Hold, settlement, release e expiração

### 11.1 Refinamento do lifecycle

`PROPOSTO` — distinguir reserva de oferta de obrigação já aceita:

```text
reserved_offer
  ├─ offer cancel/expire -> released
  └─ execution accepted -> reserved_execution

reserved_execution
  ├─ cancelled com prova -> released
  ├─ completion committed -> settlement_pending
  └─ prazo excedido/estado ambíguo -> review_required

settlement_pending
  ├─ payment commit -> settled
  └─ erro persistente -> review_required
```

`released` e `settled` são terminais e mutuamente exclusivos. `review_required` mantém o valor reservado; não cria dinheiro e não devolve silenciosamente fundos de trabalho possivelmente concluído.

### 11.2 Dois prazos

`PROPOSTO`:

- `performanceDeadlineAt`: limite server-side para o trabalho ser concluído;
- `settlementDeadlineAt`: prazo posterior, reservado para outbox, timeout e restart;
- `settlementGraceSeconds`: policy fixa do programa, não enviada pelo client.

Uma completion persistida até `performanceDeadlineAt` continua elegível durante a grace. Um novo trabalho concluído depois do performance deadline não é aceito como pontual.

### 11.3 Proteção do pagamento legítimo

`PROPOSTO`:

1. Jobs persiste completion server-authoritative e outbox de settlement na mesma transação de domínio;
2. o hold já deve estar ligado à execução antes da conclusão;
3. Economy locka hold/operation/conta e decide settlement/release por uma única transação;
4. `reserved_execution` ou `settlement_pending` nunca é auto-released apenas porque o relógio venceu;
5. expiração ambígua vira `review_required`, mantendo fundos reservados;
6. operador/reconciler consulta receipt e estado do Jobs antes de settlement ou release auditado;
7. replay usa a mesma operation key e nunca credita duas vezes.

Essa regra troca disponibilidade temporária do orçamento por proteção do trabalhador. É preferível prender verba para revisão a devolver a verba e perder uma remuneração legítima.

### 11.4 Auto-release permitido

`PROPOSTO` — somente holds `reserved_offer` sem execução aceita podem ser automaticamente released no expiry. Cancelamento explícito de uma execução aceita exige prova de estado server-side e reason fechado.

### 11.5 Corridas

| Corrida | Resultado obrigatório |
|---|---|
| accept vs offer expiry | um CAS vence; execution aceita impede auto-release |
| completion vs execution cancel | um estado de domínio vence antes da chamada financeira |
| settlement vs release | um terminal vence; loser retorna receipt/estado atual |
| settlement perto do prazo | completion pontual entra em grace/settlement pending |
| crash após commit | lookup/replay encontra receipt persistido |
| revisão sem decisão | fundos permanecem reservados, sem mint nem perda |

## 12. Salários pendentes

`VERIFICADO` — hoje insuficiência apenas pula o pagamento. Não há dívida salarial persistente.

`PROPOSTO` — futuro fluxo, fora desta Wave:

1. Org determina membership, duty, grade, período e salary;
2. Economy cria/reusa uma obrigação única por período;
3. se houver saldo, paga e liquida;
4. se não houver, marca `pending_budget` sem crédito/ledger de pagamento;
5. Tesouro pode repassar fundos à instituição;
6. reconciler paga obrigações mais antigas com a mesma key;
7. mudança de grade futura não altera retroativamente o fingerprint da obrigação já criada;
8. cancelamento administrativo exige reason e audit.

Não usar hold do contrato de Jobs como dívida salarial e não alterar o payroll existente até um contrato próprio ser aprovado.

## 13. Contratos ilegais e organizações criminosas

`BLOQUEADO` — ficam fora do Tesouro inicial. A conta organizacional atual possui saldo genérico e não modela legal/dirty denomination. `illegal_job` existe como categoria de reporting, não como fonte de funding.

`PROPOSTO` — compatibilidade futura deve usar sponsor e programa separados, sem `institutional_role` governamental, sem acesso ao Tesouro e com policy de moeda/proveniência aprovada. A infraestrutura genérica de idempotência/holds pode ser reaproveitada, mas nunca o programa municipal.

## 14. Riscos de regressão

| Risco | Severidade | Mitigação |
|---|---:|---|
| polícia/hospital deixam de aparecer em `player.job` | alta | resolver contrato antes da migração |
| consumer externo filtra `type='job'` | alta | inventário do deployment e role/capability |
| ledger fantasma após CAS zero | crítica | teste real + transação com affected rows |
| lost update em writes absolutos | crítica | row locks/CAS no DB |
| deadlock sem retry idempotente | alta | lock order + retry bounded |
| response perdida após commit duplica pagamento | crítica | operation/receipt duráveis + lookup |
| hold expira após trabalho concluído | crítica | binding + grace + `review_required` |
| salário insuficiente desaparece | alta | obrigação persistente futura |
| tipo passa a ser usado como permissão | alta | role/type classificam; capability autoriza |
| perfil government esconde recruitment | média | override/UX decidido antes do cutover |
| UI override descartado no type change | média | snapshot + revisão de incompatibilidades |
| capitalização vira faucet | crítica | operação única, finita, idempotente e desabilitada |
| versão real do oxmysql diverge do upstream | crítica | pin/version/hash + suite descartável |

## 15. Escopo exato da próxima implementação recomendada

### Wave 1.5A-2B — Transaction Gate

Somente após aprovação deste relatório:

1. criar em `mz_testkit` um runner de MySQL/FiveM descartável e os 12 cenários da seção 9;
2. registrar versão/hash real de `oxmysql`, DB engine e isolation level;
3. executar characterization do padrão atual sem tocar em dados reais;
4. se e somente se o gate passar, implementar no `mz_economy` um primitivo transacional **interno** com connection-scoped queries, affected rows, lock ordering e deadlock retry;
5. provar o primitivo pelo mesmo runner, incluindo crash após commit;
6. documentar o contrato interno e resultados;
7. não criar exports públicos de funding;
8. não criar Treasury/Organization, programa, hold de produção ou capitalização;
9. não alterar `mz_org`, tipos, `mz_jobs`, `mz_police`, `mz_medical` ou payroll;
10. manter Jobs fail-closed.

Fora da 1.5A-2B:

- `institutional_role` e migração `job -> government`;
- Organization do Tesouro e seed financeiro;
- API pública reserve/settle/release;
- repasses reais;
- pending payroll;
- hospital billing;
- contratos ilegais;
- ativação de Jobs.

Após PASS da 1.5A-2B, uma Wave separada poderá implementar o role institucional e a arquitetura financeira aprovada.

## 16. Evidência local executada

`VERIFICADO` — harnesses existentes, sem modificar arquivos:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\mz_testkit\runners\run-local-suite.ps1 -Suite economy
# SUMMARY total=7 pass=7 failed=0

Push-Location mz_org
lua ..\mz_testkit\tests\mz_org\organization_readiness_contract_harness.lua
# organization_readiness_contract_harness: PASS states=5 fail_closed=2
```

Esses resultados confirmam contratos locais/mockados. Não confirmam MySQL, FiveM runtime, concorrência, rollback ou crash.

## 17. Decisões pendentes

| Decisão | Estado | Gate |
|---|---|---|
| storage/schema de `institutional_role` | `BLOQUEADO` | aprovar owner e contrato no `mz_org` |
| compatibilidade de `player.job` | `BLOQUEADO` | inventariar consumidores do deployment |
| código da Organization do Tesouro | `BLOQUEADO` | aprovar código/role/flags |
| valor e fonte de capitalização | `BLOQUEADO` | decisão humana explícita |
| split de multas/receitas | `BLOQUEADO` | policy financeira |
| versão/hash real do oxmysql | `BLOQUEADO` | staging/FXServer disponível |
| engine e isolation level | `BLOQUEADO` | staging disponível |
| primitivo `startTransaction` ou alternativa | `BLOQUEADO` | suite real da seção 9 |
| TTL/grace/review SLA | `BLOQUEADO` | balanceamento + operação |
| pending payroll contract | `PROPOSTO` | Wave própria; payroll atual preservado |
| migração polícia/hospital | `BLOQUEADO` | role + consumer migration + regression PASS |

## 18. NOT RUN

- FXServer/OneSync runtime;
- MySQL/MariaDB real;
- versão instalada de `oxmysql`;
- isolation level real;
- `SELECT ... FOR UPDATE`;
- zero affected rows dentro de transaction batch;
- rollback e falhas por statement;
- reservas concorrentes;
- settlement vs release;
- deadlock/lock timeout/retry;
- crash antes/depois de commit;
- DDL descartável ou de produção;
- capitalização/repasses/holds;
- payroll com insuficiência em runtime;
- migração ou rollback `job -> government`;
- smoke runtime de polícia, hospital, target, radial ou menus.

## 19. Impacto arquitetural desta auditoria

- contratos públicos: nenhum alterado; nomes futuros não foram fixados;
- canonical ownership: inalterado; Org possui Organization/role, Economy possui dinheiro/ledger/holds;
- writer/authority: inalterado;
- dependências cross-resource: nenhuma criada;
- persistência/database: nenhum schema ou dado alterado;
- segurança/permissões: inalteradas; capabilities continuam autoridade;
- exports/events/callbacks/adapters: nenhum criado ou modificado;
- external dependencies: documentação upstream consultada, versão instalada ainda desconhecida;
- Graphify scope used: consulta read-only cross-resource;
- Graphify synchronization: não requerida para auditoria documental;
- Graphify validation: `NOT APPLICABLE`;
- runtime validation: `NOT RUN`;
- implementação seguinte: aguardando aprovação.
