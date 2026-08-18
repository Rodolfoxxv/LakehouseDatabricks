# Databricks notebook source
# DBTITLE 1,Relatório Executivo Operacional (RF-08 e RF-09)
# Prompt 07 — Consolida operação do dia, normalidade (30d), continuidade do mês e ações prioritárias.

from pyspark.sql import SparkSession
import pyspark.sql.functions as F
import sys

# 1. Configuração de Parâmetros e Widgets
spark = SparkSession.builder.getOrCreate()

try:
    dbutils.widgets.text("regiao", "Campinas", "Região / Conjunto")
    dbutils.widgets.dropdown("usar_ia", "true", ["true", "false"], "Usar IA Generativa (ai_gen)")
    regiao = dbutils.widgets.get("regiao")
    usar_ia = dbutils.widgets.get("usar_ia").strip().lower() == "true"
except Exception:
    regiao = "Campinas"
    usar_ia = True

# Obtém catálogo da sessão Spark (padrão: grid_dev)
try:
    catalog = spark.conf.get("catalogo")
except Exception:
    catalog = "grid_dev"

print(f"=== GERANDO RELATÓRIO EXECUTIVO ===")
print(f"Catálogo: {catalog} | Região: {regiao} | Usar IA: {usar_ia}\n")

# 2. Leitura da Camada Gold — Painel Operacional Dia (RN-13)
df_painel = spark.table(f"{catalog}.gold.painel_operacional_dia").filter(F.col("nome_conjunto").contains(regiao))

if df_painel.count() == 0:
    raise ValueError(f"[ERRO DE REGIONAL] Nenhum registro operacional encontrado para a região '{regiao}' no catálogo {catalog}. Verifique o nome da região.")

# O dia de referência é o último dia com movimento no painel
ref_date = df_painel.select(F.max("data")).collect()[0][0]
print(f"Data de Referência (Último Movimento): {ref_date}")

# Filtra dados do dia de referência
df_dia = df_painel.filter(F.col("data") == ref_date)

row_dia = df_dia.select(
    F.sum("qtd_interrupcoes").alias("qtd_interrupcoes"),
    F.sum("uc_horas_interrompidas").alias("uc_horas"),
    F.sum("qtd_chamados").alias("qtd_chamados"),
    F.sum("chamados_ouvidoria").alias("chamados_ouvidoria"),
    F.sum("chamados_risco_saude").alias("chamados_saude"),
    F.sum("ucs_prioridade_alta").alias("ucs_prioridade_alta")
).collect()[0]

qtd_interrupcoes = row_dia["qtd_interrupcoes"] or 0
uc_horas = row_dia["uc_horas"] or 0.0
qtd_chamados = row_dia["qtd_chamados"] or 0
chamados_ouvidoria = row_dia["chamados_ouvidoria"] or 0
chamados_saude = row_dia["chamados_saude"] or 0
ucs_prioridade_alta = row_dia["ucs_prioridade_alta"] or 0

acoes_list = [r[0] for r in df_dia.select("acao_recomendada").distinct().collect() if r[0]]
acao_recomendada = "; ".join(acoes_list) if acoes_list else "Monitoramento operacional contínuo"

# 3. Comparação com a Normalidade (Média dos 30 dias anteriores)
df_30d = df_painel.filter((F.col("data") >= F.date_sub(F.lit(ref_date), 30)) & (F.col("data") < F.lit(ref_date)))
avg_30d_res = df_30d.select(F.avg("qtd_chamados")).collect()[0][0]
avg_30d = float(avg_30d_res) if avg_30d_res is not None else 1.0
ratio_30d = qtd_chamados / avg_30d if avg_30d > 0 else 1.0

# 4. Continuidade do Mês a partir da Metric View com MEASURE() (RN-04)
df_metric = spark.sql(f"""
    SELECT MEASURE(`DEC`) AS dec_horas, MEASURE(`FEC`) AS fec_vezes
    FROM {catalog}.gold.continuidade_metricas
    WHERE `Mes` = DATE_TRUNC('month', CAST('{ref_date}' AS DATE))
    GROUP BY ALL
""")
row_metric = df_metric.collect()[0] if df_metric.count() > 0 else None
dec_mes = float(row_metric["dec_horas"]) if row_metric and row_metric["dec_horas"] is not None else 0.0
fec_mes = float(row_metric["fec_vezes"]) if row_metric and row_metric["fec_vezes"] is not None else 0.0

# 5. O que precisa de Ação Hoje: Bairros com UCs Prioritárias & Clientes Risco Ouvidoria
df_bairros = spark.table(f"{catalog}.gold.prioridade_inspecao_uc") \
    .filter((F.col("nome_conjunto").contains(regiao)) & (F.col("prioridade_inspecao") == "alta")) \
    .groupBy("bairro").count().orderBy(F.col("count").desc())

bairros_collected = df_bairros.limit(3).collect()
top_bairros = ", ".join([f"{r['bairro']} ({r['count']} UCs)" for r in bairros_collected]) if bairros_collected else "Sem concentração crítica"

df_clientes_ouvidoria = spark.table(f"{catalog}.gold.saude_cliente") \
    .filter((F.col("nome_conjunto").contains(regiao)) & (F.col("risco_ouvidoria") == "alto"))
qtd_clientes_ouvidoria = df_clientes_ouvidoria.count()

# 6. Geração do Relatório (IA via ai_gen vs Gabarito sem IA - RF-09)
if usar_ia:
    prompt_ai = f"""Você é o analista executivo sênior de operações da distribuidora Luz do Vale.
Escreva um relatório executivo de no máximo 250 palavras para a diretoria sobre a regional {regiao} referente à data {ref_date}.

REGRAS DE CONFORMIDADE E ÉTICA (OBRIGATÓRIAS):
1. Use EXCLUSIVAMENTE os números fornecidos abaixo. Não estime, não arredonde para efeito e não invente valores.
2. UCs com variação de consumo atípico são classificadas como 'prioridade de inspeção'. NUNCA escreva ou mencione as palavras fraude, furto, roubo ou irregularidade.

DADOS BRUTOS OFICIAIS DO DIA:
- Região: {regiao}
- Data de Referência: {ref_date}
- Interrupções no dia: {qtd_interrupcoes}
- UC-horas sem fornecimento: {uc_horas:.2f}
- Volume de chamados hoje: {qtd_chamados}
- Média diária de chamados nos últimos 30 dias: {avg_30d:.1f} (Variação de {ratio_30d:.1f}x em relação ao normal)
- Chamados com risco à saúde: {chamados_saude}
- Chamados com menção a ouvidoria: {chamados_ouvidoria}
- DEC acumulado do mês: {dec_mes:.2f} horas
- FEC acumulado do mês: {fec_mes:.2f} interrupções
- UCs em prioridade alta de inspeção técnica: {ucs_prioridade_alta} (Principais bairros: {top_bairros})
- Clientes em risco de ouvidoria: {qtd_clientes_ouvidoria}
- Ação recomendada: {acao_recomendada}

ESTRUTURA DO TEXTO (EXATAMENTE 3 PARTES):
1. O QUE ACONTECEU: Resumo direto das interrupções, horas afetadas e principais motivos.
2. IMPACTO EM NÚMEROS: Comparação do volume de chamados contra a normalidade de 30 dias e os indicadores DEC/FEC do mês.
3. O QUE PRECISA DE AÇÃO HOJE: Ações imediatas exigidas, UCs prioritárias e gestão de clientes.
"""
    try:
        # Executa síntese IA usando ai_gen
        res_ai = spark.sql(f"SELECT ai_gen('{prompt_ai}') AS relatorio").collect()
        relatorio_texto = res_ai[0]["relatorio"]
    except Exception as e:
        print(f"[AVISO] Não foi possível invocar ai_gen: {e}. Alternando para gabarito determinístico.")
        usar_ia = False

if not usar_ia:
    relatorio_texto = f"""RELATÓRIO EXECUTIVO OPERACIONAL — REGIONAL {regiao.upper()}
Data de Referência: {ref_date}

1. O QUE ACONTECEU:
Em {ref_date}, a regional {regiao} registrou {qtd_interrupcoes} interrupções de fornecimento de energia, totalizando {uc_horas:.2f} UC-horas interrompidas. O volume de chamados de atendimento somou {qtd_chamados} registros, dos quais {chamados_saude} apresentaram risco à saúde e {chamados_ouvidoria} fizeram menção à ouvidoria.

2. IMPACTO EM NÚMEROS:
- Chamados no dia: {qtd_chamados} (Média dos 30 dias anteriores: {avg_30d:.1f} chamados/dia — variação de {ratio_30d:.1f}x em relação ao normal).
- Indicadores regulatórios acumulados no mês: DEC de {dec_mes:.2f} horas e FEC de {fec_mes:.2f} interrupções por UC.

3. O QUE PRECISA DE AÇÃO HOJE:
- Prioridade de inspeção técnica: {ucs_prioridade_alta} UCs com consumo atípico em prioridade alta de inspeção, concentradas nos bairros {top_bairros}.
- Gestão de clientes: {qtd_clientes_ouvidoria} cliente(s) com risco alto de abertura de ouvidoria.
- Ação operacional indicada: {acao_recomendada}.
"""

print("\n========================================================")
print("RELATÓRIO EXECUTIVO FINAL")
print("========================================================")
print(relatorio_texto)
print("========================================================\n")

# Salva o relatório como DataFrame na sessão
df_resultado = spark.createDataFrame([(ref_date, regiao, qtd_interrupcoes, uc_horas, qtd_chamados, ratio_30d, dec_mes, fec_mes, ucs_prioridade_alta, relatorio_texto)], 
    ["data_referencia", "regiao", "interrupcoes", "uc_horas", "chamados", "variacao_30d_ratio", "dec_mes", "fec_mes", "ucs_prioridade_alta", "relatorio_executivo"])

display(df_resultado)
