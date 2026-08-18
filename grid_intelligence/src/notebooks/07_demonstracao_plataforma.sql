-- Databricks notebook source
-- DBTITLE 1,Demonstração da Plataforma Grid Intelligence (Prompt 07)
-- 8 Consultas de Prova dos Requisitos de Negócio e Arquitetura do Lakehouse

-- COMMAND ----------
-- DBTITLE 1,Prova 1: RN-01 tem efeito (Filtragem de Interrupções Duplicadas / Menores que 3 min)
-- Prova a eficácia da filtragem regulatória ANEEL entre a camada Bronze e Silver
SELECT
  (SELECT COUNT(*) FROM grid_dev.bronze.interrupcoes) AS total_registros_bronze,
  (SELECT COUNT(*) FROM grid_dev.silver.interrupcoes_limpas) AS total_registros_silver,
  (SELECT COUNT(*) FROM grid_dev.bronze.interrupcoes) - (SELECT COUNT(*) FROM grid_dev.silver.interrupcoes_limpas) AS interrupcoes_descartadas,
  ROUND(100.0 * ((SELECT COUNT(*) FROM grid_dev.bronze.interrupcoes) - (SELECT COUNT(*) FROM grid_dev.silver.interrupcoes_limpas)) / (SELECT COUNT(*) FROM grid_dev.bronze.interrupcoes), 2) AS percentual_descartado_pct;

-- COMMAND ----------
-- DBTITLE 1,Prova 2: A qualidade tem efeito (Regras de Sanitização de Consumo)
-- Prova o descarte de leituras negativas e com qualidade != 'OK' entre Bronze e Silver
SELECT
  qualidade_leitura,
  COUNT(*) AS total_leituras_bronze,
  SUM(CASE WHEN consumo_kwh >= 0 AND qualidade_leitura = 'OK' THEN 1 ELSE 0 END) AS leituras_aproveitadas_silver,
  SUM(CASE WHEN consumo_kwh < 0 OR qualidade_leitura != 'OK' OR qualidade_leitura IS NULL THEN 1 ELSE 0 END) AS leituras_descartadas
FROM grid_dev.bronze.telemetria
GROUP BY qualidade_leitura
ORDER BY total_leituras_bronze DESC;

-- COMMAND ----------
-- DBTITLE 1,Prova 3: RN-04 é real (Metric View DEC vs Cálculo Manual Insumos)
-- Prova que a Metric View 'continuidade_metricas' bate EXATAMENTE com o cálculo regulatório manual (DIC acumulado / UCs distintas)
WITH mv AS (
  SELECT `Conjunto` AS nome_conjunto, `Mes` AS mes_apuracao, MEASURE(`DEC`) AS dec_metric_view
  FROM grid_dev.gold.continuidade_metricas
  GROUP BY ALL
),
calc AS (
  SELECT nome_conjunto, mes_apuracao, ROUND(SUM(dic_horas_acumuladas) / COUNT(DISTINCT id_uc), 2) AS dec_calculado_manual
  FROM grid_dev.gold.continuidade_conjunto_mes
  GROUP BY nome_conjunto, mes_apuracao
)
SELECT
  mv.nome_conjunto,
  mv.mes_apuracao,
  mv.dec_metric_view,
  calc.dec_calculado_manual,
  ROUND(mv.dec_metric_view - calc.dec_calculado_manual, 4) AS diferenca_exata
FROM mv
JOIN calc ON mv.nome_conjunto = calc.nome_conjunto AND mv.mes_apuracao = calc.mes_apuracao
ORDER BY mv.mes_apuracao DESC, mv.nome_conjunto
LIMIT 15;

-- COMMAND ----------
-- DBTITLE 1,Prova 4: Os dois eixos funcionam (Inspeção Técnica de Perdas Não-Técnicas)
-- Prova que UCs de alta prioridade exibem queda individual enquanto o conjunto permanece estável
SELECT
  id_uc,
  nome_conjunto,
  bairro,
  prioridade_inspecao,
  variacao_individual_pct,
  variacao_conjunto_pct,
  flag_violacao_medidor,
  data_classificacao
FROM grid_dev.gold.prioridade_inspecao_uc
WHERE prioridade_inspecao = 'alta'
ORDER BY variacao_individual_pct ASC
LIMIT 10;

-- COMMAND ----------
-- DBTITLE 1,Prova 5: A anonimização funciona (Mascara PII Regex RN-09)
-- Prova a desidentificação de CPF e Telefone em chamados telefônicos entre Bronze e Silver
SELECT
  b.id_chamado,
  b.fala_cliente AS fala_bronze_com_pii,
  s.fala_cliente_anonimizada AS fala_silver_anonimizada,
  s.flag_pii_removida
FROM grid_dev.bronze.chamados b
JOIN grid_dev.silver.chamados_enriquecidos s ON b.id_chamado = s.id_chamado
WHERE b.fala_cliente RLIKE '[0-9]{3}\\.[0-9]{3}\\.[0-9]{3}-[0-9]{2}' 
   OR b.fala_cliente RLIKE '\\([0-9]{2}\\)\\s?[0-9]{4,5}-[0-9]{4}'
   OR b.fala_cliente LIKE '%CPF%'
LIMIT 10;

-- COMMAND ----------
-- DBTITLE 1,Prova 6: O evento narrativo está lá (Pico de Chamados na Noite da Cascata 2025-10-15)
-- Prova o surto de chamados durante a tempestade de 15/10/2025 comparado com a média das mesmas horas nos outros dias
WITH tempestade AS (
  SELECT HOUR(data_hora_chamado) AS hora, COUNT(*) AS chamados_tempestade_15out
  FROM grid_dev.silver.chamados_enriquecidos
  WHERE CAST(data_hora_chamado AS DATE) = '2025-10-15'
  GROUP BY HOUR(data_hora_chamado)
),
normalidade AS (
  SELECT HOUR(data_hora_chamado) AS hora, ROUND(COUNT(*) / COUNT(DISTINCT CAST(data_hora_chamado AS DATE)), 1) AS media_chamados_outros_dias
  FROM grid_dev.silver.chamados_enriquecidos
  WHERE CAST(data_hora_chamado AS DATE) != '2025-10-15'
  GROUP BY HOUR(data_hora_chamado)
)
SELECT
  t.hora,
  t.chamados_tempestade_15out,
  n.media_chamados_outros_dias,
  ROUND(t.chamados_tempestade_15out / NULLIF(n.media_chamados_outros_dias, 0), 1) AS multiplicador_anomalia
FROM tempestade t
JOIN normalidade n ON t.hora = n.hora
ORDER BY t.hora;

-- COMMAND ----------
-- DBTITLE 1,Prova 7: A tendência está lá (Crescimento de Consumo ~30% ao ano)
-- Prova a tendência anual de crescimento sintético no período de 4 anos (2022-2025)
WITH consumo_anual AS (
  SELECT YEAR(data_leitura) AS ano, ROUND(SUM(consumo_kwh) / 1000000.0, 2) AS consumo_total_gwh
  FROM grid_dev.silver.consumo_diario
  GROUP BY YEAR(data_leitura)
)
SELECT
  ano,
  consumo_total_gwh,
  LAG(consumo_total_gwh) OVER (ORDER BY ano) AS consumo_ano_anterior_gwh,
  ROUND(100.0 * (consumo_total_gwh - LAG(consumo_total_gwh) OVER (ORDER BY ano)) / LAG(consumo_total_gwh) OVER (ORDER BY ano), 2) AS crescimento_anual_pct
FROM consumo_anual
ORDER BY ano;

-- COMMAND ----------
-- DBTITLE 1,Prova 8: A sazonalidade está lá (Pico de Chamados no Verão)
-- Prova que os meses quentes do verão (Dez/Jan/Fev/Mar) possuem aproximadamente o dobro de chamados que o inverno
SELECT
  MONTH(data_hora_chamado) AS num_mes,
  CASE MONTH(data_hora_chamado)
    WHEN 1 THEN '01 - Janeiro (Verão)' WHEN 2 THEN '02 - Fevereiro (Verão)' WHEN 3 THEN '03 - Março (Verão)'
    WHEN 4 THEN '04 - Abril' WHEN 5 THEN '05 - Maio' WHEN 6 THEN '06 - Junho (Inverno)'
    WHEN 7 THEN '07 - Julho (Inverno)' WHEN 8 THEN '08 - Agosto (Inverno)' WHEN 9 THEN '09 - Setembro'
    WHEN 10 THEN '10 - Outubro' WHEN 11 THEN '11 - Novembro' WHEN 12 THEN '12 - Dezembro (Verão)'
  END AS mes_estacao,
  COUNT(*) AS total_chamados_acumulado,
  ROUND(COUNT(*) / COUNT(DISTINCT YEAR(data_hora_chamado)), 0) AS media_chamados_por_ano
FROM grid_dev.silver.chamados_enriquecidos
GROUP BY MONTH(data_hora_chamado)
ORDER BY num_mes;
