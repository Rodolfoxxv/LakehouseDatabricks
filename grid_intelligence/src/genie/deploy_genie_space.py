import argparse
import json
import os
import subprocess
import sys
from pathlib import Path

def main():
    parser = argparse.ArgumentParser(description="Implanta/Atualiza o Genie Space do Copiloto de Operações no Databricks")
    parser.add_argument("--catalog", default="grid_dev", help="Nome do catálogo Unity Catalog (ex: grid_dev, grid_intelligence)")
    parser.add_argument("--warehouse-id", default="c2d015b31194d84d", help="ID do SQL Warehouse para o Genie Space")
    parser.add_argument("--profile", default="grid_intelligence", help="Perfil do Databricks CLI")
    args = parser.parse_args()

    script_dir = Path(__file__).parent
    agent_file = script_dir / "grid_agent.json"

    if not agent_file.exists():
        agent_file = script_dir / "space_definition.json"

    if not agent_file.exists():
        print(f"Erro: Nenhum arquivo de definição encontrado em {script_dir}")
        sys.exit(1)

    with open(agent_file, "r", encoding="utf-8") as f:
        raw_content = f.read()

    # Substitui a variável ${catalogo} pelo valor fornecido (RN-13)
    processed_content = raw_content.replace("${catalogo}", args.catalog)
    space_def = json.loads(processed_content)

    title = "Copiloto de Operações — Luz do Vale"
    description = "Genie Space inteligente para apoio à diretoria e equipe de operações da Luz do Vale"

    payload = {
        "title": title,
        "description": description,
        "warehouse_id": args.warehouse_id,
        "serialized_space": json.dumps(space_def, ensure_ascii=False)
    }

    temp_payload = script_dir / "_deploy_payload.json"
    with open(temp_payload, "w", encoding="utf-8") as f:
        json.dump(payload, f, ensure_ascii=False)

    print(f"Verificando se o Genie Space '{title}' ja existe no Databricks...")
    list_cmd = ["databricks", "genie", "list-spaces", "--profile", args.profile, "-o", "json"]
    list_res = subprocess.run(list_cmd, capture_output=True, text=True, encoding="utf-8", errors="replace")

    existing_space_id = None
    if list_res.returncode == 0 and list_res.stdout and list_res.stdout.strip():
        try:
            data = json.loads(list_res.stdout)
            spaces = data.get("spaces", [])
            for s in spaces:
                if s.get("title") == title:
                    existing_space_id = s.get("space_id")
                    break
        except Exception as e:
            print("Aviso ao analisar lista de spaces:", e)

    if existing_space_id:
        print(f"Atualizando Genie Space existente (ID: {existing_space_id})...")
        update_cmd = [
            "databricks", "genie", "update-space", existing_space_id,
            "--serialized-space", json.dumps(space_def, ensure_ascii=False),
            "--profile", args.profile
        ]
        res = subprocess.run(update_cmd, capture_output=True, text=True, encoding="utf-8", errors="replace")
        space_id = existing_space_id
    else:
        print("Criando novo Genie Space...")
        create_cmd = [
            "databricks", "genie", "create-space",
            "--json", f"@{temp_payload}",
            "--profile", args.profile,
            "-o", "json"
        ]
        res = subprocess.run(create_cmd, capture_output=True, text=True, encoding="utf-8", errors="replace")
        space_id = None
        if res.returncode == 0 and res.stdout and res.stdout.strip():
            try:
                res_json = json.loads(res.stdout)
                space_id = res_json.get("space_id")
            except Exception:
                pass

    if temp_payload.exists():
        os.remove(temp_payload)

    if res.returncode == 0:
        print("\n========================================================")
        print("GENIE SPACE IMPLANTADO COM SUCESSO!")
        if space_id:
            print(f"Space ID: {space_id}")
            print(f"URL: https://dbc-f17be7d2-b81c.cloud.databricks.com/genie/rooms/{space_id}")
        print("========================================================\n")
    else:
        print("[ERRO] Falha ao implantar Genie Space:")
        print("STDOUT:", res.stdout)
        print("STDERR:", res.stderr)
        sys.exit(1)

if __name__ == "__main__":
    main()
