-- ============================================================================
-- RN-10 — GOVERNANCA E MASCARAMENTO DE DADOS PESSOAIS NA LEITURA (BRONZE)
--
-- Esta function de Column Mask do Unity Catalog garante que apenas membros do
-- grupo 'atendimento' (ou administradores) tenham acesso aos dados pessoais
-- originais (nome, telefone e transcricao identificada) da tabela bronze.chamados.
-- Todos os outros usuarios visualizam '[RESTRITO]'.
--
-- ATENCAO / LIMITACAO:
-- A tabela bronze.chamados e recriada durante execucoes com Full Refresh do pipeline DLT,
-- o que remove as mascaras aplicadas. Por isso, este script deve ser executado como uma
-- task de SQL Job apos a execucao do pipeline.
-- ============================================================================

-- 1. Criar a funcao de mascara no schema bronze
CREATE OR REPLACE FUNCTION ${catalogo}.${schema_bronze}.mascarar_dado_pessoal(valor STRING)
RETURN CASE
  WHEN is_account_group_member('atendimento') THEN valor
  ELSE '[RESTRITO]'
END;

-- 2. Aplicar a mascara nas colunas sensiveis de bronze.chamados
ALTER TABLE ${catalogo}.${schema_bronze}.chamados
  ALTER COLUMN nome_solicitante SET MASK ${catalogo}.${schema_bronze}.mascarar_dado_pessoal;

ALTER TABLE ${catalogo}.${schema_bronze}.chamados
  ALTER COLUMN telefone_solicitante SET MASK ${catalogo}.${schema_bronze}.mascarar_dado_pessoal;

ALTER TABLE ${catalogo}.${schema_bronze}.chamados
  ALTER COLUMN transcricao SET MASK ${catalogo}.${schema_bronze}.mascarar_dado_pessoal;
