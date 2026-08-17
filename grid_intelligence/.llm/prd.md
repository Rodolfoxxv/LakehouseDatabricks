# PRD — Grid Intelligence (Luz do Vale Distribuidora S.A.)

## Contexto de Negócio

A **Luz do Vale Distribuidora S.A.** é uma distribuidora fictícia de energia elétrica operando sob regulação da ANEEL. A empresa lida com três grandes dores de negócio mensuráveis financeiramente:

1. **Continuidade do Fornecimento (DEC/FEC)**: Interrupções no fornecimento acima do limite regulatório geram compensação financeira automática aos consumidores (em 2024, distribuidoras brasileiras pagaram mais de R$ 1,1 bilhão).
2. **Perdas Não Técnicas (PNT)**: Energia distribuída e não faturada (furto, fraude e erros de medição) somando ~R$ 11,5 bilhões em 2025 no Brasil.
3. **Atendimento ao Cliente e Ouvidoria**: Transcrições de milhares de chamados contendo avisos antecipados de insatisfação e reclamações regulatórias sem análise sistematizada.

---

## Glossário do Projeto

| Termo | Definição |
|---|---|
| **UC — Unidade Consumidora** | O ponto de entrega de energia. **Não é sinônimo de cliente** (um cliente pode ter várias UCs). |
| **Conjunto** | Subdivisão geográfica da área de concessão; unidade de agregação regulatória da ANEEL. |
| **DEC** | Duração Equivalente de Interrupção por UC — tempo médio (em horas) sem fornecimento. |
| **FEC** | Frequência Equivalente de Interrupção por UC — número médio de interrupções. |
| **PNT** | Perdas Não Técnicas. |
| **Prioridade de inspeção** | Classificação de prioridade (alta, média, baixa) para envio de visita técnica à UC. |

---

## Regras de Negócio Globais

- **RN-01**: Só interrupções com **3 minutos ou mais** entram na apuração de DEC e FEC. A regra vive na camada de transformação, nunca no relatório.
- **RN-02**: A apuração de DEC e FEC considera o total de UCs do conjunto.
- **RN-03**: Baseline de consumo de UC é calculado por janela histórica de mesmo tipo de dia (útil vs final de semana/feriado).
- **RN-04**: DEC e FEC têm **uma única definição** no sistema, consumida por dashboard, agente e relatório.
- **RN-05**: Deduplicação e limpeza de registros são realizadas na camada silver.
- **RN-06**: Uma UC é candidata a inspeção quando o consumo cai em **dois eixos simultâneos**: contra o próprio baseline **e** enquanto a vizinhança permanece estável.
- **RN-07**: A saída da detecção é **prioridade de inspeção** (alta, média, baixa). **Nunca** um rótulo de fraude, furto ou culpa. Nenhuma coluna, variável ou comentário pode usar as palavras "fraude", "furto" ou "culpado".
- **RN-08**: Chamados de atendimento passam por estruturação e categorização de motivos.
- **RN-09**: Dado pessoal em transcrição é **mascarado antes** de qualquer análise de conteúdo.
- **RN-10**: O texto original identificado é preservado com **acesso restrito** (proteção na leitura e na análise).
- **RN-11**: A camada de ingestão **não filtra, não corrige e não aplica regra de negócio**. Leitura inválida de medidor é mantida na bronze como fato sobre o medidor.
- **RN-12**: Todo registro ingerido carrega origem (`_input_file_name`) e momento de ingestão (`_ingested_at`).
- **RN-13**: O agente conversacional acessa **apenas a camada de negócio (gold / metric views)**.
- **RN-14**: As entidades da **camada gold** carregam descrição em linguagem de negócio. Bronze e silver não usam `COMMENT` (são apenas passagem).

---

## Modelo de Informação e Datasets

Os dados de origem residem em `raw.landing` nos seguintes diretórios e grãos:

| Base | Grão | Volume Histórico |
|---|---|---|
| `unidades_consumidoras` | 1 por ponto de entrega | 4.000 UCs |
| `interrupcoes` | 1 por evento de rede | 1.383 registros |
| `consumo_diario` | 1 por UC por dia | ~5,85 milhões de linhas (4 anos) |
| `chamados` | 1 por ligação (com transcrição) | 2.801 chamados |

---

## Estrutura da Solução e Entregas

1. **Prompt 00 — Setup e Infraestrutura**: Instalação do bundle, criação dos catálogos `grid_dev` e `grid_intelligence`, schemas (`raw`, `bronze`, `silver`, `gold`) e volume `raw.landing`.
2. **Prompt 01 — Camada Bronze**: Ingestão fiel do volume sem filtros.
3. **Prompt 02 — Camada Silver (Números)**: Limpeza, deduplicação, regra dos 3 min (RN-01) e baseline de consumo.
4. **Prompt 03 — Camada Silver (Texto)**: Anonimização de PII (RN-09) e enriquecimento de transcrições.
5. **Prompt 04 — Camada Gold & Metric Views**: Modelo de negócio final com documentação (RN-14) e metric view unificada de DEC/FEC (RN-04).
6. **Prompt 05 — Dashboard AI/BI**: Visualização executiva sobre a camada gold.
7. **Prompt 06 — Agente Conversacional**: Copiloto assistente para consultas de linguagem natural sobre a camada gold (RN-13).
8. **Prompt 07 — Relatório e Validações**: Queries de homologação e relatório final de projeto.
