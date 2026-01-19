#!/usr/bin/env bash
# Step 028 — docs_fix_labs_minimal (LABS.md uniquement)
# Objectif: Index factuel des labs réellement présents. Idempotent. Aucune spéculation.

set -euo pipefail

TS="$(date +%Y%m%d_%H%M%S)"
LOG_DIR="tools/logs"
LOG_PATH="${LOG_DIR}/docs_fix_labs_${TS}.txt"
mkdir -p "${LOG_DIR}"

FILE="LABS.md"
PRE_SHA="$(sha256sum "$FILE" 2>/dev/null | awk '{print $1}')"
[[ -z "${PRE_SHA:-}" ]] && PRE_SHA="(absent)"

PYCODE='import os, json
from pathlib import Path

root = Path.cwd()
file = Path("LABS.md")

labs_dir = root/"labs"
pipes_dir = root/"pipelines"
verify_sh = root/"tools"/"verify.sh"
verify_spec = root/"tools"/"verify.spec"
worker_py = root/"worker"/"worker.py"

labs = []
if labs_dir.exists():
    for p in sorted(labs_dir.iterdir()):
        if p.is_dir():
            labs.append(p.name)

pipelines = []
if pipes_dir.exists():
    for p in sorted(pipes_dir.iterdir()):
        pipelines.append(p.name)

has_verify = verify_sh.exists() and verify_spec.exists()
runner_placeholder = False
if worker_py.exists():
    s = worker_py.read_text(encoding="utf-8", errors="ignore")
    runner_placeholder = ("\"kind\": \"placeholder\"" in s) or ("runner" in s)

lines = []
lines.append("# Labs")
lines.append("")
lines.append("## Objectif")
lines.append("- Les labs sont des unités d’évaluation exécutables, évaluées par l’autograding.")
lines.append("- Les exécutions produisent un run et un proof_bundle (preuves) associés aux soumissions.")
lines.append("")

lines.append("## Inventaire des labs")
if labs:
    for name in labs:
        lines.append(f"- labs/{name}/")
else:
    lines.append("- aucun lab implémenté à ce stade")
if pipelines:
    for name in pipelines:
        lines.append(f"- pipelines/{name}")
lines.append("")

lines.append("## Structure d’un lab")
lines.append("- spec (YAML/JSON si présent)")
lines.append("- assets (si présents)")
lines.append("- scripts d’exécution (si présents)")
lines.append("- sorties attendues: proof_bundle (logs/tests/diff/audit)")
lines.append("")

lines.append("## Cycle d’exécution")
lines.append("- upload_zip → queued → worker → run → proof_bundle")
lines.append("")

lines.append("## Vérification (preuves)")
if has_verify:
    lines.append("```bash")
    lines.append("bash tools/verify.sh --spec tools/verify.spec")
    lines.append("```")
else:
    lines.append("- (verify.sh non présent)")
lines.append("")

lines.append("## Limites actuelles")
if runner_placeholder:
    lines.append("- Runner en mode placeholder (isolement fort non garanti)")
if not labs:
    lines.append("- Labs partiellement implémentés (inventaire vide)")
if not runner_placeholder and labs:
    lines.append("- Implémentation des runners à confirmer lab par lab")

content = "\n".join(lines) + "\n"

old = file.read_text(encoding="utf-8", errors="ignore") if file.exists() else ""
changed = 0
if old != content:
    file.write_text(content, encoding="utf-8")
    changed = 1

print(json.dumps({
  "CHANGED": changed,
  "labs": labs,
  "pipelines": pipelines,
  "has_verify": has_verify,
  "runner_placeholder": runner_placeholder
}))
'

PY_OUT="$(python3 -c "$PYCODE")"
CHANGED=$(echo "$PY_OUT" | python3 -c 'import sys,json; print(json.load(sys.stdin)["CHANGED"])')
LABS_LIST=$(echo "$PY_OUT" | python3 -c 'import sys,json; print(" ".join(json.load(sys.stdin)["labs"]))')
PIPES_LIST=$(echo "$PY_OUT" | python3 -c 'import sys,json; print(" ".join(json.load(sys.stdin)["pipelines"]))')
POST_SHA="$(sha256sum "$FILE" 2>/dev/null | awk '{print $1}')"

{
  echo "FILE=$FILE"
  echo "PRE_SHA256=$PRE_SHA"
  echo "POST_SHA256=$POST_SHA"
  echo "CHANGED=$CHANGED"
  echo "SOURCES: labs/=$( [ -d labs ] && echo yes || echo no ), pipelines/=$( [ -d pipelines ] && echo yes || echo no )"
  echo "INVENTORY: labs=[${LABS_LIST}] pipelines=[${PIPES_LIST}]"
} >"$LOG_PATH"

echo "LOG_PATH=${LOG_PATH}"