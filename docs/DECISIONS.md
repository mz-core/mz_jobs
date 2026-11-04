# MZ Jobs — decisões arquiteturais

## Fechadas na Wave 1

### ADR-JOBS-001 — ownership

`mz_jobs` é o único owner de ofertas, execuções, estágios e reputação profissional por track. Não escreve dinheiro, ledger, orçamento, item, estoque, custódia, população, membership, duty ou skills.

### ADR-JOBS-002 — oferta e execução são ciclos distintos

Oferta: `draft -> published -> reserved -> accepted`, com saídas `expired` e `cancelled`. Execução remunerada/com custódia: `accepted -> in_progress -> settlement_pending -> completed`; serviço sem essas capacidades pode usar `in_progress -> completed`. Há saídas `cancelled` e `failed_review`. Ambos usam `version` para CAS. O aceite é single-winner; coop não faz parte desta fundação.

### ADR-JOBS-003 — categorias e stages

Categorias estruturais: `logistics_route`, `service_intervention`, `production_collection` e `clandestine_contract`. Stages tipados: `pickup`, `transport`, `deliver`, `inspect`, `repair`, `interact` e `return`. Capabilities declaram requisitos; serviço sem carga, veículo, org ou origem/destino é válido. Nenhum stage aceita recompensa ou resultado escolhido pelo client.

### ADR-JOBS-004 — reputação não é skill

`mz_jobs_reputation` mantém somente XP/reputação profissional por track. Perks, atributos e habilidades pertencem a uma futura integração com `mz_skills`. Nesta Wave não existe endpoint de conclusão nem concessão de XP.

### ADR-JOBS-005 — persistência reduzida

O desenho Wave 0 foi reduzido de oito para seis tabelas: offers, executions, operations, events, outbox e reputation. `operations` guarda idempotência de comandos; `events` é trilha append-only; `outbox` coordena efeitos externos e retries. Tabelas locais de custody/settlement foram removidas: só serão desenhadas, se necessárias, após os owners fornecerem recibos canônicos.

### ADR-JOBS-006 — SQL e ativação

O baseline é CREATE-only e manual. O runtime apenas lê `information_schema` e falha fechado. `MZJobsConfig.Enabled=false` é o padrão; nesse estado não consulta schema, não inicia worker e não escreve.

### ADR-JOBS-007 — superfície pública

A Wave 1 expõe somente `GetJobsReadiness` e `GetJobsCapabilities`, ambos read-only. Não há evento de rede, callback client ou export mutável. Mutações de fundação permanecem módulos server-side internos e são exercitadas apenas por mocks no `mz_testkit`.

## Pendentes / BLOCKED

### ADR-JOBS-008 — budget finito e settlement

Todo contrato remunerado deverá obter hold/garantia finita no `mz_economy` antes de publicar/criar obrigação, liberar o hold em cancelamento/expiração e efetuar settlement idempotente com recibo. A fonte preferida para o piloto é orçamento municipal finito, sujeita à aprovação. Não há nome de export decidido. **BLOCKED: contrato público ausente no owner financeiro.**

### ADR-JOBS-009 — custody de inventory

Coleta/entrega com bens reais exige reserve/commit/cancel owner-scoped, fingerprint, timeout, compensação e consulta de recibo no `mz_inventory`. **BLOCKED: contrato público ausente.**

### ADR-JOBS-010 — população, UI e crime

Trabalho virtual pertence a `mz_population`; UI de produção exige host real; consequências ilegais usam `mz_dispatch`/`mz_police`. Todos permanecem fora da Wave 1.
