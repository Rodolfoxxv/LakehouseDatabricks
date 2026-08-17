-- ============================================================================
-- CAMADA BRONZE — GRID INTELLIGENCE
-- Ingestao incremental fiel das bases brutas (RN-11) via Auto Loader (STREAM read_files)
--
-- ARMADILHA DO AUTO LOADER EM STREAMING TABLES:
-- Quando um arquivo no volume landing e sobrescrito (ex: regerado), o Auto Loader
-- com `allowOverwrites => true` reprocessa o arquivo. Porem, como a Streaming Table
-- e append-only, os registros antigos continuam na tabela e o volume duplica.
-- SOLUCAO: Apos regerar arquivos de origem no volume, execute o pipeline com Full Refresh.
-- ============================================================================

CREATE OR REFRESH STREAMING TABLE ${catalogo}.${schema_bronze}.unidades_consumidoras
TBLPROPERTIES ('delta.feature.timestampNtz' = 'supported')
AS SELECT
  *,
  _metadata.file_path AS arquivo_origem,
  current_timestamp() AS ingerido_bronze_em
FROM STREAM read_files(
  '${volume_landing}/unidades_consumidoras/',
  format => 'parquet'
);

CREATE OR REFRESH STREAMING TABLE ${catalogo}.${schema_bronze}.interrupcoes
TBLPROPERTIES ('delta.feature.timestampNtz' = 'supported')
AS SELECT
  *,
  _metadata.file_path AS arquivo_origem,
  current_timestamp() AS ingerido_bronze_em
FROM STREAM read_files(
  '${volume_landing}/interrupcoes/',
  format => 'parquet'
);

CREATE OR REFRESH STREAMING TABLE ${catalogo}.${schema_bronze}.consumo_diario
TBLPROPERTIES ('delta.feature.timestampNtz' = 'supported')
AS SELECT
  *,
  _metadata.file_path AS arquivo_origem,
  current_timestamp() AS ingerido_bronze_em
FROM STREAM read_files(
  '${volume_landing}/consumo_diario/',
  format => 'parquet'
);

CREATE OR REFRESH STREAMING TABLE ${catalogo}.${schema_bronze}.chamados
TBLPROPERTIES ('delta.feature.timestampNtz' = 'supported')
AS SELECT
  *,
  _metadata.file_path AS arquivo_origem,
  current_timestamp() AS ingerido_bronze_em
FROM STREAM read_files(
  '${volume_landing}/chamados/',
  format => 'parquet'
);
