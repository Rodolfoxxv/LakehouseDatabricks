-- ============================================================================
-- RN-04 — METRIC VIEW DE CONTINUIDADE (DEC / FEC DEFINICAO UNIFICADA)
--
-- Esta Metric View do Unity Catalog e a UNICA fonte da verdade para DEC e FEC.
-- Nenhuma tabela gold calcula DEC ou FEC em colunas estaticas.
-- ============================================================================

USE CATALOG IDENTIFIER(:catalogo);
USE SCHEMA IDENTIFIER(:schema_gold);

CREATE OR REPLACE VIEW continuidade_metricas
WITH METRICS
LANGUAGE YAML
AS $$
version: '1.1'
source: continuidade_conjunto_mes
comment: "Metric View de continuidade para apuracao unificada de DEC e FEC (RN-04)"

dimensions:
  - { expr: "nome_conjunto", name: "Conjunto", comment: "Nome do conjunto de distribuicao geografica" }
  - { expr: "id_conjunto", name: "Codigo do Conjunto", comment: "Identificador unico do conjunto" }
  - { expr: "municipio", name: "Municipio", comment: "Municipio do conjunto" }
  - { expr: "mes_apuracao", name: "Mes", comment: "Mes de apuracao dos indicadores" }

measures:
  - { expr: "SUM(uc_horas_interrompidas) / SUM(total_ucs)", name: "DEC", comment: "Duracao Equivalente de Interrupcao por UC media mensal em horas" }
  - { expr: "SUM(uc_interrupcoes) / SUM(total_ucs)", name: "FEC", comment: "Frequencia Equivalente de Interrupcao por UC media mensal" }
  - { expr: "SUM(uc_horas_interrompidas) / (SUM(total_ucs) / COUNT(DISTINCT mes_apuracao))", name: "DEC Acumulado", comment: "Duracao Equivalente de Interrupcao acumulada no periodo em horas" }
  - { expr: "SUM(uc_interrupcoes) / (SUM(total_ucs) / COUNT(DISTINCT mes_apuracao))", name: "FEC Acumulado", comment: "Frequencia Equivalente de Interrupcao acumulada no periodo" }
  - { expr: "SUM(qtd_interrupcoes)", name: "Interrupcoes", comment: "Quantidade total de eventos de interrupcao validos" }
  - { expr: "SUM(qtd_interrupcoes_climaticas)", name: "Interrupcoes Climaticas", comment: "Quantidade de interrupcoes causadas por fatores climaticos" }
  - { expr: "SUM(qtd_interrupcoes_climaticas) / NULLIF(SUM(qtd_interrupcoes), 0)", name: "Proporcao Climatica", comment: "Proporcao de interrupcoes causadas por intemperies" }
  - { expr: "SUM(qtd_interrupcoes_programadas)", name: "Interrupcoes Programadas", comment: "Quantidade de interrupcoes programadas com aviso previo" }
  - { expr: "SUM(uc_horas_interrompidas)", name: "Horas UC Interrompidas", comment: "Soma do produto duracao em horas vezes UCs afetadas" }
  - { expr: "MAX(maior_duracao_horas)", name: "Maior Interrupcao", comment: "Maior duracao individual de interrupcao no periodo em horas" }
  - { expr: "SUM(total_ucs) / COUNT(DISTINCT mes_apuracao)", name: "Total de UCs", comment: "Total medio de unidades consumidoras ativas no conjunto" }
$$;
