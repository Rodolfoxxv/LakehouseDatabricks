# Grid Intelligence — Luz do Vale Distribuidora S.A.

Plataforma de dados e IA no Databricks para distribuidora de energia elétrica (projeto **Grid Intelligence**).

## Estrutura do Projeto

* `src/`: Código fonte em Python.
  * `src/grid_intelligence/`: Módulos compartilhados para pipelines e jobs.
* `resources/`: Definições do Declarative Automation Bundle (DABs) — schemas, volumes, pipelines, jobs.
* `.llm/prd.md`: Documentação de PRD, regras de negócio e glossário do projeto.

---

## Setup e Deploy com Databricks CLI (DABs)

### 1. Requisitos e Perfis
O perfil configurado no Databricks CLI deve ser `grid_intelligence`:
```bash
databricks bundle validate --profile grid_intelligence
```

### 2. Deploy nos Ambientes (`dev` e `prod`)
```bash
# Deploy no ambiente de desenvolvimento (Catálogo: grid_dev)
databricks bundle deploy -t dev --profile grid_intelligence

# Deploy no ambiente de produção (Catálogo: grid_intelligence)
databricks bundle deploy -t prod --profile grid_intelligence
```

---

## 🚨 Instalação e Reset de Catálogos (Comando Destrutivo)

> [!CAUTION]
> **ATENÇÃO:** O comando abaixo é **extremamente destrutivo** e remove permanentemente o catálogo, todos os seus schemas, tabelas, volumes e arquivos contidos. Sempre confirme antes de rodar.

Para recomeçar o ambiente `grid_dev` limpo do zero:
```bash
databricks experimental aitools tools query --profile grid_intelligence \
  "DROP CATALOG IF EXISTS grid_dev CASCADE"
```
