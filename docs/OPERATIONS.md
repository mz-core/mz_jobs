# MZ Jobs — operação da fundação

## Boot e readiness

1. O padrão é `MZJobsConfig.Enabled=false`.
2. Desativado: o resource carrega exports read-only, não consulta MySQL, não inicia reconciliation e não escreve.
3. Ativado em staging: aguarda `oxmysql`, verifica `mz_core` e valida as seis tabelas por `information_schema`.
4. Tabela/coluna ausente ou MySQL/Core indisponível mantém `ready=false`; nenhuma mutação é permitida.

`mz_starter` não inclui `ensure mz_jobs`. Não adicionar antes do gate de staging.

## Aplicação manual do baseline em staging

1. Confirmar que não há schema `mz_jobs_*` divergente.
2. Fazer backup verificável do banco e registrar o procedimento de restore.
3. Aplicar manualmente `sql/001_mz_jobs_baseline.sql` usando credencial operacional autorizada.
4. Conferir as seis tabelas, uniques, índices e FK interna execução -> oferta.
5. Iniciar o resource ainda com `Enabled=false` e validar os exports.
6. Somente em staging controlado, mudar a flag para `true`, reiniciar e verificar `ready=true`.

O resource não executa CREATE/ALTER/DROP/DELETE de schema.

## Reconciliação

- polling de 30 segundos somente quando ready;
- lease de 30 segundos por row;
- máximo de cinco tentativas;
- backoff exponencial de 1 a 900 segundos;
- handler ausente/poison termina como `failed`, sem loop apertado;
- reserva expirada por worker crash é rejeitada e liberada/expirada sem apagar operation/event.

Nenhum tópico financeiro ou inventory é registrado nesta Wave.

## Rollback não destrutivo

1. Voltar `Enabled=false` e reiniciar/parar o resource.
2. Não remover tabelas nem receipts/events enquanto houver investigação ou reconciliação pendente.
3. Restaurar backup apenas com autorização explícita e procedimento do operador.
4. Não adicionar/remove `ensure` nesta Wave.

## Diagnóstico

Use apenas `GetJobsReadiness` e `GetJobsCapabilities`. Erros persistidos/logados são tokens sanitizados; payloads, secrets e valores externos não são impressos.

## Referências de terceiros

Nenhum script em `ref/trabalhos` é dependência. O webhook literal já identificado deve ser revogado/rotacionado pelo operador, sem copiar ou reproduzir o valor.
