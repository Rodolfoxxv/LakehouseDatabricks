-- 1. Tabela silver.consumo_diario: deduplicacao e descarte de consumo nulo, negativo ou acima do limite fisico
CREATE OR REFRESH MATERIALIZED VIEW ${catalogo}.${schema_silver}.consumo_diario
TBLPROPERTIES ('delta.feature.timestampNtz' = 'supported')
AS SELECT
  c.id_uc,
  c.data,
  c.consumo_kwh,
  u.id_conjunto,
  u.bairro,
  u.classe_consumo,
  c.arquivo_origem,
  c.ingerido_bronze_em,
  current_timestamp() AS processado_silver_em
FROM ${catalogo}.${schema_bronze}.consumo_diario c
JOIN ${catalogo}.${schema_silver}.unidades_consumidoras u
  ON c.id_uc = u.id_uc
WHERE c.consumo_kwh IS NOT NULL
  AND c.consumo_kwh >= 0
  AND c.consumo_kwh <= CASE u.classe_consumo
    WHEN 'residencial' THEN 150.0
    WHEN 'comercial'   THEN 1000.0
    WHEN 'industrial'  THEN 10000.0
    WHEN 'rural'       THEN 500.0
    ELSE 2000.0
  END
QUALIFY ROW_NUMBER() OVER (PARTITION BY c.id_uc, c.data ORDER BY c.ingerido_bronze_em DESC) = 1;

-- 2. Tabela silver.baseline_consumo: comparacao da janela recente (ultimos 30 dias) vs baseline (90 dias anteriores)
CREATE OR REFRESH MATERIALIZED VIEW ${catalogo}.${schema_silver}.baseline_consumo
AS WITH ancoragem AS (
  SELECT MAX(data) AS max_data FROM ${catalogo}.${schema_silver}.consumo_diario
),
stats_uc AS (
  SELECT
    c.id_uc,
    c.id_conjunto,
    AVG(CASE WHEN c.data > a.max_data - INTERVAL 30 DAYS THEN c.consumo_kwh END) AS media_recente_uc,
    AVG(CASE WHEN c.data <= a.max_data - INTERVAL 30 DAYS AND c.data > a.max_data - INTERVAL 120 DAYS THEN c.consumo_kwh END) AS media_baseline_uc,
    COUNT(CASE WHEN c.data > a.max_data - INTERVAL 30 DAYS THEN 1 END) AS dias_recente_uc,
    COUNT(CASE WHEN c.data <= a.max_data - INTERVAL 30 DAYS AND c.data > a.max_data - INTERVAL 120 DAYS THEN 1 END) AS dias_baseline_uc
  FROM ${catalogo}.${schema_silver}.consumo_diario c
  CROSS JOIN ancoragem a
  WHERE c.data > a.max_data - INTERVAL 120 DAYS
  GROUP BY c.id_uc, c.id_conjunto
),
stats_conjunto AS (
  SELECT
    id_conjunto,
    AVG(media_recente_uc) AS media_recente_conjunto,
    AVG(media_baseline_uc) AS media_baseline_conjunto
  FROM stats_uc
  GROUP BY id_conjunto
)
SELECT
  u.id_uc,
  u.id_conjunto,
  ROUND(u.media_recente_uc, 2) AS media_recente_uc,
  ROUND(u.media_baseline_uc, 2) AS media_baseline_uc,
  u.dias_recente_uc,
  u.dias_baseline_uc,
  ROUND(100.0 * (u.media_recente_uc - u.media_baseline_uc) / NULLIF(u.media_baseline_uc, 0), 2) AS variacao_pct_uc,
  ROUND(j.media_recente_conjunto, 2) AS media_recente_conjunto,
  ROUND(j.media_baseline_conjunto, 2) AS media_baseline_conjunto,
  ROUND(100.0 * (j.media_recente_conjunto - j.media_baseline_conjunto) / NULLIF(j.media_baseline_conjunto, 0), 2) AS variacao_pct_conjunto,
  current_timestamp() AS processado_silver_em
FROM stats_uc u
JOIN stats_conjunto j ON u.id_conjunto = j.id_conjunto;
