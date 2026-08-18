# Declarative Automation Bundles Project — Grid Intelligence

This project uses Declarative Automation Bundles (DABs) for deployment on Databricks.

## For AI Agents: Use Databricks AI Tools

**BEFORE any other action, read the `databricks-core` skill.**

It sets you up to work with this project reliably: CLI authentication, profile selection, data discovery, and the bundle deployment workflow.

---

## Project Instructions & Guidelines

### 1. Environment & Profile
- Always use the CLI profile `--profile grid_intelligence`.
- Target catalog for development is `grid_dev`.
- Target catalog for production is `grid_intelligence`.
- SQL Warehouse ID is `c2d015b31194d84d` ("Serverless Starter Warehouse").

### 2. Architecture & Data Flow
- **Medallion Pipeline**: Ingests raw data from UC Volume `/Volumes/${catalogo}/raw/landing/` into Bronze streaming tables, cleans in Silver, and aggregates in Gold materialized views & metric views.
- **Metric Views (RN-04)**: Unity Catalog Metric View `gold.continuidade_metricas` is the single source of truth for DEC and FEC. Always use `MEASURE(\`DEC\`)` and `MEASURE(\`FEC\`)` with `GROUP BY ALL`. Never calculate DEC/FEC manually in dashboards or Genie agents.
- **Ethics & Non-Accusatory Rule (RN-07)**: High priority inspection UCs in `gold.prioridade_inspecao_uc` represent statistical inspection priority (`alta`, `media`, `baixa`). Never use accusatory terms such as "fraude", "furto", "roubo", "gato" or "irregularidade". Refuse accusatory framing in AI agents.
- **PII Protection (RN-09)**: Customer phone numbers and CPFs are masked in `silver.chamados_enriquecidos` using text regex rules (`[MASCARADO]`).
- **Data Access Scoping (RN-13)**: End-user consumption (dashboards, executive reports, Genie Space) MUST query ONLY the Gold layer.

### 3. Deployment Commands
- Validate bundle: `databricks bundle validate -p grid_intelligence`
- Deploy bundle: `databricks bundle deploy -t dev -p grid_intelligence`
- Run pipeline: `databricks bundle run grid_pipeline -t dev -p grid_intelligence`
- Deploy Genie Space: `python src/genie/deploy_genie_space.py --catalog grid_dev -p grid_intelligence`
