#!/usr/bin/env bash
# Step 029 — docs_fix_matrice_competences_minimal (MATRICE_COMPETENCES.md uniquement)
# Objectif: matrice opérationnelle, factuelle, observable et testable. Idempotent.

set -euo pipefail

TS="$(date +%Y%m%d_%H%M%S)"
LOG_DIR="tools/logs"
LOG_PATH="${LOG_DIR}/docs_fix_matrice_comp_${TS}.txt"
mkdir -p "${LOG_DIR}"

FILE="MATRICE_COMPETENCES.md"
PRE_SHA="$(sha256sum "$FILE" 2>/dev/null | awk '{print $1}')"
[[ -z "${PRE_SHA:-}" ]] && PRE_SHA="(absent)"

PYCODE='import os, re
from pathlib import Path

root = Path.cwd()
api_main = root/"api"/"app"/"main.py"
worker_py = root/"worker"/"worker.py"
verify_sh = root/"tools"/"verify.sh"
verify_spec = root/"tools"/"verify.spec"
compose = root/"docker-compose.yml"
smoke_step = root/"tools"/"steps"/"003_smoke_e2e.sh"
rag_dir = root/"rag"
labs_dir = root/"labs"

has_health = False
endpoints = []
if api_main.exists():
    s = api_main.read_text(encoding="utf-8", errors="ignore")
    has_health = "\"/health\"" in s
    for m in re.finditer(r"@(?:app|router)\.(?:get|post|put|delete|patch)\(\"([^\"]+)\"", s):
        endpoints.append(m.group(1))
endpoints = sorted(set(endpoints))

has_verify = verify_sh.exists() and verify_spec.exists()
has_compose = compose.exists()
has_smoke = smoke_step.exists()
has_worker = worker_py.exists()
has_rag = rag_dir.exists()
has_labs = labs_dir.exists()

runner_placeholder = False
if has_worker:
    ws = worker_py.read_text(encoding="utf-8", errors="ignore")
    runner_placeholder = ("\"kind\": \"placeholder\"" in ws)

# Build minimal, observable, testable matrix
lines = []
lines.append("# Matrice de compétences")
lines.append("")
lines.append("## Principes")
lines.append("- Compétences observables (liées à des artefacts/commandes du dépôt)")
lines.append("- Preuves exigées (logs, proof_bundle, endpoints fonctionnels, verify PASS)")
lines.append("- Progression par paliers (Junior → Intermediate → Senior)")
lines.append("")

lines.append("## Niveaux")
lines.append("- Junior")
lines.append("- Intermediate")
lines.append("- Senior")
lines.append("")

lines.append("## Domaines")
lines.append("- Architecture")
lines.append("- API")
lines.append("- Worker / Autograding")
lines.append("- RAG")
lines.append("- DevOps / Exécution")
lines.append("- Documentation & preuves")
lines.append("")

lines.append("## Matrice (listes structurées)")

# Helper to add a block per level/domain with competence + proof

def add_block(level, domain, competence, proof):
    lines.append(f"### {level} — {domain}")
    lines.append(f"- compétence: {competence}")
    lines.append(f"- preuve attendue: {proof}")
    lines.append("")

# Architecture
add_block("Junior", "Architecture", "Comprendre les composants présents (API, Worker, UI, Mongo) et les ports exposés", "docker compose ps (si présent) ; lecture docker-compose.yml")
add_block("Intermediate", "Architecture", "Tracer le flux upload_zip → queued → run → proof_bundle", "exécution de smoke (si disponible) ou lecture des logs worker")
add_block("Senior", "Architecture", "Valider les invariants CONTRACT_CANON (IDs uniques, 1 run → ≤1 proof_bundle)", "preuve par lecture des documents et/ou sortie de 003_smoke_e2e.sh")

# API
api_proof = "curl -sS http://localhost:8000/health" if has_health else "(endpoint /health non détecté)"
add_block("Junior", "API", "Tester la santé de l’API", api_proof)
add_block("Intermediate", "API", "Décrire les endpoints détectés", ", ".join(endpoints) if endpoints else "(aucun endpoint détecté par scan)")
add_block("Senior", "API", "Diagnostiquer un échec d’upload_zip (statuts/erreurs)", "lecture api/app/main.py + reproduction contrôlée")

# Worker / Autograding
proof_smoke = "bash tools/run.sh tools/steps/003_smoke_e2e.sh" if has_smoke else "(smoke step absent)"
add_block("Junior", "Worker / Autograding", "Expliquer les statuts queued/running/needs_review", "lecture worker/worker.py")
add_block("Intermediate", "Worker / Autograding", "Produire un run et observer proof_bundle", proof_smoke)
wb = "runner.kind=placeholder" if runner_placeholder else "runner: implémentation à vérifier"
add_block("Senior", "Worker / Autograding", "Qualifier le runner et les artefacts de preuve", wb)

# RAG
rag_comp = "Identifier la présence du répertoire rag/ et l’état des fonctionnalités" if has_rag else "(répertoire rag/ absent)"
rag_proof = "ls -la rag/" if has_rag else "N/A"
add_block("Junior", "RAG", rag_comp, rag_proof)
add_block("Intermediate", "RAG", "Cartographier ce qui est documenté dans RAG.md", "lecture RAG.md (aucun endpoint confirmé dans le code API)")
add_block("Senior", "RAG", "Aligner RAG avec les invariants (sans promesse d’endpoint)", "revue croisée docs ↔ code")

# DevOps / Exécution
ver_cmd = "bash tools/verify.sh --spec tools/verify.spec" if has_verify else "(verify.sh/spec absents)"
compose_cmd = "docker compose up -d --build" if has_compose else "(docker-compose.yml absent)"
add_block("Junior", "DevOps / Exécution", "Lancer l’environnement local", compose_cmd)
add_block("Intermediate", "DevOps / Exécution", "Vérifier les invariants minimaux", ver_cmd)
add_block("Senior", "DevOps / Exécution", "Collecter des logs ciblés pour diagnostic", "docker compose logs --tail=100 worker")

# Documentation & preuves
add_block("Junior", "Documentation & preuves", "Ajouter une section minimale factuelle dans un .md", "grep structure + sha256 avant/après")
add_block("Intermediate", "Documentation & preuves", "Écrire un step atomique idempotent sous tools/steps/", "bash tools/run.sh tools/steps/<step>.sh + preuves")
add_block("Senior", "Documentation & preuves", "Définir des critères de validation et arrêter après preuves", "verify PASS + logs de step")

content = "\n".join(lines) + "\n"

p = Path("MATRICE_COMPETENCES.md")
old = p.read_text(encoding="utf-8", errors="ignore") if p.exists() else ""
changed = 0
if old != content:
    p.write_text(content, encoding="utf-8")
    changed = 1

print(f"CHANGED={changed}")
'

PY_OUT="$(python3 -c "$PYCODE")"
CHANGED=$(echo "$PY_OUT" | awk -F= '/^CHANGED=/{print $2; exit}')
[[ -z "${CHANGED}" ]] && CHANGED=0
POST_SHA="$(sha256sum "$FILE" 2>/dev/null | awk '{print $1}')"

{
  echo "FILE=$FILE"
  echo "PRE_SHA256=$PRE_SHA"
  echo "POST_SHA256=$POST_SHA"
  echo "CHANGED=$CHANGED"
} >"$LOG_PATH"

echo "LOG_PATH=${LOG_PATH}"