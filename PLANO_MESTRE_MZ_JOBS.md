# MZ JOBS — PLANO MESTRE DE ARQUITETURA

**Projeto:** MZ Framework / Maravilhosa RolePlay  
**Data:** 25/10/2026  
**Status:** proposta de arquitetura, NÃO implementada  
**Base de estudo:** `D:\git-hub\repo_oficial\ref\trabalhos` (diretório LOCAL canônico com scripts de referência). O pacote originalmente enviado, `trabalhos.zip`, contém 32 diretórios principais e 961 entradas, incluindo assets e arquivos auxiliares; o conteúdo local pode ter diferenças e deve prevalecer após conferência. O repositório `mz-core/mz_core` consultado contém documentação histórica; o código LOCAL mais recente é a fonte de verdade.

## Localização canônica e política de leitura

- **Raiz da framework para esta tarefa:** `D:\git-hub\repo_oficial`.
- **Referências de terceiros (somente leitura):** `D:\git-hub\repo_oficial\ref\trabalhos`.
- A pasta `ref\trabalhos` contém os trabalhos **descompactados**, separados em subpastas. Percorrer diretórios e `fxmanifest.lua`/`__resource.lua`, identificar dependências, licenças, mecânicas e problemas; não tratar `trabalhos.zip` como caminho de execução do Codex.
- Os exemplos pertencem ao acervo de **REFERÊNCIA**, não são resources do `mz_starter`, não devem entrar em `ensure`, nem ter arquivos alterados ou copiados sem permissão/licença verificada.
- Preferir leitura de `server`, `client`, `shared`, `config`, documentação e manifests relevantes. Evitar varredura e leitura integral de mídias, builds, `node_modules`, artefatos binários e assets pesados.
- Verificar nomes e quantidade de subpastas na máquina: as 32 pastas são a contagem do ZIP originalmente recebido, não uma garantia do estado atual do diretório local.
- Para cada referência relevante, registrar seu **caminho relativo real** a partir de `ref\trabalhos`, mecânica útil, dependências, riscos, licença e a integração MZ proposta. Sem carregar segredos em relatórios.
- Caso o caminho não exista ou não seja legível, registrar bloqueio e **não inventar** auditoria local; continuar com a arquitetura da framework e indicar a etapa pendente.

## 0. Decisões que não devem ser reabertas sem evidência

1. Criar **`mz_jobs`** como motor de oportunidades, contratos, progresso de atividade e reputação profissional. Não transformar `mz_core` em controlador de empregos.
2. **`mz_economy` é a autoridade financeira atual**: sem carteira/saldo/ledger próprios em `mz_jobs`; conferir os exports atuais no código local, pois a documentação histórica de junho/2026 ainda descreve uma arquitetura anterior.
3. **`mz_population` é dona da simulação de população, necessidades e trabalhos virtuais de NPCs**. `mz_jobs` fornece contratos e recebe ofertas/solicitações; não criar um segundo gerador global de pedestres e não substituir os NPCs existentes.
4. `mz_inventory` continua dono de itens, capacidade, transferências e metadados; `mz_org` continua dona de vínculos/cargos/permissões/duty e do payroll onde aplicável.
5. **Jogador antes da automação**: NPC virtual só cobre parte de demandas não atendidas, respeitando janela de oportunidade, limites econômicos e sem absorver contratos já reservados.
6. **Rotas só onde fazem sentido**. Viagem em transporte/logística/entregas; tarefas interativas em obras/manutenção; produção em agricultura/mineração/madeira; ofertas e riscos em atividades ilícitas.
7. **Uma atividade precisa ter consequência**, não somente spawn de checkpoint + recompensa: demanda, produto, estoque, serviço prestado, custo de empresa, imposto/taxa ou consequência operacional.
8. Reutilização das referências **conceitual**, com leitura de licença/proveniência antes de aproveitar código/asset. Não carregar ESX/vRP, notificadores antigos, painéis obsoletos, schemas e pagamentos vulneráveis.
9. UI enxuta, responsiva e contextual; usar `mz_frontend` e componentes MZ existentes quando disponíveis. Sem segundo mapa, segundo inventário ou dashboard sempre aberto.
10. Nunca modificar `mz_core` nem contratos de terceiros sem autorização explícita. Primeiro adaptar usando API pública; quando ela faltar, documentar a lacuna e solicitar decisão.
11. Sem worktree, branch ou commit automáticos. Priorizar a estrutura `main` no ambiente local com backup antes de mudanças importantes.
12. Idioma do servidor `pt-BR` padrão com suporte `en-US`; não criar seletor por jogador. Configuração pública pequena e defaults seguros.

## 1. Leitura do pacote enviado: o que aproveitar

| Referência em `ref\trabalhos` | Padrão/meio aproveitável | Uso pensado | Prioridade | Risco / o que NÃO copiar |
|---|---|---|---|---|
| `big_empregos` | catálogo unificado de empregos, veículo/ponto/nível | definições declarativas simples | P1 | config repetitivo grande, pagamentos genéricos, framework antiga |
| `truck_logistics` | fretes, caminhões, habilidades, motoristas contratados, empresa | transporte e empresas logísticas | P3 | saldo próprio `trucker_users.money`, criação de lucro periódico, entrada client `reward/distance`, segredo de webhook presente em arquivo: sanitizar e rotacionar se real |
| `thor_transportadora...` | mecânica de transporte | inspiração secundária | P3 | partes devem ser auditadas/licenciadas antes de uso |
| `inside-courier` e `rc_ramazon` | encomendas, retirada, entrega, clientes | courier integrado a pedidos reais | P2 | `inside-Courier:payout` acionável sem prova; `rc_ramazonDelivery:payout(payout)` recebe valor do cliente |
| `inside-warehouse` | depósito, movimentação física, frota | centros de distribuição | P3 | recursos antigos de UI/ESX |
| `inside-busdriver`, `Q_motorista`, `Q_taxista` | passageiros, paradas, veículo, remuneração | transporte coletivo/táxi | P4 | chamada isolada de payout, sem validação do percurso no servidor |
| `inside-builder`, `balaka_construtor-main` | ferramentas, tarefas em obra, experiência | manutenção, obra, projetos por etapas | P4 | atividade local e pay por simples callback |
| `Q_eletricista`, `inside-gardener`, jardineiro VRPEX | locais e interações com equipamentos | chamados dinâmicos de manutenção | P4 | marcadores e lógica legada a não replicar |
| `inside-farmer`, `inside-fruitpicker`, `Q_leiteiro`, `Q_minerador`, `Q_lenhador` | coleta, colheita, transformação de insumos | cadeia produtiva real | P2–P4 | geração infinita de item ao invocar evento sem prova válida |
| `Q_lixeiro` | coleta/reciclagem e turnos curtos | limpeza urbana com demanda por bairro | P2–P3 | loop artificial fixo, payout sem controle central |
| `Q_pescador`, `Q_cacador`, `devil_tubarao-main` | pesca, caça e espécies/áreas | atividades de lazer/produção futura | P5 | balanceamento e assets/licenças |
| `inside-carthief` | encomendas de carros e entregas ilícitas | desmanche/receptação | P5 | `Payout(Payout, arg, CarLabel)` aceita números do cliente |
| `inside-illegalorders`, `inside-illegaltransportation` | vários tipos de contrato ilegal | quadro de oportunidades clandestinas | P5 | callbacks de pagamento acionáveis, rota+dinheiro sem prova |
| `inside-selldrugs` | negociação com NPC e desfechos variados | mercado clandestino / reputação | P5 | não copiar lógica de preços ou recompensa sem validação |
| `inside-shoprobbery` | caixas, cofres, funcionários e risco | assaltos vinculados a lojas e `mz_dispatch` | P5 | `inside-shoprobbery:payout(..., money)` aceita valor fornecido |
| `inside-moneywash` | tarefa física, lavagem, máquinas ocupadas | futuro circuito de moeda ilícita | P5 | `WashedMoney` global compartilhado; callbacks de devolução sem origem comprovada |
| `rc_Marketplace` | anúncios, vendas, compra e coleta de receita | referência a mercado de bens | P6 | race conditions e consistência de inventário/saldo a auditar |
| `mycroft-jobforms-main` | candidatura/recrutamento | vagas de empresas via `mz_org` | P6 | UI/ACL de terceiros |
| `rc_carDelivery`, `rc_carRental`, `rc_VehicleShop` | serviços de transporte automotivo | extensão com `mz_vehicles` | P4–P6 | `rc_carDelivery:payout(payout)` recebe valor do cliente; não duplicar garagem/loja |
| `rc_blackPhone`, `rc_hud`, `rc_vote`, `vrp_tutorial`, `emprego_Corona` | referências secundárias | avaliar caso a caso | opcional | duplicam sistemas MZ ou são periféricos ao escopo |

**Constatações diretamente observadas:**
- `inside-moneywash/inside-moneywash/server.lua` usa `local WashedMoney` no escopo geral e permite uma sequência separada para receber o montante. Não existe isolamento claro por contrato/personagem na variável.
- `rc_ramazon/[RAMAZON]/rc_ramazonDelivery/server/main.lua` recebe o argumento `payout` na operação de pagamento; `rc_carDelivery` e `inside-carthief` possuem padrões análogos.
- `inside-courier/server/server.lua` sorteia o pagamento em callback sem comprovação durável da tarefa.
- `truck_logistics/truck_logistics/server.lua` possui tabela de dinheiro separada e um loop de remuneração de motoristas offline; o evento de iniciar contrato recebe `distance` e `reward` do cliente. Em uma reimplementação, distância/preço precisam ser derivados no servidor e cada lucro exige fonte econômica.
- Existem recursos ESX/vRP, bibliotecas duplicadas (`pNotify`, `rprogress`) e código/assets de épocas distintas. Realizar inventário de licenças antes de copiar qualquer implementação.

## 2. Limites de responsabilidade (owners)

| Área | Owner | Limites do `mz_jobs` |
|---|---|---|
| Conta do jogador, identidade e sessão | `mz_core` via contratos públicos | só consulta; não altera fluxo de login, personagem ou estado principal |
| Saldo, transferências, taxas, ledger, preços financeiros | `mz_economy` | solicita liquidação com referência idempotente e recebe recibo definitivo |
| Inventário, itens, pesos, metadados, escrow/transferência | `mz_inventory` | solicita reservar/remover/entregar mercadorias, sem mexer direto em suas tabelas |
| Simulação de demanda, trabalhadores e clientes NPCs | `mz_population` | publica ou consome contratos, não possui seu scheduler mundial nem gera todos os peds |
| Organizações, cargos, contratação, folha, duty | `mz_org` e recursos de payroll existentes | oferece contratos independentes sem virar novo payroll |
| Veículos e regras de propriedade | `mz_vehicles`/`mz_garagem` | valida veículo através das APIs, não persiste uma garagem paralela |
| Rotas, waypoints, mapa | `mz_navigation` | pede orientação e destinos, não duplica motor/mapa |
| Interação com entidades e ações contextuais | `mz_target` e `mz_radialmenu` | registra ações junto ao recurso e valida server-side |
| Interface reusável/notificações | `mz_frontend` / `@mz/ui` existentes | usa componentes e não cria outra biblioteca de notificações |
| Crime, polícia, alertas e resposta | `mz_police`/`mz_dispatch` | publica ocorrências; não define polícia nem altera MDT |
| Telefone e anúncios de oportunidades | `mz_phone` | pode disponibilizar app/canal de oportunidades em fase posterior |

**Distinção de domínio:**
- *Profissão/skill*: progressão e capacidade individual (mz_jobs).
- *Emprego formal/cargo/duty*: vínculo na organização e folha de pagamento (`mz_org`/payroll).
- *Contrato autônomo*: tarefa aberta/reservada/concluída com remuneração individual (`mz_jobs` + `mz_economy`).
- *Trabalho virtual de NPC*: simulação agregada sob `mz_population` que pode satisfazer uma necessidade gerada pelo mercado, sem colocar automaticamente dinheiro na conta de jogador.

## 3. Modelo de jogo: trabalho não é sempre uma rota

**Classe A — transporte:** delivery de encomendas, fretes, ônibus, táxi. Requer carga/passageiro, ponto inicial/final, viagem e prova da entrega; checkpoints são meios, não fins.

**Classe B — serviço dinâmico:** manutenção elétrica, obra, jardinagem, remoção de lixo. Recebe ordem contextual, inspeciona objeto/área, escolhe ferramenta, realiza pequenas ações verificáveis e entrega a obra.

**Classe C — produção:** madeira, agricultura, mineração, pesca e reciclagem. Gera bens finitos, transforma itens/insumos, entrega produtos à cadeia logística/estoque/mercado com rastreabilidade.

**Classe D — ilícito:** transportes clandestinos, roubo sob encomenda, comércio ilícito, receptação/desmanche, assaltos e lavagem. Cada um possui processo, risco, demanda, restrições e consequências; evitar fazendas infinitas de dinheiro sujo.

**Classe E — contratos livres/humanos:** empresas abrem pedidos (mecânica, guincho, taxista, manutenção). O sistema encontra jogador disponível; contratação formal via owner de organizações.

### Regras de experiência (UX)
- Início rápido: o jogador vê o contrato e o aceita em 2–3 ações, sem preenchimento burocrático.
- Trabalhos curtos **3–7 minutos**, intermediários **10–20 minutos** e longos **20–40 minutos**, como **metas de design a validar em testes**, não tempos rígidos.
- Há sempre objetivo, progresso visual, faixa de recompensa estimada e requisitos antes da aceitação.
- No mínimo duas abordagens nos trabalhos complexos: rapidez vs cuidado, ferramentas vs investimento, rota segura vs tempo; benefícios calculados no servidor.
- Variação real: destino, ferramenta, defeito, tipo de carga, cliente, evento e necessidade mudam, com conjunto limitado/curado de atividades.
- Evitar 15 checkpoints idênticos e minigames arbitrários em tudo.
- Recompensar cooperação quando houver: entregas de equipe com pagamento repartido definido ANTES do início, sem duplicar valor total.
- Estados de erro claros: carga inválida, colega desconectado, veículo perdido, contrato expirado, falta de materiais, servidor reiniciado.
- Pausa/reconexão controlada e abandono sem perder injustamente recursos; regras diferentes para tarefa curta, encomenda e frete físico.
- `mz_target` para ações no mundo, `mz_radialmenu` para ações de contexto, telefone para consultar ofertas, mapa apenas via `mz_navigation`. Sem segunda UI para o mesmo fim.

## 4. Arquitetura mínima do recurso

```text
[mz_jobs]
├─ fxmanifest.lua
├─ README.md
├─ shared/
│  ├─ config.lua                # poucas opções públicas; flags OFF e limites essenciais
│  ├─ locales/pt-BR.lua
│  ├─ locales/en-US.lua
│  └─ contracts.lua             # DTOs/erros/enums compartilhados, sem lógica sensível
├─ server/
│  ├─ main.lua                  # bootstrap, checagens dependências, cleanup
│  ├─ catalog.lua               # registro de templates e suas versões
│  ├─ contracts.lua             # publicar/listar/claim/cancel/expire
│  ├─ executions.lua            # sessão e máquina de estados do contrato
│  ├─ proof.lua                 # provas verificadas server-side
│  ├─ settlement.lua            # idempotência + adapter mz_economy
│  ├─ reputation.lua            # progresso ocupacional separado de cargo de org
│  ├─ outbox.lua                # entregas duráveis entre owners quando necessário
│  ├─ adapters/                # SOMENTE contracts públicos descobertos
│  │  ├─ economy.lua
│  │  ├─ inventory.lua
│  │  ├─ population.lua
│  │  ├─ identity.lua
│  │  └─ org.lua
│  └─ activities/
│     ├─ registry.lua
│     ├─ delivery.lua           # piloto
│     ├─ production.lua         # piloto
│     └─ sanitation.lua         # piloto seguinte
├─ client/
│  ├─ main.lua
│  ├─ interactions.lua          # mz_target/radial — não injetar recursos paralelos
│  ├─ navigation.lua            # mz_navigation
│  ├─ activities/
│  │  ├─ delivery.lua
│  │  └─ production.lua
│  └─ nui.lua                   # bridge fina, sem lógica financeira
├─ web/                          # somente quando necessário; usar mz_frontend
├─ sql/
│  └─ 001_mz_jobs.sql            # baseline de propriedade do mz_jobs; sem auto-schema runtime
├─ tests/
│  ├─ contracts/
│  ├─ economy/
│  ├─ inventory/
│  ├─ reconnect/
│  └─ population/
└─ docs/
   ├─ OWNERS_AND_ADAPTERS.md
   ├─ STATE_MACHINE.md
   ├─ ECONOMY_AND_FUNDS.md
   ├─ POPULATION_PROTOCOL.md
   ├─ SECURITY_TEST_MATRIX.md
   └─ RUNTIME_ACCEPTANCE.md
```

Observação: esta é a **estrutura pretendida**, não um mandato de produzir muitos arquivos vazios. O Codex deve verificar nomenclaturas e integrações reais, reaproveitar convenções já existentes e criar arquivos conforme a fase. O ilícito pode ficar em atividades versionadas opcionais do `mz_jobs` ou em um recurso especializado `mz_illegaljobs` se o isolamento funcional justificar; **não decidir já por outro framework dentro do framework**.

## 5. Contratos internos propostos (NÃO são exports confirmados)

Modelo canônico, adaptável aos nomes reais após descoberta:

```lua
-- Oferta controlada pelo servidor.
{
  contract_id = 'id-opaque',
  template_id = 'food_delivery.v1',
  type = 'delivery',
  district_id = 'vespucci',
  requester = { type = 'business', id = 'business_id' },
  supplier = { type = 'warehouse', id = 'warehouse_id' },
  beneficiary = { type = 'business', id = 'business_id' },
  funding_ref = 'funding_or_escrow_ref',
  required_items = { { item = 'food_box', amount = 6 } },
  expected_duration_sec = 480,
  reward_quote = { amount = 450, currency = 'bank', category = 'legal_job' },
  status = 'open',
  expires_at = 'server-time',
  version = 1
}
```

**API de intenção (abstrata):** `ListOffers(filters)`, `PublishOffer(trustedResource, templateId, payload)`, `ReserveOffer(characterId, contractId, expectedVersion)`, `StartExecution`, `SubmitActionProof`, `CancelExecution`, `GetExecution`, `RequestSettlement`. O Codex não deve criar esses nomes como exports permanentes antes de checar os padrões públicos atuais.

### Máquina de estados

```text
DRAFT → OPEN → RESERVED → ACTIVE → VERIFYING → SETTLING → COMPLETED
            ↘ EXPIRED   ↘ CANCELLED / FAILED       ↘ SETTLEMENT_PENDING
```

- Oferta reservada por **um** operador/party via operação condicional atômica; o tempo de reserva tem TTL.
- Execução é ligada à identidade **do personagem**, não a `source` como identificador persistente.
- Cada transição grava versão monotônica e carimbo de tempo do servidor.
- Ações do cliente nunca enviam valor de pagamento, quantidade de item final, profissão, nível ou destino escolhido sem revalidação.
- Provas server-side: distância ao ponto, estágio atual, janela de tempo plausível, posse/estado de item ou veículo no owner correto, autenticidade do destino e rate-limit.
- `ACTIVE → VERIFYING`: não paga. A confirmação de entrega deve fechar estoque/carga, depois solicitar liquidação.
- Falha de API externa: `SETTLEMENT_PENDING` com outbox de retry, **sem repetir crédito**; falha definitiva visível à equipe.
- `COMPLETED` é terminal e idempotente: replay/duplo clique/desconexão não podem duplicar efeito.

## 6. Modelo de dados mínimo proposto

**Catalogar templates em arquivos versionados**; tabelas armazenam instâncias, não milhares de configurações.

1. `mz_jobs_contracts`: `id`, `template_id`, `template_version`, `type`, `requester_type/id`, `funding_ref`, `location_ref`, `payload_json`, `status`, `reserved_by_character_id`, `reservation_deadline`, `deadline`, `version`, `created_at`, `updated_at`. Índices `(status, deadline)`, `(requester_type, requester_id)`, `(reserved_by_character_id, status)`.
2. `mz_jobs_executions`: `id`, `contract_id UNIQUE`, `character_id`, `party_ref NULL`, `state`, `stage`, `progress_json` limitado, `started_at`, `last_action_at`, `finished_at`, `version`. Única execução por contrato; regras para equipe definidas separadamente.
3. `mz_jobs_settlements`: `id`, `execution_id UNIQUE`, `settlement_key UNIQUE`, `payer_ref`, `payee_ref`, `reward_quote_cents`, `state`, `economy_receipt_ref`, `attempt_count`, `next_retry_at`, `last_error_code` (sem dados sensíveis). Não implementar saldo próprio.
4. `mz_jobs_reputation`: `character_id`, `career_id`, `xp`, `level`, `completed_count`, `updated_at`, `version`, UNIQUE por `(character_id, career_id)`. Reputação não substitui grade/cargo de org.
5. `mz_jobs_outbox`: `event_id UNIQUE`, `aggregate_type/id`, `event_type`, `payload_json`, `state`, `attempts`, `available_at`, `created_at`, `processed_at`, somente se integração real exigir entrega durável.
6. `mz_jobs_action_receipts` (opcional): eventos/claims de ações que precisem prevenção de replay adicional; limitar retenção.

**Não duplicar** tabelas já existentes de pedidos de mercado, estoque e ledger. Descobrir owner no código atual e adicionar associação por ID externo. O SQL definitivo depende da modelagem real dos recursos.

## 7. Dinheiro, estoque, risco de inconsistência

**Fontes de financiamento:**
- **Empresa real/jogador**: o contratante autoriza saldo/escrow suficiente antes de publicar; taxas de serviço e remuneração são transferências/consumos rastreáveis.
- **Serviço público**: remuneração do fundo orçamentário municipal, previamente provisionado e com teto por período; qualquer emissão/subsídio deve ficar explícita no `mz_economy` como faucet e auditável.
- **NPC/empresa virtual**: possui envelope econômico por período/distrito baseado em demanda/receitas simuladas (owner `mz_population`/`mz_economy`), nunca crédito infinito para jogador.
- **Atividade ilícita**: consumo/reserva de bens e riscos com conta `dirty` apenas por contrato real do economy; downstream lavagem com custo, limites e origem. Ação criminosa gera economia e consequência, não farm infinito.

**Atenção à atomicidade cross-resource:** se remover carga via `mz_inventory` e pagar via `mz_economy` são operações distintas, não assumir transação SQL única de ponta a ponta. Preferir reserva/escrow, recibos idempotentes, outbox + reconciliação. Se API não tiver operação segura, **não inventar** compensação ingênua ou débito em duplicidade; documentar lacuna com teste que reproduz a falha.

**Composição de recompensa (quote server-side):** tarifa base por serviço + distância legítima/carga/qualidade/risco + modificadores suaves por reputação e demanda, com piso/teto definidos centralmente. Nenhuma multiplicação ilimitada por XP. Balancear renda/hora com métricas atuais do `mz_economy` e testar sem usar preços fixos copiados do ZIP.

## 8. `mz_population`: simulação híbrida e limites

**Regra principal: NPC não precisa atravessar toda a cidade para que um trabalho exista.**

1. Demanda por distrito e setor: comida, mercadorias, limpeza, manutenção, suprimentos de obra, logística, transporte, consumo cotidiano.
2. `mz_population` estima demanda/produção agregada por intervalos configurados. Publica **pedidos econômicos**, não pagamentos diretos.
3. `mz_jobs` converte demanda viável em contratos `OPEN`, respeitando cadência, cooldown, disponibilidade e orçamento.
4. O jogador vê e reserva trabalho; o contrato reservado fica fora da fila NPC.
5. Após janela dinâmica (ex.: sem candidatos, oferta vencendo, falta de estoque essencial), um trabalhador virtual pode cumprir **parte** da necessidade. Seu resultado precisa ser provado por estado de simulação/estoque e conciliado com orçamento; **zero XP/recompensa para jogador que não participou**.
6. NPCs visuais podem aparecer em locais próximos, seguindo limites de spawn/culling do `mz_population` atual. A ocupação virtual não implica um ped físico obrigatório.
7. NPCs empregados por jogadores precisam de contratos e orçamento da empresa, salários/despesas rastreáveis e limites; não gerar rendimento passivo garantido sem demanda/insumos.

**Proteções:** idempotência dos ticks, controle de catch-up pós-restart, `maxCatchupCycles`, orçamento por zona, lock/lease por oferta, limites de NPCs ativos na área, burst control após pico de demanda e fairness entre distritos.

**Protocolo proposto (nomes abstratos):**
- population→jobs: `DemandRaised`, `DemandChanged`, `WorkerSimulatedProgress`, `DemandSatisfiedByNpc`;
- jobs→population: `ContractOpened`, `ContractReserved`, `ContractCompleted`, `UnfilledDemandNotice`;
- economy→jobs: `SettlementAccepted/Rejected`, recibo, e indicadores agregados de mercado; 
- jobs→economy: `Quote/Reserve/Settle` com `external_ref` único;
- jobs→inventory: `Reserve/Consume/Deliver` com recibos e estado para reprocessamento.

**Nunca presumir que exports com esses nomes já existem**; o Codex deve mapear e traduzir para os contracts reais.

## 9. Projeto-piloto de ponta a ponta

### PILOTO A — Abastecimento de empresa (principal)

**Cenário:** mercado/restaurante da cidade precisa de caixas de alimentos. Demanda é originada pelo owner de comércio/população. O pedido é publicado, um jogador aceita produzir/coletar lote, outro pode transportar a carga e entregar ao comércio. O estoque da loja sobe, o orçamento cai, ambos os executores recebem pela parte comprovada, e o `mz_economy` classifica tudo.

**Versão mais simples da primeira rodada:** o produto já existe no armazém; somente `retirar → transportar → entregar` com um jogador e uma loja virtual. Depois ligar produção física e divisão de contrato.

**Fases do contrato:** `OPEN → RESERVED → LOAD_VERIFIED → IN_TRANSIT → DELIVERY_VERIFIED → SETTLEMENT_PENDING → COMPLETED` (subestados definidos pelo template; respeitam máquina global).

**Critérios de aceitação:** estoque sobe uma única vez; orçamento sai uma única vez; jogador recebe uma única vez; NPC não aceita contrato já reservado; relog não perde/duplica carga; desconexão e reinício resultam em retomada ou cancelamento consistente; rota é exibida pelo `mz_navigation`.

### PILOTO B — Ciclo de recurso físico

Coletar madeira ou material reciclável (`mz_inventory`) → processar → criar pedido para depósito/comércio → entregar. Produção finita por área/tempo; não premiar pelo simples acionamento de evento. Começar com **um** item/um tipo de produção para validar a plataforma, sem 20 profissões de uma vez.

### PILOTO C — Limpeza urbana

`mz_population` detecta demanda de serviço por setor → publicação de chamados → jogador recolhe pontos verificáveis + descarrega carga → município liquida serviço dentro do orçamento. Se sem jogador, serviço virtual reduz demanda parcialmente, sem pagamentos à conta de jogador.

## 10. Interface mínima

- No mundo: NPC de contratação (reaproveitado de `mz_population`), `mz_target` com `Ver trabalhos`, placas/terminals, e `mz_radialmenu` para `Trabalho atual`, `Cancelar`, `Solicitar apoio` quando contextual.
- Lista de oportunidades simples: **tipo de atividade, região, duração estimada, recompensa, itens/requisitos, disponibilidade**. Cards compactos, filtros só quando necessários.
- Ativo: objetivo atual, barra de etapa, botão de navegar pela `mz_navigation`, histórico mínimo. Sem mapa embutido.
- Notificações de mudança de contrato/erro via componentes MZ; sem spam.
- App do `mz_phone` só depois da API de ofertas estabilizada. Primeiro validar fluxo via terminal/target.
- UI sem foco preso, compatível com F6/ESC dos recursos atuais, estados de close/reconnect e velocidades de mensagens; testes em 1080p/1440p/ultrawide.

## 11. Segurança e antifraude (bloqueia release)

- O client envia **intenção** e identificador da tarefa/etapa, nunca valor, XP, quantidade de produto final, flag de conclusão ou identificação arbitrária de outro jogador.
- Source real do evento + identidade do personagem resolvida no servidor a cada transição sensível; revalidar caso troca de personagem/relog.
- Autorizar recurso chamador/claim publisher com `GetInvokingResource()` quando aplicável; não considerar `metadata.source_resource` fornecida pelo cliente como identidade.
- Server validates ações: localização, área de serviço, cooldown, veículo correto e propriedade/uso, carga autêntica, integridade dos itens, tempo mínimo plausível, visibilidade/estado do mundo quando possível.
- Filtros anti-spam, limites por personagem, distância e fila, locks CAS no contrato, unique key por settlement, progress monotônico.
- Rejeitar spam de `SubmitProof`, replay de NUI, contrato expirado, teleport, source trocado, player offline e uso fora da stage.
- Garantir que eventos server-internal usem `AddEventHandler` e não sejam acidentalmente networked.
- Cleanup determinístico de entidades/props temporários via owners; nunca apagar itens/veículos reais por cancelamento sem prova.
- Habilitar auditoria com ID de execução, `character_id`, `template_id`, event type, reason e external_ref, sem credenciais em logs.
- Testar falha de economy/inventory/population com estado seguro (`fail closed` ao publicar/entregar/receber); **não concluir nem pagar se a confirmação da integração essencial não chegou**.
- Revisão de segredo: as referências podem conter configurações de webhook de terceiros embutidas; não portar e verificar se requer rotação/revogação, sem expor no relatório.

## 12. Roadmap para o Codex — WAVE por WAVE, com portões

| Wave | Entrega real | Gates antes de passar |
|---|---|---|
| **0 — Auditoria e ADR** | leitura dos recursos atuais e `ref\trabalhos`, owners, contracts públicos, lacunas, dependências e fluxos; proposta final de SQL/API/árvore; sem mudança de runtime | owner de saldo/inventário/ped/NUI inequívoco; contrato real de cada integração citado em arquivo/linha; lista de riscos assinada no relatório |
| **1 — Fundação** | recurso `mz_jobs` atrás de flags OFF, baseline SQL, catalog/contrato/execução, idempotência e testes isolados; sem NUI avançada | 100% testes de estados, reservas concorrentes, restart/replay; nada paga sem confirmação |
| **2 — Entrega simples** | uma encomenda simulada de estoque real com origem/destino, target e navegação; pagamento central | item debitado/adicionado uma vez, settlement uma vez; reconexão segura; uso possível em gameplay real |
| **3 — Produção + demanda** | único produtor (madeira OU agricultura) e consumidor virtual com orçamento finito; pedidos abastecem entregas | estoque/demanda e fundos reconciliam; latência aceitável; cenários sem jogador |
| **4 — Simulação NPC** | `mz_population` passa a abastecer demanda virtual parcialmente com TTL/fairness; visual só por alcance | sem NPC duplicado, CPU/script hitch controlado, sem renda passiva fabricada, disputa jogador/NPC segura |
| **5 — Mais legais** | coleta urbana, manutenção elétrica, obra e transporte mais longo (um por wave menor) | cada mecânica adiciona valor real sem quebrar contratos existentes |
| **6 — Ilícitos** | encomendas ilegais, receptação e assaltos em módulos opcionais, integrados ao dispatch/estoque | dinheiro sujo/itens/auditoria/alertas server-authoritative; sem farm infinito |
| **7 — Empresas e polimento** | contratos publicados por organizações, vagas, divisão de tarefas, integração phone, habilidades, economia balanceada | owner org preservado, custo total consistente, UI leve, cenários multilíngues e observabilidade |

**Importante:** Se a Wave 0 revelar que um owner necessário não possui adapter público consistente, parar a implementação daquele caminho e reportar contrato faltante. Não “resolver” modificando o core silenciosamente.

## 13. Testes mínimos de aceite (nomes orientativos)

1. Dois personagens tentando aceitar o mesmo contrato ao mesmo tempo → exatamente uma reserva.
2. Cliente forja dinheiro/XP/item/count, distância, destino ou conclusão → request negado.
3. Duas vezes o mesmo callback de entrega e de pagamento → uma única alteração de estoque e saldo.
4. Restart entre `VERIFYING` e `SETTLING` → outbox reprocessa até recibo ou estado investigável sem crédito duplicado.
5. Falha de `mz_economy` → nenhuma recompensa perdida/duplicada; transição fica pendente e é reconciliável.
6. Falha de `mz_inventory` → sem `COMPLETED` e sem item fictício.
7. Desconexão, morte, troca de personagem e expiração de reserva → regras explícitas e sem manter lock eterno.
8. Explosão de demanda em 10 distritos → geração e processamento limitados, sem centenas de NPCs spawnados.
9. Contrato reservado por jogador + scheduler de NPC → NPC não conclui nem rouba crédito do jogador.
10. Payout e classificação no ledger batem com origem do fundo e orçamento.
11. Dupla contratação de equipe → split correto, nunca pagamento total repetido para cada membro.
12. Reiniciar `mz_population`, `mz_navigation` ou `mz_target` → resource não entra em loop de erro e se recupera quando integrações voltam.
13. UI não rouba foco permanente, `ESC` fecha, ações por target refletem estado e não ficam presas.
14. 1080p, 1440p e ultrawide, deslocamento normal sem hitch por loop `Wait(0)` fora de proximidade.
15. Português padrão e inglês sem strings faltando, logs de auditoria e alertas staff úteis.

## 14. Métricas econômicas e de diversão

**Antes de balancear pagamento** instrumentar:
- Ofertas abertas, aceitas, expiradas; taxas de abandono, conclusão, retries e erros.
- Tempo real até aceitar, tempo de serviço, tempo deslocando vs interagindo, dinheiro/hora por atividade, repetição por jogador.
- % demanda suprida por jogador, NPC e sistema de emergência; liquidez/orçamento e variação de estoque por distrito.
- Relação de renda de trabalho simples vs produção especializada vs risco ilegal, sempre com limites e fontes claras.
- Script hitch, spawn count, queries por minuto, backlog outbox e latência de settlement.

**UX não deve perder para a simulação**: população é pano de fundo que gera demanda, não barreira burocrática. Se não existir pedido orgânico suficiente, permitir contratos públicos subsidiados e limitados (ex.: prefeitura) para o servidor não parecer vazio, com custo transparente e tetos.

## 15. ADRs a registrar antes de implementar

- ADR-001: owners/domínios e distinção profissão x org.
- ADR-002: contrato/execução/settlement e chave de idempotência.
- ADR-003: provedores atuais de saldo, inventory e reserva de item.
- ADR-004: protocolo de demanda NPC, prazo de reserva e prioridade player.
- ADR-005: política de desligamento, morte, reconexão e interrupção.
- ADR-006: estratégia de orçamento, faucets/sinks e precificação.
- ADR-007: decisão sobre atividades ilícitas e controle de permissões.
- ADR-008: experiência visual sem map/UI duplicados.

## 16. Critérios de pronto do produto BASE

A base está sólida quando **um contrato real** consegue atravessar publicação → reserva → início → prova → entrega → liquidação → auditoria com falhas e reinício, sem alterar `mz_core`, sem duplicar dinheiro/itens, e tendo uma UI simples operável por `mz_target`/`mz_navigation`. **Só depois** escalar para dezenas de profissões, motoristas NPC e ilícitos.

---

### Referências externas técnicas

- FiveM — Secure Your Events: https://docs.fivem.net/docs/developers/server-security/
- FiveM — Resource manifest: https://docs.fivem.net/docs/scripting-reference/resource-manifest/resource-manifest/
- FiveM — Scripting in Lua e exports: https://docs.fivem.net/docs/scripting-manual/runtimes/lua/

> Nenhum trecho sensível dos scripts de referência (webhooks/tokens) está reproduzido neste documento. Nomes de APIs nas seções arquiteturais são **propostos**, não prova de que existam nos recursos atuais.
