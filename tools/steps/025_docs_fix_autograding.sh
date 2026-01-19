#!/usr/bin/env bash
# Step 025 — docs_fix_autograding_minimal (AUTOGRADING.md uniquement)
# Objectif: Remplacer le contenu placeholder par une doc minimale, factuelle et testable.
# Contraintes: idempotent; ne modifie que AUTOGRADING.md; log avec PRE/POST SHA et SUMMARY.

set -euo pipefail

TS="$(date +%Y%m%d_%H%M%S)"
LOG_DIR="tools/logs"
LOG_PATH="${LOG_DIR}/docs_fix_autograding_${TS}.txt"
mkdir -p "${LOG_DIR}"

FILE="AUTOGRADING.md"
PRE_SHA="$(sha256sum "$FILE" 2>/dev/null | awk '{print $1}')"
[[ -z "${PRE_SHA:-}" ]] && PRE_SHA="(absent)"

# Construire le contenu dans Python (-c), en s'appuyant uniquement sur des faits observables.
# - Détecte FastAPI, endpoints, worker et champs proof_bundle/score_auto/decision_hint
# - Génère un contenu canonique et n'écrit que si différent (idempotent)
PYCODE='import os, re, json, hashlib, sys
from pathlib import Path

root = Path.cwd()
api_main = root/"api"/"app"/"main.py"
worker_py = root/"worker"/"worker.py"
compose = root/"docker-compose.yml"

# Faits
fastapi = False
endpoints = []
if api_main.exists():
    s = api_main.read_text(encoding="utf-8", errors="ignore")
    fastapi = ("FastAPI(" in s) or ("from fastapi" in s)
    for m in re.finditer(r"@(?:app|router)\.(?:get|post|put|delete|patch)\(\"([^\"]+)\"", s):
        endpoints.append(m.group(1))
endpoints = sorted(set(endpoints))

worker_present = worker_py.exists()
proof_bundle = score_auto = decision_hint = False
if worker_present:
    ws = worker_py.read_text(encoding="utf-8", errors="ignore")
    proof_bundle = ("proof_bundle_id" in ws)
    score_auto = ("score_auto" in ws)
    decision_hint = ("decision_hint" in ws)

smoke_step = (root/"tools"/"steps"/"003_smoke_e2e.sh").exists()
mongo_in_api = api_main.exists() and ("MONGODB_URI" in api_main.read_text(encoding="utf-8", errors="ignore"))
mongo_in_worker = worker_present and ("MONGODB_URI" in ws)

# Filtrer endpoints intéressants
keep = []
for ep in endpoints:
    if ep in ("/health", "/submissions/upload_zip") or ep.startswith("/runs/") or ep.startswith("/submissions/"):
        keep.append(ep)
endpoints = sorted(set(keep))

# Construire le contenu
lines = []
lines.append("# Autograding")
lines.append("")
lines.append("## Objectif")
lines.append("- L’autograder RBK évalue une soumission, produit un run et un proof_bundle, et met à jour le statut.")
lines.append("")
lines.append("## Entrées")
entr = ["- Soumission: archive ZIP via POST /submissions/upload_zip (form-data: student_id, lab_id, file)"]
if any(ep.startswith("/submissions/") for ep in endpoints):
    entr.append("- Identifiants renvoyés: submission_id, upload_id (statut initial: queued)")
lines.extend(entr)
lines.append("")
lines.append("## Sorties")
out = []
if proof_bundle: out.append("- proof_bundle_id (créé par le worker)")
if score_auto: out.append("- score_auto (placeholder)")
if decision_hint: out.append("- decision_hint (ex: needs_review)")
out.append("- run_id (run d’autograde lié à la soumission)")
lines.extend(out)
lines.append("")
lines.append("## Composants")
comp = []
if fastapi:
    eps = ", ".join(endpoints) if endpoints else "(endpoints non détectés)"
    comp.append(f"- API (FastAPI) : endpoints confirmés: {eps}")
else:
    comp.append("- API : (implémentation non détectée)")
if worker_present:
    comp.append("- Worker (Python) : boucle de traitement queued -> running -> needs_review/failed + création run et proof_bundle")
else:
    comp.append("- Worker : (absent)")
# Runner (placeholder)
comp.append("- Runner : placeholder (aucune exécution isolée confirmée)")
if mongo_in_api or mongo_in_worker:
    comp.append("- MongoDB : persistance des submissions, runs et proof_bundles")
lines.extend(comp)
lines.append("")
lines.append("## Exécution locale (reproductible)")
lines.append("```bash")
lines.append("docker compose up -d --build")
lines.append("docker compose ps")
lines.append("```")
lines.append("")
lines.append("## Vérification (preuves)")
lines.append("- Santé API :")
lines.append("```bash")
lines.append("curl -sS http://localhost:8000/health")
lines.append("```")
if smoke_step:
    lines.append("- Démo de bout en bout (smoke) :")
    lines.append("```bash")
    lines.append("bash tools/run.sh tools/steps/003_smoke_e2e.sh")
    lines.append("```")
else:
    lines.append("- Vérifier le worker :")
    lines.append("```bash")
    lines.append("docker compose ps")
    lines.append("docker compose logs --tail=100 worker")
    lines.append("```")
lines.append("")
lines.append("## Notes / limites")
notes = []
notes.append("- Le runner est actuellement un placeholder (runner.kind=\"placeholder\"); les tests sont simulés.")
if score_auto:
    notes.append("- Le score_auto renvoyé par le worker est un exemple (50) et sert de valeur de démonstration.")
lines.extend(notes)

content = "\n".join(lines) + "\n"

# Idempotence: écrire seulement si différent
p = Path("AUTOGRADING.md")
old = p.read_text(encoding="utf-8", errors="ignore") if p.exists() else ""
if old != content:
    p.write_text(content, encoding="utf-8")
    print("CHANGED=1")
else:
    print("CHANGED=0")

# Afficher un petit résumé (5-10 lignes)
summary = []
summary.append("SUMMARY: endpoints=" + (", ".join(endpoints) if endpoints else "none"))
summary.append("SUMMARY: fastapi=" + str(fastapi))
summary.append("SUMMARY: worker_present=" + str(worker_present))
summary.append("SUMMARY: outputs=" + ",".join([x for x in ["run_id", "proof_bundle_id" if proof_bundle else None, "score_auto" if score_auto else None, "decision_hint" if decision_hint else None] if x]))
summary.append("SUMMARY: smoke_step=" + str(smoke_step))
print("\n".join(summary))
'

PY_OUT="$(python3 -c "$PYCODE")"
CHANGED=$(echo "$PY_OUT" | awk -F= '/^CHANGED=/{print $2; exit}' )
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

# Emit path for runner log
echo "LOG_PATH=${LOG_PATH}"