-- ============================================================================
-- CAMADA SILVER — TEXTO (CHAMADOS) — ROTA DETERMINISTICA (REGRAS DE TEXTO / REGEX)
--
-- LIMITACOES CONHECIDAS DA EXTRACAO POR REGRA (RF-09):
-- 1. Ironia e Negacao: Frases como "Que otimo, mais um dia sem luz" sao classificadas como 'positive'.
-- 2. Sinonimos fora da lista: "Ta tudo apagado" e capturado; "Fiquei no breu" nao e capturado.
-- 3. Motivos compostos: Chamados que relatam falta de energia E fatura alta recebem apenas um rotulo (o primeiro do CASE).
-- 4. Nomes proprios com grafia diferente: Se o cliente se apresenta por apelido na transcricao, a subscrição pelo nome da coluna nao casa e o nome pode nao ser totalmente removido no regex simples.
-- ============================================================================

-- 1. silver.chamados_anonimizados (RN-09): Anonimizacao de PII antes de qualquer analise
CREATE OR REFRESH MATERIALIZED VIEW ${catalogo}.${schema_silver}.chamados_anonimizados
TBLPROPERTIES ('delta.feature.timestampNtz' = 'supported')
AS SELECT
  c.id_chamado,
  c.id_uc,
  u.id_cliente,
  u.id_conjunto,
  u.bairro,
  u.classe_consumo,
  c.abertura,
  TO_DATE(c.abertura) AS data_chamado,
  HOUR(c.abertura) AS hora_chamado,
  DATE_TRUNC('MONTH', c.abertura) AS mes_chamado,
  c.canal,
  c.duracao_segundos,
  regexp_replace(
    regexp_replace(
      replace(c.transcricao, c.nome_solicitante, '[MASCARADO]'),
      '[0-9]{3}\\.[0-9]{3}\\.[0-9]{3}-[0-9]{2}',
      '[MASCARADO]'
    ),
    '\\([0-9]{2}\\)\\s*9?[0-9]{4}-?[0-9]{4}',
    '[MASCARADO]'
  ) AS transcricao_anonimizada,
  'regras_de_texto' AS anonimizado_por,
  c.origem,
  c.arquivo_origem,
  c.ingerido_bronze_em,
  current_timestamp() AS processado_silver_em
FROM ${catalogo}.${schema_bronze}.chamados c
LEFT JOIN ${catalogo}.${schema_silver}.unidades_consumidoras u
  ON c.id_uc = u.id_uc;

-- 2. silver.chamados_enriquecidos (RF-05): Extracao de conteudo sobre o texto JA ANONIMIZADO
CREATE OR REFRESH MATERIALIZED VIEW ${catalogo}.${schema_silver}.chamados_enriquecidos
TBLPROPERTIES ('delta.feature.timestampNtz' = 'supported')
AS SELECT
  id_chamado,
  id_uc,
  id_cliente,
  id_conjunto,
  bairro,
  classe_consumo,
  abertura,
  data_chamado,
  hora_chamado,
  mes_chamado,
  canal,
  duracao_segundos,
  transcricao_anonimizada,
  CASE
    WHEN transcricao_anonimizada RLIKE '(?i)obrigado|agradeco|otimo|parabens|resolveu' THEN 'positive'
    WHEN transcricao_anonimizada RLIKE '(?i)absurdo|pessimo|vergonha|processo|ouvidoria|aneel|procon|prejuizo|processar' THEN 'negative'
    ELSE 'neutral'
  END AS sentimento,
  CASE
    WHEN transcricao_anonimizada RLIKE '(?i)dialise|oxigenio|remedio|crianca|hospital|faisca|incendio|idoso'
      THEN 'religacao_urgente'
    WHEN transcricao_anonimizada RLIKE '(?i)escuro|sem energia|apagou|falta de energia|sem luz'
      THEN 'falta_energia'
    WHEN transcricao_anonimizada RLIKE '(?i)piscando|oscila|queimou|tensao'
      THEN 'oscilacao_tensao'
    WHEN transcricao_anonimizada RLIKE '(?i)releitura|estimativa|nao bate'
      THEN 'erro_leitura'
    WHEN transcricao_anonimizada RLIKE '(?i)conta veio|dobro|fatura subiu|trezentos reais'
      THEN 'fatura_alta'
    WHEN transcricao_anonimizada RLIKE '(?i)poste|galho|lampada da rua'
      THEN 'poste_avariado'
    WHEN transcricao_anonimizada RLIKE '(?i)religacao|religar|paguei'
      THEN 'religacao'
    ELSE 'duvida_cadastral'
  END AS motivo,
  CASE
    WHEN transcricao_anonimizada RLIKE '(?i)transformador' THEN 'transformador'
    WHEN transcricao_anonimizada RLIKE '(?i)medidor'       THEN 'medidor'
    WHEN transcricao_anonimizada RLIKE '(?i)poste'         THEN 'poste'
    WHEN transcricao_anonimizada RLIKE '(?i)fio|fiacao'    THEN 'fio'
    WHEN transcricao_anonimizada RLIKE '(?i)disjuntor'     THEN 'disjuntor'
    ELSE 'nao_especificado'
  END AS equipamento_citado,
  transcricao_anonimizada RLIKE '(?i)oxigenio|dialise|remedio|crianca|hospital|faisca|incendio|idoso' AS risco_a_saude,
  CASE
    WHEN transcricao_anonimizada RLIKE '(?i)oxigenio|dialise|remedio|crianca|hospital|faisca|incendio|idoso' THEN 'alta'
    WHEN transcricao_anonimizada RLIKE '(?i)escuro|sem energia|apagou|falta de energia|sem luz|religacao|poste' THEN 'media'
    ELSE 'baixa'
  END AS urgencia,
  transcricao_anonimizada RLIKE '(?i)ouvidoria|aneel|procon|processo' AS ameacou_ouvidoria,
  anonimizado_por,
  'regras_de_texto' AS enriquecido_por,
  origem,
  arquivo_origem,
  ingerido_bronze_em,
  current_timestamp() AS processado_silver_em
FROM ${catalogo}.${schema_silver}.chamados_anonimizados;
