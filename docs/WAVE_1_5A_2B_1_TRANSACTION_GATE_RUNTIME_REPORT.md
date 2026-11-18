# MZ Framework — Wave 1.5A-2B.1 — Transaction Gate Runtime

**Data da inspeção:** 2026-11-05  
**Workspace:** `D:\git-hub\repo_oficial`  
**Resultado:** `BLOCKED`  
**Transaction Gate real:** `NOT RUN`  
**Recursos de produção alterados:** nenhum  
**Banco ou configuração persistente acessados:** não  
**Docker/FXServer iniciados:** não

## 1. Resultado executivo

`VERIFICADO` — o modo padrão `Preflight` foi executado com código de saída `0`. O contrato estático do harness reconheceu os 12 cenários e as guardas de isolamento.

`VERIFICADO` — foram encontrados o FXServer em `D:\mz_staging\server\FXServer.exe` e o oxmysql 2.14.1 em `D:\mz_staging\resources\[ox]\oxmysql`. Os hashes observados coincidem com o relatório da Wave 1.5A-2B.

`BLOCKED` — o Docker CLI existe, mas o daemon do Docker Desktop está parado. A conexão com `dockerDesktopLinuxEngine` falhou sem iniciar serviço ou processo.

`BLOCKED` — `MZ_TX_LAB_LICENSE_KEY` não está definida na sessão. Nenhum valor de licença foi lido, solicitado no chat, impresso ou persistido.

`NOT RUN` — como duas pré-condições obrigatórias estão ausentes, o runner informou `executable_ready=False`. Conforme o gate da tarefa, não houve confirmação operacional para execução, não foram iniciados Docker Desktop, container ou FXServer e nenhum dos 12 cenários recebeu `PASS` ou `FAIL`.

`BLOCKED` — a recomendação sobre o primitivo transacional permanece condicionada à execução real. Nenhuma implementação no `mz_economy` foi iniciada.

## 2. Escopo e método

Foram lidos integralmente:

- `mz_jobs/docs/WAVE_1_5A_2B_TRANSACTION_GATE_REPORT.md`;
- `mz_jobs/docs/WAVE_1_5A_2A_GOVERNMENT_TRANSACTION_REPORT.md`;
- `mz_testkit/runners/run-mz-economy-transaction-gate.ps1`;
- `mz_testkit/tests/mz_economy/transaction_gate/README.md`;
- `mz_testkit/tests/mz_economy/transaction_gate/server.lua`;
- `mz_testkit/tests/mz_economy/transaction_gate/fxmanifest.lua`.

`VERIFICADO` — Graphify foi consultado para descoberta, mas o resultado foi ruidoso para o harness novo. As conclusões deste relatório vêm dos arquivos reais e do `Preflight`.

`VERIFICADO` — `D:\git-hub\repo_oficial` é um agregador de repositórios e não possui `.git` na raiz. Na inspeção imediatamente anterior ao `Preflight`, os repositórios `mz_jobs` e `mz_testkit` retornaram zero entradas em `git status --porcelain=v1 -uall`. Nenhuma alteração preexistente foi resetada, movida ou sobrescrita.

## 3. Comandos executados

Comando canônico executado, sem parâmetros de execução e sem segredo:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass `
  -File .\mz_testkit\runners\run-mz-economy-transaction-gate.ps1
```

Verificações read-only adicionais:

```powershell
docker version --format 'client={{.Client.Version}} server={{.Server.Version}}'
Get-Service -Name 'com.docker.service'
Get-Process -Name 'FXServer'
Get-FileHash <FXServer/oxmysql artifacts> -Algorithm SHA256
git -C mz_jobs status --porcelain=v1 -uall
git -C mz_testkit status --porcelain=v1 -uall
```

Não foram executados:

- `-Mode Execute`;
- `-ConfirmDisposableLab`;
- `docker run`, `docker pull`, `docker start` ou `docker rm`;
- inicialização de Docker Desktop/serviço;
- inicialização de FXServer;
- conexão MySQL;
- DDL ou DML;
- leitura de `D:\mz_staging\cfg\database.cfg` ou de qualquer configuração persistente de banco.

## 4. Evidência sanitizada do Preflight

```text
HARNESS_CONTRACT PASS scenarios=12 safety_gate=present
ENVIRONMENT fxserver=True oxmysql=True docker_daemon=False license_env=False
OXMYSQL version=2.14.1
  manifest_sha256=AFC0C9F4C093F455F4AD23F4EFF2F462239086F721CE5938E9765050C8600667
  library_sha256=61F3ADEC813D1D2ED342505A1110ECFEEB1465690C929B205F8F0CE3136C7385
  build_sha256=8E6405003E3F46602C94B23AE8D96677F775A2DE65BEFF1BE8BB93785B517063
TRANSACTION_GATE NOT_RUN executable_ready=False explicit_confirmation=false
```

Código de saída: `0`. Esse código significa que o `Preflight` terminou corretamente; não significa que o gate runtime passou.

## 5. Ambiente observado

| Componente | Estado | Evidência |
|---|---|---|
| Docker CLI | `VERIFICADO` | client `29.4.3` |
| Docker daemon | `BLOCKED` | pipe `dockerDesktopLinuxEngine` ausente |
| serviço Docker Desktop | `BLOCKED` | `Stopped`, start type `Manual` |
| processos Docker Desktop | `VERIFICADO` | nenhum encontrado |
| FXServer | `VERIFICADO` | arquivo presente; nenhum processo ativo |
| FXServer SHA-256 | `VERIFICADO` | `291E48DC52F75A68EB3FACA3F675E6DDA6C978FDBEE3F11BFA62C588676F535B` |
| oxmysql | `VERIFICADO` | versão `2.14.1` |
| oxmysql manifest SHA-256 | `VERIFICADO` | `AFC0C9F4C093F455F4AD23F4EFF2F462239086F721CE5938E9765050C8600667` |
| oxmysql library SHA-256 | `VERIFICADO` | `61F3ADEC813D1D2ED342505A1110ECFEEB1465690C929B205F8F0CE3136C7385` |
| oxmysql build SHA-256 | `VERIFICADO` | `8E6405003E3F46602C94B23AE8D96677F775A2DE65BEFF1BE8BB93785B517063` |
| `MZ_TX_LAB_LICENSE_KEY` | `BLOCKED` | variável ausente; conteúdo nunca lido |
| imagem MySQL 8.4 | `NOT RUN` | daemon indisponível |
| `VERSION()` | `NOT RUN` | nenhuma conexão aberta |
| isolation level | `NOT RUN` | nenhuma conexão aberta |
| SQL mode/timezone | `NOT RUN` | nenhuma conexão aberta |

## 6. Prova de isolamento no código

`VERIFICADO` no runner, ainda não provado em execução:

1. `Preflight` é o default (`run-mz-economy-transaction-gate.ps1:1-8`) e retorna antes de criar qualquer recurso (`:281-285`).
2. `Execute` exige `-ConfirmDisposableLab`, FXServer, oxmysql, Docker daemon e licença (`:287-293`).
3. O run id é hexadecimal aleatório de 12 caracteres e o schema é `mz_tx_lab_<run_id>` (`:295-296`).
4. A configuração de FXServer é gerada no temp do sistema, não em staging, e recebe a connection string criada pelo runner (`:146-170`, `:299-305`).
5. O container solicitado usa a imagem `mysql:8.4` por padrão, database gerado e bind dinâmico somente em `127.0.0.1::3306` (`:319-327`).
6. O usuário restrito precisa resolver `SELECT DATABASE()` exatamente para o schema gerado antes do FXServer (`:349-358`).
7. Os três boots são `crash_before`, `main` e `recovery` (`:362-376`).
8. O resource Lua repete a validação do prefixo e do schema atual antes de criar tabelas (`server.lua:2`, `:145-155`).
9. As únicas tabelas criadas são `tx_gate_accounts`, `tx_gate_holds`, `tx_gate_operations`, `tx_gate_receipts` e `tx_gate_ledger` (`server.lua:160-187`).
10. Logs persistidos têm URI, password e licença redigidos (`run-mz-economy-transaction-gate.ps1:200-218`).
11. O cleanup de container exige label igual ao run id; o cleanup do diretório exige temp root e leaf exatos (`:407-421`).

`VERIFICADO` — o runner não lê `database.cfg`, não usa `server.cfg` persistente e não carrega `mz_economy` ou outro resource de produção.

`NOT RUN` — bind, usuário restrito, schema, três boots, sanitização runtime e cleanup não foram exercitados nesta sessão.

## 7. Resultados individualizados

| # | Cenário | Resultado | Método preparado | Evidência runtime |
|---:|---|---|---|---|
| 1 | `SELECT ... FOR UPDATE` em duas conexões | `NOT RUN` | duas `MySQL.startTransaction` coordenadas | nenhuma; conexões não abertas |
| 2 | CAS zero rows no batch legado | `NOT RUN` | `MySQL.transaction.await` + ledger subsequente | retorno, saldo e ledger não observados |
| 3 | CAS zero rows no candidato | `NOT RUN` | affected rows e rollback antes do ledger | rollback e zero ledger não observados |
| 4 | falha em quatro posições | `NOT RUN` | erro SQL após cada estágio | invariantes não consultadas |
| 5 | corrida de duas reservas | `NOT RUN` | duas transações disputam saldo final | winners/saldo/receipt/ledger não observados |
| 6 | corrida idempotente | `NOT RUN` | mesma operation key/fingerprint | replay único não observado |
| 7 | settlement versus release | `NOT RUN` | duas transações disputam hold | terminal único e conservação não observados |
| 8 | deadlock e retry | `NOT RUN` | lock order inverso; retry condicionado ao erro | código 1213/erro estruturado não observado |
| 9 | lock timeout e retry | `NOT RUN` | timeout de sessão; retry condicionado ao erro | código 1205/erro estruturado não observado |
| 10 | crash antes do commit | `NOT RUN` | stop forçado após marker em transação aberta | rollback após restart não observado |
| 11 | commit com resposta perdida | `NOT RUN` | commit, stop e recuperação | persistência após restart não observada |
| 12 | restart, lookup e replay | `NOT RUN` | terceiro boot busca mesma operation key | receipt/contagens imutáveis não observados |

### Invariantes

Todas permanecem `NOT RUN`:

- conservação de saldos + holds;
- exatamente um receipt por operação lógica;
- ledger somente para mutação vencedora;
- rollback integral em falha/crash antes do commit;
- replay sem novo débito/crédito/ledger;
- concorrência real em conexões distintas;
- classificação estruturada de deadlock e timeout.

## 8. Crashes e concorrência

`VERIFICADO` no código — o runner força o encerramento do processo após cada marker de fase. Em `crash_before`, o marker é escrito depois de UPDATE/operation dentro de uma transação que permanece aberta por 60 segundos; em `main`, o marker vem depois do commit da operação de resposta perdida; `recovery` reinicia o FXServer e valida persistência/replay.

`NOT RUN` — não há evidência runtime de que o kill ocorreu nos checkpoints, de que duas coroutines receberam conexões físicas distintas ou de que o commit/rollback terminou antes do retorno do oxmysql 2.14.1.

## 9. Cleanup

`VERIFICADO` após a inspeção:

- nenhum processo `FXServer` ativo;
- nenhum processo Docker Desktop ativo;
- nenhum container foi criado por esta Wave;
- nenhum schema `mz_tx_lab_*` foi criado;
- nenhum temp root `mz_tx_lab_<run_id>` foi criado pelo runner;
- nenhum resultado runtime foi produzido.

`NOT RUN` — o cleanup destrutivo do lab não foi exercitado, porque a execução parou antes da criação de recursos. Não existe ID de container ou caminho temporário desta sessão a remover.

## 10. Riscos confirmados, refutados e ainda abertos

### Confirmados

- `BLOCKED`: sem Docker daemon não há MySQL efêmero.
- `BLOCKED`: sem licença na sessão o FXServer não pode ser iniciado pelo runner.
- `VERIFICADO`: o gate falha fechado e não tenta criar recursos no modo padrão.
- `VERIFICADO`: oxmysql instalado continua sendo 2.14.1 com os hashes esperados.

### Refutados nesta inspeção

- não houve uso acidental de configuração persistente de banco;
- não houve inicialização automática do Docker Desktop;
- não houve execução implícita de FXServer, DDL ou DML pelo `Preflight`.

### Ainda abertos

- comportamento de CAS com zero affected rows no batch legado;
- commit/rollback de `MySQL.startTransaction` 2.14.1;
- disponibilidade de erro estruturado para 1213/1205;
- retry bounded sem duplicação;
- crash antes/depois do commit e replay após restart;
- uso de conexões distintas nas corridas;
- efetividade do cleanup após execução real.

## 11. Instruções operacionais para desbloqueio

Executar localmente, em uma nova sessão PowerShell, sem colar a licença no chat, em arquivo ou em histórico compartilhado:

1. iniciar deliberadamente o Docker Desktop pela interface local;
2. aguardar `docker info` retornar sucesso;
3. capturar a licença sem eco no console:

```powershell
$secureLicense = Read-Host 'MZ_TX_LAB_LICENSE_KEY' -AsSecureString
$env:MZ_TX_LAB_LICENSE_KEY = [System.Net.NetworkCredential]::new('', $secureLicense).Password
Remove-Variable secureLicense
```

4. na mesma sessão, executar novamente somente o `Preflight`:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass `
  -File .\mz_testkit\runners\run-mz-economy-transaction-gate.ps1
```

5. exigir a saída `docker_daemon=True`, `license_env=True` e `executable_ready=True`;
6. retornar ao operador para nova confirmação explícita, informando que serão iniciados um container MySQL 8.4 efêmero e três processos FXServer sequenciais e que haverá DDL/DML apenas em `mz_tx_lab_<run_id>`;
7. somente depois da confirmação executar o comando `-Mode Execute -ConfirmDisposableLab` já aprovado na especificação;
8. ao fim, limpar a variável na mesma sessão:

```powershell
Remove-Item Env:\MZ_TX_LAB_LICENSE_KEY
```

Não usar `D:\mz_staging\cfg\database.cfg`, `D:\mz_multichar_staging\cfg\database.cfg` ou qualquer connection string persistente.

## 12. Recomendação técnica e próximo gate

`BLOCKED` — não aprovar ainda o primitivo interno de transações. O source do oxmysql 2.14.1 observado pode reduzir falhas a boolean e deixa em aberto o timing de commit via disposer. Sem os cenários 2, 3, 4, 8, 9, 10, 11 e 12 em runtime, affected rows, rollback, retry e recuperação não estão certificados.

Próximo gate mínimo:

1. `Preflight` com `executable_ready=True`;
2. confirmação explícita do operador nesta conversa após descrição dos processos e DDL/DML do lab;
3. execução sem alteração do harness;
4. 12 resultados individualizados e cleanup comprovado;
5. revisão humana do relatório runtime;
6. autorização separada para qualquer implementação no `mz_economy`.

Mesmo com eventual `12/12 PASS`, esta Wave não autoriza funding, Tesouro, holds reais, migração organizacional ou ativação de Jobs.

## 13. Ausências confirmadas

`VERIFICADO`:

- nenhum arquivo de `mz_core`, `mz_economy`, `mz_org`, runtime de `mz_jobs`, `mz_inventory`, `mz_police`, `mz_medical`, `mz_starter` ou payroll foi alterado;
- nenhum `server.cfg` ou arquivo de staging foi alterado;
- nenhum branch, worktree ou commit foi criado;
- nenhum dado financeiro ou schema persistente foi acessado;
- nenhuma API financeira, Treasury, programa municipal ou hold real foi criado;
- Jobs não foi ativado;
- somente este relatório foi adicionado.

## 14. Impacto arquitetural

- contratos públicos: nenhum;
- canonical ownership: inalterado;
- writer/authority: inalterado;
- dependências cross-resource de produção: nenhuma;
- persistência/database: nenhuma alteração; runtime lab `NOT RUN`;
- segurança/permissões: inalteradas;
- exports/events/callbacks/adapters: nenhum;
- external dependencies: apenas inspeção de Docker CLI, FXServer e oxmysql instalados;
- Graphify scope used: consulta read-only;
- Graphify synchronization: não requerida para relatório e execução não iniciada;
- Graphify validation: `NOT APPLICABLE`;
- validação runtime pendente: todos os 12 cenários;
- implementação seguinte: não iniciada e aguardando revisão/autorização.
