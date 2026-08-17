-- ============================================================================
-- CAMADA GOLD — PAINEL OPERACIONAL DIARIO (RN-14)
--
-- Consolida os 5 blocos operacionais (rede, chamados, consumo, prioridades e cadastro)
-- agregando cada bloco separadamente e unindo via FULL OUTER JOIN para nao perder dias sem eventos.
-- ============================================================================

CREATE OR REFRESH MATERIALIZED VIEW ${catalogo}.${schema_gold}.painel_operacional_dia
TBLPROPERTIES ('delta.feature.timestampNtz' = 'supported')
COMMENT 'Consolidado operacional diario por conjunto costurando interrupcoes, chamados, consumo e acoes recomendadas'
AS WITH info_conjuntos AS (
  SELECT
    id_conjunto,
    FIRST(nome_conjunto) AS nome_conjunto,
    FIRST(municipio) AS municipio,
    COUNT(DISTINCT id_uc) AS total_ucs
  FROM ${catalogo}.${schema_silver}.unidades_consumidoras
  GROUP BY id_conjunto
),
agg_interrupcoes AS (
  SELECT
    id_conjunto,
    data_evento AS data,
    COUNT(*) AS qtd_interrupcoes,
    SUM(uc_horas_interrompidas) AS uc_horas_interrompidas,
    SUM(qtd_ucs_afetadas) AS ucs_afetadas,
    COUNT_IF(causa_climatica) AS interrupcoes_climaticas,
    MAX(duracao_minutos) AS maior_duracao_minutos
  FROM ${catalogo}.${schema_silver}.interrupcoes_validas
  GROUP BY id_conjunto, data_evento
),
agg_chamados AS (
  SELECT
    id_conjunto,
    data_chamado AS data,
    COUNT(*) AS qtd_chamados,
    COUNT_IF(risco_a_saude) AS chamados_risco_saude,
    COUNT_IF(ameacou_ouvidoria) AS chamados_ouvidoria,
    COUNT_IF(urgencia = 'alta') AS chamados_urgencia_alta
  FROM ${catalogo}.${schema_silver}.chamados_enriquecidos
  GROUP BY id_conjunto, data_chamado
),
agg_consumo AS (
  SELECT
    id_conjunto,
    data,
    SUM(consumo_kwh) AS total_consumo_kwh,
    COUNT(DISTINCT id_uc) AS ucs_com_leitura
  FROM ${catalogo}.${schema_silver}.consumo_diario
  GROUP BY id_conjunto, data
),
agg_prioridades AS (
  SELECT
    id_conjunto,
    COUNT_IF(prioridade_inspecao = 'alta') AS ucs_prioridade_alta
  FROM ${catalogo}.${schema_gold}.prioridade_inspecao_uc
  GROUP BY id_conjunto
),
datas_conjuntos AS (
  SELECT id_conjunto, data FROM agg_interrupcoes
  UNION
  SELECT id_conjunto, data FROM agg_chamados
  UNION
  SELECT id_conjunto, data FROM agg_consumo
)
SELECT
  d.id_conjunto,
  c.nome_conjunto,
  c.municipio,
  d.data,
  COALESCE(i.qtd_interrupcoes, 0) AS qtd_interrupcoes,
  COALESCE(i.uc_horas_interrompidas, 0.0) AS uc_horas_interrompidas,
  COALESCE(i.ucs_afetadas, 0) AS ucs_afetadas,
  COALESCE(i.interrupcoes_climaticas, 0) AS interrupcoes_climaticas,
  COALESCE(i.maior_duracao_minutos, 0.0) AS maior_duracao_minutos,
  COALESCE(ch.qtd_chamados, 0) AS qtd_chamados,
  COALESCE(ch.chamados_risco_saude, 0) AS chamados_risco_saude,
  COALESCE(ch.chamados_ouvidoria, 0) AS chamados_ouvidoria,
  COALESCE(ch.chamados_urgencia_alta, 0) AS chamados_urgencia_alta,
  COALESCE(cs.total_consumo_kwh, 0.0) AS total_consumo_kwh,
  COALESCE(cs.ucs_com_leitura, 0) AS ucs_com_leitura,
  COALESCE(p.ucs_prioridade_alta, 0) AS ucs_prioridade_alta,
  CASE
    WHEN COALESCE(ch.chamados_risco_saude, 0) > 0
      THEN 'Atendimento prioritario: cliente com risco a saude afetado'
    WHEN COALESCE(ch.chamados_ouvidoria, 0) > 0
      THEN 'Atencao ouvidoria: cliente com mencao a ANEEL/Procon/Ouvidoria'
    WHEN COALESCE(i.uc_horas_interrompidas, 0) > 500.0 OR COALESCE(i.ucs_afetadas, 0) > 1000
      THEN 'Manutencao de emergencia na rede: alto volume de UCs desabastecidas'
    WHEN COALESCE(p.ucs_prioridade_alta, 0) > 0
      THEN 'Despachar equipe de inspeção tecnica para UCs prioritarias'
    ELSE 'Operacao normal'
  END AS acao_recomendada,
  current_timestamp() AS processado_gold_em
FROM datas_conjuntos d
JOIN info_conjuntos c ON d.id_conjunto = c.id_conjunto
LEFT JOIN agg_interrupcoes i ON d.id_conjunto = i.id_conjunto AND d.data = i.data
LEFT JOIN agg_chamados ch ON d.id_conjunto = ch.id_conjunto AND d.data = ch.data
LEFT JOIN agg_consumo cs ON d.id_conjunto = cs.id_conjunto AND d.data = cs.data
LEFT JOIN agg_prioridades p ON d.id_conjunto = p.id_conjunto;
