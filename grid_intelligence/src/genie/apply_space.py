import argparse
import json
import os
import sys
from pathlib import Path
from databricks.sdk import WorkspaceClient

def main():
    parser = argparse.ArgumentParser(description="Aplica e atualiza a definição do Genie Space do Copiloto de Operações")
    parser.add_argument("--catalog", default="grid_dev", help="Nome do catálogo no Unity Catalog (ex: grid_dev, grid_intelligence)")
    parser.add_argument("--warehouse-id", default="c2d015b31194d84d", help="ID do SQL Warehouse para execução do Genie Space")
    parser.add_argument("--profile", default="grid_intelligence", help="Perfil do Databricks CLI")
    args = parser.parse_args()

    script_dir = Path(__file__).parent
    space_def_path = script_dir / "space_definition.json"

    if not space_def_path.exists():
        print(f"Erro: Arquivo {space_def_path} não encontrado!")
        sys.exit(1)

    with open(space_def_path, "r", encoding="utf-8") as f:
        raw_text = f.read()

    # Substitui o marcador de catálogo pelo valor real (RN-13)
    processed_text = raw_text.replace("${catalogo}", args.catalog)
    space_def = json.loads(processed_text)

    space_title = "Copiloto de Operações — Luz do Vale"
    space_description = "Genie Space inteligente para apoio à diretoria e equipe de operações da Luz do Vale"

    w = WorkspaceClient(profile=args.profile)

    print(f"Verificando se o Genie Space '{space_title}' já existe...")
    spaces_response = w.genie.list_spaces()
    existing_space = None
    if spaces_response and hasattr(spaces_response, "spaces") and spaces_response.spaces:
        for s in spaces_response.spaces:
            if s.title == space_title:
                existing_space = s
                break

    serialized_str = json.dumps(space_def, ensure_ascii=False)

    if existing_space:
        print(f"Atualizando Genie Space existente (ID: {existing_space.space_id})...")
        w.genie.update_space(
            space_id=existing_space.space_id,
            serialized_space=serialized_str,
            title=space_title,
            description=space_description,
            warehouse_id=args.warehouse_id
        )
        space_id = existing_space.space_id
    else:
        print("Criando novo Genie Space...")
        res = w.genie.create_space(
            warehouse_id=args.warehouse_id,
            serialized_space=serialized_str,
            title=space_title,
            description=space_description
        )
        space_id = res.space_id

    print("\n========================================================")
    print("GENIE SPACE APLICADO COM SUCESSO!")
    print(f"Space ID: {space_id}")
    print(f"URL: https://dbc-f17be7d2-b81c.cloud.databricks.com/genie/rooms/{space_id}")
    print("========================================================\n")

if __name__ == "__main__":
    main()
