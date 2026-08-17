-- ============================================================================
-- CAMADA GOLD — PRIORIDADE DE INSPECAO TECNICA (RN-06, RN-07, RN-08, RN-14)
--
-- Aplica a analise dos dois eixos simultaneos de consumo (queda individual vs estabilidade do conjunto)
-- combinada com sinais fisicos de violacao no medidor.
--
-- PROIBICAO REQUISITO RN-07:
-- A saida e ESTRITAMENTE prioridade (alta, media, baixa). Nenhuma coluna, valor ou comentario
-- utiliza os rotulos "fraude", "furto" ou "culpado".
-- ============================================================================

CREATE OR REFRESH MATERIALIZED VIEW ${catalogo}.${schema_gold}.prioridade_inspecao_uc
TBLPROPERTIES ('delta.feature.timestampNtz' = 'supported')
COMMENT 'Classificacao auditavel de prioridade de inspeção técnica por UC com base nos dois eixos de consumo e sinais fisicos (RN-06, RN-07)'
AS WITH violacao_recente AS (
  SELECT
    id_uc,
    MAX(sinal_violacao_medidor) AS sinal_violacao_recente
  FROM ${catalogo}.${schema_bronze}.consumo_diario
  GROUP BY id_uc
),
base_prioridade AS (
  SELECT
    b.id_uc,
    b.id_conjunto,
    u.nome_conjunto,
    u.bairro,
    u.classe_consumo,
    b.media_baseline_uc AS consumo_medio_baseline_kwh,
    b.media_recente_uc AS consumo_medio_recente_kwh,
    b.dias_baseline_uc AS dias_no_baseline,
    b.dias_recente_uc AS dias_no_periodo_recente,
    b.variacao_pct_uc AS variacao_da_uc,
    b.variacao_pct_conjunto AS variacao_do_conjunto,
    COALESCE(v.sinal_violacao_recente, false) AS sinal_violacao_recente,
    (b.variacao_pct_uc < -20.0) AS caiu_contra_si,
    (ABS(b.variacao_pct_conjunto) <= 10.0) AS vizinhanca_estavel,
    (b.variacao_pct_uc < -20.0 AND ABS(b.variacao_pct_conjunto) <= 10.0) AS atende_os_dois_eixos
  FROM ${catalogo}.${schema_silver}.baseline_consumo b
  JOIN ${catalogo}.${schema_silver}.unidades_consumidoras u ON b.id_uc = u.id_uc
  LEFT JOIN violacao_recente v ON b.id_uc = v.id_uc
)
SELECT
  id_uc,
  id_conjunto,
  nome_conjunto,
  bairro,
  classe_consumo,
  caiu_contra_si,
  vizinhanca_estavel,
  atende_os_dois_eixos,
  sinal_violacao_recente,
  variacao_da_uc,
  variacao_do_conjunto,
  consumo_medio_baseline_kwh,
  consumo_medio_recente_kwh,
  dias_no_baseline,
  dias_no_periodo_recente,
  CASE
    WHEN atende_os_dois_eixos AND sinal_violacao_recente THEN 'alta'
    WHEN atende_os_dois_eixos OR sinal_violacao_recente THEN 'media'
    ELSE 'baixa'
  END AS prioridade_inspecao,
  CASE
    WHEN atende_os_dois_eixos AND sinal_violacao_recente THEN 'Queda individual acentuada com vizinhanca estavel e sinal de alerta no medidor'
    WHEN atende_os_dois_eixos THEN 'Queda de consumo individual acentuada com vizinhanca estavel'
    WHEN sinal_violacao_recente THEN 'Alerta de violacao registrado no medidor sem queda expressiva de consumo'
    WHEN caiu_contra_si AND NOT vizinhanca_estavel THEN 'Queda de consumo acompanhada por variacao no conjunto (possivel evento de rede)'
    ELSE 'Comportamento de consumo dentro dos padroes normais'
  END AS motivo_observado,
  current_timestamp() AS processado_gold_em
FROM base_prioridade;
