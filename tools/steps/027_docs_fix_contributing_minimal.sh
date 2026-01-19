#!/usr/bin/env bash
# Step 027 — docs_fix_contributing_minimal (CONTRIBUTING.md uniquement)
# Objectif: produire une contribution guide minimal, factuel, idempotent.
# Contraintes: ne modifie que CONTRIBUTING.md; log PRE/POST SHA + CHANGED; exécution via tools/run.sh.

set -euo pipefail

TS="$(date +%Y%m%d_%H%M%S)"
LOG_DIR="tools/logs"
LOG_PATH="${LOG_DIR}/docs_fix_contributing_${TS}.txt"
mkdir -p "${LOG_DIR}"

FILE="CONTRIBUTING.md"
PRE_SHA="$(sha256sum "$FILE" 2>/dev/null | awk '{print $1}')"
[[ -z "${PRE_SHA:-}" ]] && PRE_SHA="(absent)"

PYCODE='import os, sys
from pathlib import Path

root = Path.cwd()
file = Path("CONTRIBUTING.md")

has_compose = (root/"docker-compose.yml").exists()
has_verify = (root/"tools"/"verify.sh").exists() and (root/"tools"/"verify.spec").exists()
api_main = root/"api"/"app"/"main.py"
has_health = False
if api_main.exists():
    s = api_main.read_text(encoding="utf-8", errors="ignore")
    has_health = "\"/health\"" in s

lines = []
lines.append("# Contributing")
lines.append("")
lines.append("## Scope")
lines.append("- Ce dépôt RBK Labs accepte des contributions sur la documentation, les scripts et le code.")
lines.append("")
lines.append("## Workflow (atomic steps + proofs)")
lines.append("- Chaque changement est implémenté via un step atomique sous tools/steps/.")
lines.append("- Exécuter un step avec le runner et STOP après preuves:")
lines.append("```bash")
lines.append("bash tools/run.sh tools/steps/<step>.sh")
lines.append("```")
lines.append("")
lines.append("## Local verification")
lines.append("- Vérifier localement avant toute PR:")
lines.append("```bash")
if has_verify:
    lines.append("bash tools/verify.sh --spec tools/verify.spec")
if has_compose:
    lines.append("docker compose up -d --build")
if has_health:
    lines.append("curl -sS http://localhost:8000/health")
lines.append("```")
lines.append("")
lines.append("## Branches")
lines.append("- Utilisez des branches courtes: feat/<topic>, fix/<topic>, docs/<topic>, chore/<topic>.")
lines.append("")
lines.append("## Commits")
lines.append("- Message clair, court, à l’impératif. Pas de convention imposée.")
lines.append("- La ligne Co-Authored-By est optionnelle (si pertinent).")
lines.append("")
lines.append("## Pull request")
lines.append("- Checklist minimale:")
lines.append("  - verify PASS")
lines.append("  - preuves incluses (extraits de logs, greps)")
lines.append("  - pas de changements hors scope")

content = "\n".join(lines) + "\n"
old = file.read_text(encoding="utf-8", errors="ignore") if file.exists() else ""
if old != content:
    file.write_text(content, encoding="utf-8")
    print("CHANGED=1")
else:
    print("CHANGED=0")
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