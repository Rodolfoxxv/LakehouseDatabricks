-- ============================================================================
-- CAMADA GOLD — CONTINUIDADE DE FORNECIMENTO (DEC / FEC INSUMOS) — RN-04, RN-14
--
-- ATENCAO: Esta tabela NAO possui colunas de DEC ou FEC calculados na linha.
-- Ela armazena estritamente os INSUMOS ADITIVOS (uc_horas_interrompidas, uc_interrupcoes,
-- total_ucs). A unica definicao de DEC e FEC reside na METRIC VIEW (gold.continuidade_metricas).
-- ============================================================================

CREATE OR REFRESH MATERIALIZED VIEW ${catalogo}.${schema_gold}.continuidade_conjunto_mes
TBLPROPERTIES ('delta.feature.timestampNtz' = 'supported')
COMMENT 'Agregacao mensal de continuidade por conjunto com insumos aditivos para apuracao unificada de DEC e FEC (RN-04)'
AS WITH ucs_conjunto AS (
  SELECT
    id_conjunto,
    nome_conjunto,
    municipio,
    COUNT(DISTINCT id_uc) AS total_ucs
  FROM ${catalogo}.${schema_silver}.unidades_consumidoras
  GROUP BY id_conjunto, nome_conjunto, municipio
),
interrupcoes_mes AS (
  SELECT
    id_conjunto,
    mes_apuracao,
    SUM(uc_horas_interrompidas) AS uc_horas_interrompidas,
    SUM(qtd_ucs_afetadas) AS uc_interrupcoes,
    COUNT(*) AS qtd_interrupcoes,
    COUNT_IF(causa_climatica) AS qtd_interrupcoes_climaticas,
    COUNT_IF(tipo = 'programada') AS qtd_interrupcoes_programadas,
    MAX(duracao_horas) AS maior_duracao_horas
  FROM ${catalogo}.${schema_silver}.interrupcoes_validas
  GROUP BY id_conjunto, mes_apuracao
)
SELECT
  u.id_conjunto,
  u.nome_conjunto,
  u.municipio,
  i.mes_apuracao,
  u.total_ucs,
  COALESCE(i.uc_horas_interrompidas, 0.0) AS uc_horas_interrompidas,
  COALESCE(i.uc_interrupcoes, 0) AS uc_interrupcoes,
  COALESCE(i.qtd_interrupcoes, 0) AS qtd_interrupcoes,
  COALESCE(i.qtd_interrupcoes_climaticas, 0) AS qtd_interrupcoes_climaticas,
  COALESCE(i.qtd_interrupcoes_programadas, 0) AS qtd_interrupcoes_programadas,
  COALESCE(i.maior_duracao_horas, 0.0) AS maior_duracao_horas,
  current_timestamp() AS processado_gold_em
FROM ucs_conjunto u
JOIN interrupcoes_mes i ON u.id_conjunto = i.id_conjunto;
