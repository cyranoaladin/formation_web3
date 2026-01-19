#!/usr/bin/env bash
# Step 026 — docs_fix_contract_canon_minimal (CONTRACT_CANON.md uniquement)
# Objectif: produire un contrat canonique minimal, factuel, testable, aligné avec le dépôt.
# Contraintes: idempotent; modifie uniquement CONTRACT_CANON.md; log PRE/POST SHA + SUMMARY.

set -euo pipefail

TS="$(date +%Y%m%d_%H%M%S)"
LOG_DIR="tools/logs"
LOG_PATH="${LOG_DIR}/docs_fix_contract_canon_${TS}.txt"
mkdir -p "${LOG_DIR}"

FILE="CONTRACT_CANON.md"
PRE_SHA="$(sha256sum "$FILE" 2>/dev/null | awk '{print $1}')"
[[ -z "${PRE_SHA:-}" ]] && PRE_SHA="(absent)"

PYCODE='import os, re, json
from pathlib import Path

root = Path.cwd()
api_main = root/"api"/"app"/"main.py"
models_py = root/"api"/"app"/"models.py"
worker_py = root/"worker"/"worker.py"
compose = root/"docker-compose.yml"

# Components presence
has_api = api_main.exists()
has_worker = worker_py.exists()
has_ui = (root/"ui").exists()
has_rag = (root/"rag").exists()
has_mongo = False

ports = {"api": None, "ui": None}
if compose.exists():
    s = compose.read_text(encoding="utf-8", errors="ignore")
    if "mongo:" in s: has_mongo = True
    # Simple port detection
    for line in s.splitlines():
        line=line.strip()
        if line.startswith("- \"8000:8000\""): ports["api"] = "8000"
        if line.startswith("- \"3000:3000\""): ports["ui"] = "3000"

# Endpoints detection (decorators)
endpoints = []
if has_api:
    s = api_main.read_text(encoding="utf-8", errors="ignore")
    for m in re.finditer(r"@(?:app|router)\.(?:get|post|put|delete|patch)\(\"([^\"]+)\"", s):
        endpoints.append(m.group(1))
endpoints = sorted(set(endpoints))

# States from code
submission_states = set()
run_states = set()
# infer from worker transitions and models
if models_py.exists():
    ms = models_py.read_text(encoding="utf-8", errors="ignore")
    if "SubmissionDoc" in ms:
        # known from flow
        submission_states.update(["queued", "running", "needs_review", "failed"])  # observed in api/worker
    if "AutogradeRunDoc" in ms:
        run_states.update(["queued", "running", "completed"])  # model default + worker updates

# Proof bundle hints
decision_hints = set()
if worker_py.exists():
    ws = worker_py.read_text(encoding="utf-8", errors="ignore")
    if "decision_hint" in ws: decision_hints.add("needs_review")

# Build content
lines = []
lines.append("# Contrat canonique")
lines.append("")
lines.append("## Objectif")
lines.append("- Définir les surfaces contractuelles et les attentes minimales (composants, endpoints, états, invariants) basées sur le dépôt actuel.")
lines.append("")

lines.append("## Composants")
comp = []
if has_api: comp.append("- API (FastAPI)")
if has_worker: comp.append("- Worker (Python)")
if has_ui: comp.append("- UI (Vite/React) — port 3000")
if has_rag: comp.append("- RAG (présence du répertoire rag/)")
if has_mongo: comp.append("- MongoDB")
if not comp: comp.append("- (aucun composant détecté)")
lines.extend(comp)
lines.append("")

lines.append("## Endpoints")
if endpoints:
    for ep in sorted(endpoints):
        lines.append(f"- {ep}")
else:
    lines.append("- (aucun endpoint détecté)")
lines.append("")

lines.append("## Ports")
if ports["api"]: lines.append("- API: " + str(ports["api"]))
if ports["ui"]: lines.append("- UI: " + str(ports["ui"]))
if not (ports["api"] or ports["ui"]): lines.append("- (non détectés)")
lines.append("")

lines.append("## États canoniques")
if submission_states:
    lines.append("- Submission.status: " + ", ".join(sorted(submission_states)))
if run_states:
    lines.append("- AutogradeRun.status: " + ", ".join(sorted(run_states)))
if decision_hints:
    lines.append("- ProofBundle.decision_hint: " + ", ".join(sorted(decision_hints)))
lines.append("")

lines.append("## Invariants")
lines.append("- Chaque soumission possède un submission_id unique")
lines.append("- Chaque run possède un run_id unique")
lines.append("- Un run produit au plus un proof_bundle (lien run.proof_bundle_id)")
lines.append("- Les proof_bundles sont considérés immuables (pas de modification rétroactive)")

content = "\n".join(lines) + "\n"

p = Path("CONTRACT_CANON.md")
old = p.read_text(encoding="utf-8", errors="ignore") if p.exists() else ""
changed = 0
if old != content:
    p.write_text(content, encoding="utf-8")
    changed = 1

print("CHANGED="+str(changed))
print("SUMMARY: components="+", ".join(comp))
print("SUMMARY: endpoints="+(", ".join(endpoints) if endpoints else "none"))
print("SUMMARY: ports=api:"+str(ports["api"])+", ui:"+str(ports["ui"]))
print("SUMMARY: states=submissions:"+", ".join(sorted(submission_states))+" | runs:"+", ".join(sorted(run_states)))
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
  echo "--- PY_SUMMARY ---"
  echo "$PY_OUT" | sed -n '2,12p'
} >"$LOG_PATH"

echo "LOG_PATH=${LOG_PATH}"