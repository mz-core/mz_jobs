# MZ Framework — Wave 1.5A-2B — Transaction Gate

**Data:** 2026-10-26  
**Workspace:** `D:\git-hub\repo_oficial`  
**Escopo de produção alterado:** nenhum  
**Banco real acessado:** não  
**DDL executado:** nenhum  
**Fase 3:** `BLOCKED / NOT STARTED`  
**Funding/Tesouro/holds reais:** não iniciados

## 1. Classificação e resultado do gate

- `VERIFICADO`: observado no filesystem/source atual ou em validação local executada.
- `PROPOSTO`: estratégia ainda não implementada no runtime financeiro.
- `BLOQUEADO`: pré-condição obrigatória ausente ou risco que impede a Fase 3.
- `NOT RUN`: não houve execução real daquele cenário em MySQL/oxmysql/FXServer.

### Conclusão executiva

`VERIFICADO` — foi localizada uma instalação de FXServer e oxmysql configurada em `D:\mz_staging`. O resource instalado é oxmysql **2.14.1**, e o `resources.cfg` desse staging contém `ensure oxmysql` e `ensure mz_economy`. Não havia processo FXServer/MySQL ativo no momento da inspeção.

`BLOQUEADO` — o banco referenciado por esse staging não foi provado descartável. Seu arquivo de configuração existe, mas não foi lido, copiado ou usado. O Docker CLI está instalado, porém o daemon está parado; também não havia cliente/serviço MySQL local nem `MZ_TX_LAB_LICENSE_KEY` disponível. Assim, não existia ambiente simultaneamente isolado, operacional e autorizado para executar os 12 casos.

`VERIFICADO` — foi criado no `mz_testkit` um laboratório executável, opt-in e fail-closed. O modo padrão é somente `Preflight`; o modo `Execute` exige explicitamente `-ConfirmDisposableLab`, Docker ativo, licença via variável de ambiente e os executáveis observados. A execução cria um MySQL efêmero ligado apenas a `127.0.0.1`, com schema `mz_tx_lab_<run_id>` e usuário restrito.

`NOT RUN` — nenhum dos 12 cenários recebeu `PASS` ou `FAIL` de banco real. Não foi criada evidência artificial a partir de mocks ou documentação.

`BLOQUEADO` — nenhum primitivo foi adicionado ao `mz_economy`. Além da ausência de execução real, o bundle 2.14.1 observado expõe riscos que precisam ser caracterizados no laboratório: `MySQL.startTransaction` é experimental, retorna somente sucesso booleano na falha capturada e seu bundle chama `commit()` pelo disposer sem aguardar explicitamente o Promise. Isso impede afirmar hoje que deadlock e lock timeout podem ser classificados e repetidos com segurança.

## 2. Método e guarda de segurança

`VERIFICADO` — foram lidos os relatórios 1.5A-1 e 1.5A-2A, `DECISIONS.md`, os arquivos financeiros obrigatórios do `mz_economy`, o README/registry/runners do `mz_testkit` e o código instalado do oxmysql.

`VERIFICADO` — Graphify foi usado para descoberta cross-resource. O resultado incluiu muito material histórico; todas as conclusões deste relatório foram confirmadas no source real.

`VERIFICADO` — antes de qualquer arquivo novo, foram inspecionados os estados locais dos repositórios. `mz_economy` e `mz_testkit` já possuíam mudanças extensas. Nenhuma delas foi sobrescrita, formatada ou movida.

Guardas aplicadas:

1. nenhuma conexão foi aberta usando `D:\mz_staging\cfg\database.cfg` ou `D:\mz_multichar_staging\cfg\database.cfg`;
2. nenhum conteúdo de credencial foi impresso;
3. Docker Desktop não foi iniciado automaticamente;
4. nenhum server.cfg existente foi alterado;
5. nenhum DDL ou DML foi enviado;
6. o runner real só aceita um container criado por ele e valida o label do run antes de removê-lo;
7. o diretório temporário só pode ser apagado se estiver sob o temp do sistema e se seu nome for exatamente `mz_tx_lab_<run_id>`;
8. o resource Lua valida `SELECT DATABASE()` antes de criar qualquer tabela;
9. o schema observado deve ser exatamente igual ao schema gerado;
10. logs persistidos pelo runner removem URI MySQL, password e licença.

## 3. Ambiente e proveniência observados

### 3.1 FXServer

| Campo | Resultado |
|---|---|
| caminho | `D:\mz_staging\server\FXServer.exe` |
| arquivo presente | `VERIFICADO` |
| processo ativo | não encontrado |
| tamanho | 292.448 bytes |
| SHA-256 | `291E48DC52F75A68EB3FACA3F675E6DDA6C978FDBEE3F11BFA62C588676F535B` |
| FileVersion/ProductVersion | `1.0.0.0`; não identifica o artifact build de forma suficiente |
| execução nesta Wave | `NOT RUN` |

`BLOQUEADO` — o build canônico do artifact não pôde ser inferido com segurança apenas pelo metadata do executável. O hash acima é a proveniência local utilizável.

### 3.2 oxmysql observado

| Campo | Resultado |
|---|---|
| caminho | `D:\mz_staging\resources\[ox]\oxmysql` |
| carregamento configurado | `ensure oxmysql` em `D:\mz_staging\cfg\resources.cfg:15` |
| Economy configurado | `ensure mz_economy` em `D:\mz_staging\cfg\resources.cfg:25` |
| versão manifest | `2.14.1` |
| `fxmanifest.lua` SHA-256 | `AFC0C9F4C093F455F4AD23F4EFF2F462239086F721CE5938E9765050C8600667` |
| `lib/MySQL.lua` SHA-256 | `61F3ADEC813D1D2ED342505A1110ECFEEB1465690C929B205F8F0CE3136C7385` |
| `dist/build.js` SHA-256 | `8E6405003E3F46602C94B23AE8D96677F775A2DE65BEFF1BE8BB93785B517063` |
| execução nesta Wave | `NOT RUN` |

`VERIFICADO` — a instalação em `D:\mz_multichar_staging\resources\[ox]\oxmysql` possui os mesmos hashes. Esse segundo staging não contém `server\FXServer.exe` no layout observado.

`VERIFICADO` no source instalado:

- `lib/MySQL.lua:151-153` expõe `MySQL.startTransaction`;
- `dist/build.js:27296-27324` abre uma conexão, inicia a transação, executa o callback e converte o retorno em boolean;
- erro capturado chama `logError`, faz rollback e deixa a resposta como `false`;
- `dist/build.js:26748-26763` mantém um flag de transaction e chama `commit()` em `Symbol.dispose` sem `await` explícito;
- `dist/build.js:27372-27375` rotula `startTransaction` como experimental.

Esses pontos descrevem o código, não comprovam o timing real de commit/rollback no FXServer.

### 3.3 Banco e container

| Verificação | Resultado |
|---|---|
| cliente Docker | `VERIFICADO`, versão client 29.4.3 |
| Docker daemon | indisponível |
| imagem MySQL local | `NOT RUN`, daemon indisponível |
| cliente `mysql`/`mariadb` no host | não encontrado |
| serviço MySQL/MariaDB no host | não encontrado |
| engine/versão DB | `NOT RUN` |
| isolation level | `NOT RUN` |
| `sql_mode` | `NOT RUN` |
| timezone | `NOT RUN` |
| schema descartável criado | não |

O harness coleta `VERSION()`, `version_comment`, `transaction_isolation`, `sql_mode`, `time_zone` e `system_time_zone` somente depois de validar o schema descartável.

## 4. Arquivos criados, backups e diff

### 4.1 Criados

| Arquivo | Papel |
|---|---|
| `mz_testkit/runners/run-mz-economy-transaction-gate.ps1` | preflight, container efêmero, três boots FXServer, sanitização e cleanup |
| `mz_testkit/tests/mz_economy/transaction_gate/fxmanifest.lua` | resource test-only; carrega somente oxmysql e o harness |
| `mz_testkit/tests/mz_economy/transaction_gate/server.lua` | guardas e 12 cenários reais |
| `mz_testkit/tests/mz_economy/transaction_gate/README.md` | execução segura e limites |
| `mz_jobs/docs/WAVE_1_5A_2B_TRANSACTION_GATE_REPORT.md` | este relatório |

### 4.2 Alterados

Nenhum arquivo preexistente foi alterado por esta Wave.

### 4.3 Backups

Nenhum backup foi necessário porque todos os arquivos da entrega são novos. Os arquivos preexistentes inspecionados permaneceram byte a byte fora do diff desta tarefa.

### 4.4 Registry

`VERIFICADO` — o registry atual declara `registeredEntries=64`, mas contém 67 entradas reais. Não há IDs duplicados nem paths registrados ausentes; o profile FiveM possui quatro entradas coerentes com suas quatro suites.

`BLOQUEADO` — `mz_testkit/registry/tests.json`, `README.md` e `runners/run-local-suite.ps1` já contêm alterações locais preexistentes. Conforme a regra do testkit, esta Wave não reescreveu o registry compartilhado. A suíte possui runner dedicado e documentação; integração no registry fica pendente de consolidação das mudanças existentes.

## 5. Arquitetura do laboratório

```text
run-mz-economy-transaction-gate.ps1
  ├─ Preflight (default, read-only)
  │    ├─ valida 12 cenários e guardas
  │    ├─ identifica hashes do FXServer/oxmysql
  │    └─ nunca inicia DB/FXServer
  └─ Execute + -ConfirmDisposableLab
       ├─ container MySQL efêmero, bind 127.0.0.1
       ├─ database mz_tx_lab_<run_id>
       ├─ usuário restrito ao database gerado
       ├─ runtime temporário: oxmysql + mz_tx_gate
       ├─ boot 1: crash_before
       ├─ boot 2: main
       ├─ boot 3: recovery
       ├─ resultado/logs sanitizados em mz_testkit/results/
       └─ cleanup por container label + temp path estritos
```

Tabelas artificiais do lab:

- `tx_gate_accounts`;
- `tx_gate_holds`;
- `tx_gate_operations`;
- `tx_gate_receipts`;
- `tx_gate_ledger`.

Elas existem somente no database efêmero. Nenhum nome canônico do MZ é usado e nenhuma tabela real é consultada.

## 6. Matriz dos 12 cenários

| # | Cenário | Resultado | Método preparado | Evidência ausente para PASS |
|---:|---|---|---|---|
| 1 | `SELECT ... FOR UPDATE` com duas conexões | `NOT RUN` | duas `MySQL.startTransaction` coordenadas; mede bloqueio e saldo visto por B | timestamps e resultado persistido do FXServer |
| 2 | CAS zero rows no batch antigo | `NOT RUN` | `MySQL.transaction.await` com UPDATE impossível seguido de ledger | boolean retornado, saldo e ledger reais |
| 3 | CAS zero rows no candidato | `NOT RUN` | `startTransaction`, lê `affectedRows`, retorna false antes do ledger | rollback real e zero ledger |
| 4 | erro em cada etapa | `NOT RUN` | quatro transações com erro SQL após cada mutação | invariantes consultadas após cada rollback |
| 5 | duas reservas pelo saldo final | `NOT RUN` | duas conexões lockam a mesma conta | um winner, saldo zero, uma operation/receipt/ledger |
| 6 | mesma operationKey/fingerprint | `NOT RUN` | `INSERT IGNORE` + row lock + replay | dois retornos equivalentes e uma mutação |
| 7 | settle versus release | `NOT RUN` | duas conexões disputam hold `reserved` | um terminal e conservação de 100 unidades |
| 8 | deadlock e retry | `NOT RUN` | lock order inverso na primeira tentativa; retry até 3 somente se código reconhecido | código 1213/`ER_LOCK_DEADLOCK` entregue por chamada |
| 9 | lock timeout | `NOT RUN` | timeout de sessão de 1 s; retry até 3 somente se código reconhecido | código 1205/`ER_LOCK_WAIT_TIMEOUT` entregue por chamada |
| 10 | queda antes do commit | `NOT RUN` | runner mata o FXServer após marker dentro da transação aberta | restart prova saldo/operation intactos |
| 11 | commit e resposta perdida | `NOT RUN` | commita, descarta receipt no processo e força stop | dados persistidos após restart |
| 12 | restart e lookup/replay | `NOT RUN` | terceiro boot busca e repete a mesma key | mesmo receipt, contagens e saldo inalterados |

Critério global implementado pelo resultado final: 12 resultados, zero `FAIL`, zero `NOT_RUN`; caso contrário o campo `gate` é `BLOCKED` e o runner termina com código não zero.

## 7. CAS zero rows no padrão atual

`VERIFICADO` — `mz_economy/server/accounts/repository.lua:51-62` anexa o ledger ao batch e retorna somente `MySQL.transaction.await(statements) == true`.

`VERIFICADO` — `applyOrgAccountOperation` usa UPDATE condicional por status e saldo anterior, mas não obtém o número de linhas afetadas antes de o ledger do mesmo batch ser executado (`repository.lua:140-159`).

`VERIFICADO` no bundle instalado — o batch transacional do oxmysql trata ausência de erro SQL como sucesso; zero affected rows não é, por si, erro SQL.

`NOT RUN` — não foi observado em MySQL real se o padrão antigo retorna `true` e persiste ledger após um CAS de zero rows. O cenário 2 existe especificamente para obter essa evidência. Até sua execução, o risco permanece:

```text
UPDATE CAS -> 0 rows
INSERT ledger -> sucesso
transaction bool -> possivelmente true
resultado possível -> ledger fantasma
```

Nenhuma rota legada foi corrigida nesta Wave.

## 8. Estratégia candidata para transação interna

`PROPOSTO`, condicionada ao gate real:

1. executar tudo em uma única conexão/transação;
2. ordenar locks por tipo e ID canônicos antes da primeira query;
3. lockar operation/hold e contas com `SELECT ... FOR UPDATE`;
4. inspecionar `affectedRows` imediatamente após cada CAS;
5. retornar `false` antes de receipt/ledger se o CAS perder;
6. gravar saldo, operation, receipt e ledger antes do commit;
7. responder somente após commit comprovado pela versão instalada;
8. replay consultar a mesma operationKey/fingerprint;
9. retry somente para deadlock e lock timeout identificados de forma estruturada;
10. no máximo três tentativas, mesma operationKey e backoff pequeno;
11. nunca repetir autorização, validação, saldo insuficiente ou conflito idempotente.

Ordem de lock proposta:

```text
operation/receipt key
  -> hold id
  -> account ids em ordem lexical/numericamente estável
```

`BLOQUEADO` — no oxmysql 2.14.1 observado, a implementação de `startTransaction` captura o erro e retorna boolean quando não há callback de erro. Assim, o caller Lua não recebe, pelo contrato observado, um código transacional estruturado confiável para separar deadlock, lock timeout, SQL inválido ou perda de conexão.

Alternativas que exigem decisão e teste, sem implementação automática:

- atualizar/pinar oxmysql para versão cuja assinatura realmente devolva o erro estruturado, e repetir os 12 casos;
- adicionar ao owner de infraestrutura uma extensão pequena e versionada que preserve connection scope e retorne `{ok, code}`, seguida do mesmo lab;
- não usar retry automático e tratar falha como estado recuperável por replay externo — insuficiente para o requisito atual de retry reconhecido.

Não é aceitável analisar texto do console global como mecanismo de produção.

## 9. Estado da Fase 3

**Estado:** `BLOCKED / NOT STARTED`.

Motivos cumulativos:

1. Docker daemon indisponível;
2. nenhum DB efêmero foi criado;
3. FXServer/oxmysql não foram executados;
4. 12 cenários permanecem `NOT RUN`;
5. commit via disposer não foi caracterizado no runtime;
6. códigos de deadlock/timeout não são retornados pelo contrato Lua observado;
7. um módulo sem consumidor seria código morto e foi proibido pela própria Wave.

Consequentemente:

- nenhum arquivo do `mz_economy` foi criado ou alterado;
- nenhum `server_script` foi adicionado ao manifest;
- nenhum export/event/callback foi criado;
- nenhum comportamento das rotas existentes mudou.

## 10. Compatibilidade e riscos das rotas atuais

| Rota/padrão | Estado nesta Wave | Risco ainda aberto |
|---|---|---|
| contas pessoais | inalterado | writes absolutos dependem dos locks Lua/single writer |
| transfer player/player | inalterado | concorrência DB não caracterizada |
| Organization deposit/withdraw | inalterado | transação real não caracterizada |
| commerce org | inalterado | CAS zero rows pode não abortar ledger |
| polícia | inalterado | cálculo prévio + writes absolutos; sem prova multiprocesso |
| payroll | inalterado | cálculo prévio + writes absolutos; sem pending salary |
| ledger | inalterado | depende de atomicidade do batch real |
| idempotência | inalterada | replay local testado por mock, crash real não testado |

Os harnesses locais existentes não substituem MySQL/FXServer. Nenhuma regressão dessas rotas foi introduzida porque elas não foram editadas.

## 11. Validação executada

### 11.1 Harness novo

```text
PowerShell parser: PASS
luac -p server.lua: PASS
HARNESS_CONTRACT: PASS scenarios=12 safety_gate=present
Execute sem -ConfirmDisposableLab: PASS fail-closed, exit code 1
TRANSACTION_GATE: NOT_RUN executable_ready=False explicit_confirmation=false
```

O `Preflight` registrou a versão e os três hashes do oxmysql sem abrir conexão.

### 11.2 Regressão local existente

```text
powershell -NoProfile -ExecutionPolicy Bypass \
  -File .\mz_testkit\runners\run-local-suite.ps1 -Suite economy

SUMMARY total=7 pass=7 failed=0
```

Classificação: `VERIFICADO` somente como harness local/mockado. Não prova FiveM, MySQL, concorrência, rollback ou crash.

### 11.3 Não executado

- Docker/MySQL real;
- FXServer;
- oxmysql runtime;
- DDL do lab;
- os 12 cenários;
- cleanup real de container/schema;
- `mz_economy` runtime;
- qualquer banco persistente.

## 12. Gate para a próxima execução

Pré-condições operacionais:

1. iniciar deliberadamente o Docker daemon;
2. fornecer `MZ_TX_LAB_LICENSE_KEY` fora de logs e arquivos versionados;
3. revisar os paths e hashes exibidos pelo `Preflight`;
4. confirmar que nenhuma configuração de banco persistente será usada;
5. executar:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass `
  -File .\mz_testkit\runners\run-mz-economy-transaction-gate.ps1 `
  -Mode Execute -ConfirmDisposableLab
```

Após a execução:

- `PASS 12/12` com código estruturado e commit/rollback comprovados permite revisar a Fase 3;
- qualquer `FAIL`, `NOT_RUN`, cleanup incompleto ou ausência de erro estruturado mantém `BLOCKED`;
- a Fase 3 ainda exige aprovação específica porque o primitivo sem consumidor pode continuar injustificado.

## 13. Ausências confirmadas

`VERIFICADO`:

- `mz_core` não alterado;
- `mz_org` não alterado;
- runtime de `mz_jobs` não alterado;
- `mz_inventory`, `mz_police`, `mz_medical`, `mz_population` e `mz_starter` não alterados;
- `server.cfg` não alterado;
- payroll não alterado;
- schemas/dados reais não acessados;
- branch/worktree/commit não criados;
- funding API, Tesouro, holds reais, repasses, pending payroll e `institutional_role` não iniciados;
- Jobs não ativado.

## 14. Impacto arquitetural

- contratos públicos: nenhum;
- canonical ownership: inalterado; `mz_economy` continua owner financeiro;
- writer/authority: inalterado;
- dependências cross-resource de produção: nenhuma;
- persistência/database de produção: nenhuma mudança;
- segurança/permissões: inalteradas;
- exports/events/callbacks/adapters: nenhum novo;
- external dependencies: harness opcional usa Docker, FXServer e oxmysql observados;
- Graphify scope used: consulta cross-resource read-only;
- Graphify synchronization: não requerida; somente QA test-only e relatório foram adicionados;
- Graphify validation: `NOT APPLICABLE`;
- pending architectural validation: execução real dos 12 cenários e decisão sobre erro estruturado;
- próxima implementação: não iniciada; aguarda revisão deste relatório.
