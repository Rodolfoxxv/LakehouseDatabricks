-- ============================================================================
-- CAMADA GOLD — SAUDE DO CLIENTE E RISCO DE OUVIDORIA (RN-09, RN-10, RN-14)
--
-- O grao desta tabela e o CLIENTE (id_cliente), nao a UC, permitindo consolidar
-- o historico de relacionamentos de clientes com múltiplas UCs.
-- Utiliza estritamente os textos JA ANONIMIZADOS da silver (RN-09).
-- ============================================================================

CREATE OR REFRESH MATERIALIZED VIEW ${catalogo}.${schema_gold}.saude_cliente
TBLPROPERTIES ('delta.feature.timestampNtz' = 'supported')
COMMENT 'Saude do relacionamento e indicador de risco de ouvidoria por cliente com dados anonimizados'
AS WITH ucs_cliente AS (
  SELECT
    id_cliente,
    FIRST(id_conjunto) AS id_conjunto,
    FIRST(bairro) AS bairro
  FROM ${catalogo}.${schema_silver}.unidades_consumidoras
  GROUP BY id_cliente
),
conjuntos AS (
  SELECT DISTINCT id_conjunto, nome_conjunto FROM ${catalogo}.${schema_silver}.unidades_consumidoras
)
SELECT
  c.id_cliente,
  u.id_conjunto,
  j.nome_conjunto,
  u.bairro,
  COUNT(*) AS qtd_chamados,
  COUNT(DISTINCT c.id_uc) AS qtd_ucs_com_chamado,
  COUNT_IF(c.sentimento = 'negative') AS qtd_chamados_negativos,
  ROUND(100.0 * COUNT_IF(c.sentimento = 'negative') / COUNT(*), 1) AS proporcao_negativa,
  COUNT_IF(c.ameacou_ouvidoria) AS qtd_mencoes_ouvidoria,
  COUNT_IF(c.risco_a_saude) AS qtd_chamados_risco_saude,
  COUNT_IF(c.urgencia = 'alta') AS qtd_urgencia_alta,
  (COUNT(*) >= 3) AS reincidente,
  MODE(c.motivo) AS motivo_predominante,
  MAX_BY(c.equipamento_citado, c.abertura) AS ultimo_equipamento_citado,
  MAX_BY(c.transcricao_anonimizada, c.abertura) AS ultima_fala,
  MIN(c.abertura) AS primeiro_chamado_em,
  MAX(c.abertura) AS ultimo_chamado_em,
  CASE
    WHEN COUNT_IF(c.ameacou_ouvidoria) > 0 THEN 'alto'
    WHEN COUNT(*) >= 3 AND COUNT_IF(c.sentimento = 'negative') > 0 THEN 'alto'
    WHEN COUNT_IF(c.risco_a_saude) > 0 THEN 'alto'
    WHEN COUNT_IF(c.sentimento = 'negative') > 0 OR COUNT(*) >= 2 THEN 'medio'
    ELSE 'baixo'
  END AS risco_ouvidoria,
  current_timestamp() AS processado_gold_em
FROM ${catalogo}.${schema_silver}.chamados_enriquecidos c
JOIN ucs_cliente u ON c.id_cliente = u.id_cliente
LEFT JOIN conjuntos j ON u.id_conjunto = j.id_conjunto
GROUP BY c.id_cliente, u.id_conjunto, j.nome_conjunto, u.bairro;
