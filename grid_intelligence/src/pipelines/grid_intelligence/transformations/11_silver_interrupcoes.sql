CREATE OR REFRESH STREAMING TABLE ${catalogo}.${schema_silver}.interrupcoes_validas
TBLPROPERTIES ('delta.feature.timestampNtz' = 'supported')
AS SELECT
  id_interrupcao,
  id_conjunto,
  inicio,
  fim,
  duracao_minutos,
  tipo,
  causa,
  equipamento,
  qtd_ucs_afetadas,
  TO_DATE(inicio) AS data_evento,
  DATE_TRUNC('MONTH', inicio) AS mes_apuracao,
  duracao_minutos / 60.0 AS duracao_horas,
  (duracao_minutos / 60.0) * qtd_ucs_afetadas AS uc_horas_interrompidas,
  causa = 'climatica' AS causa_climatica,
  origem,
  arquivo_origem,
  ingerido_bronze_em,
  current_timestamp() AS processado_silver_em
FROM STREAM(${catalogo}.${schema_bronze}.interrupcoes)
-- RN-01: Religadores atuam automaticamente desarmando e religando em segundos (galho na rede, piscar de luz).
-- Apenas interrupcoes com duracao >= limiar regulatorio (3 min) entram na apuracao dos indicadores DEC/FEC.
WHERE duracao_minutos >= ${duracao_minima_interrupcao_min};
