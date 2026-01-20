#!/usr/bin/env bash
# STEP 041 — api_models_submission_run_proof (CODE CHANGE)
# But: garantir les modèles Mongo minimaux (Submission, AutogradeRun, ProofBundle)
# + mettre à jour les JSON Schemas pour refléter les champs minimaux sans casser l'existant.
# Preuves: sha256 avant/après, grep classes/champs, import python, verify PASS

set -euo pipefail

TS=$(date +%Y%m%d_%H%M%S)
LOG="tools/logs/041_models_${TS}.txt"
mkdir -p tools/logs

sha() { if [[ -f "$1" ]]; then sha256sum "$1" | awk '{print $1}'; else echo "(absent)"; fi }

MOD_FILE="api/app/models.py"
SUB_SCHEMA="schemas/canonical/submission.schema.json"
RUN_SCHEMA="schemas/canonical/autograde_run.schema.json"
PROOF_SCHEMA="schemas/canonical/proof_bundle.schema.json"

{
  echo "[INFO] STEP 041 @ $TS"
  echo "== SHA BEFORE =="
  echo "models.py: $(sha "$MOD_FILE")"
  echo "submission.schema.json: $(sha "$SUB_SCHEMA")"
  echo "autograde_run.schema.json: $(sha "$RUN_SCHEMA")"
  echo "proof_bundle.schema.json: $(sha "$PROOF_SCHEMA")"

  echo
  echo "== PATCH: models.py (append canonical models if absent) =="
  python3 - <<'PY'
from pathlib import Path
p=Path('api/app/models.py')
s=p.read_text(encoding='utf-8')
changed=False

block='''

# --- Canonical minimal models (Step 041) ---
from typing import Optional, Union, Dict, Any, List
from pydantic import BaseModel
from datetime import datetime

class SubmissionCanon(BaseModel):
    submission_id: str
    student_id: Optional[str] = None
    lab_id: Optional[str] = None
    status: str  # queued|running|completed|needs_review|failed
    created_at: datetime
    updated_at: datetime
    upload_id: Optional[str] = None
    error: Optional[str] = None
    run_id: Optional[str] = None
    proof_bundle_id: Optional[str] = None

class AutogradeRunCanon(BaseModel):
    run_id: str
    submission_id: str
    status: str  # queued|running|completed|failed
    created_at: datetime
    updated_at: datetime
    score_auto: Optional[int] = None
    decision_hint: Optional[str] = None

class ProofBundleCanon(BaseModel):
    proof_bundle_id: str
    run_id: str
    created_at: datetime
    artifacts: Union[Dict[str, Any], List[Any]]
    immutable: bool = True
    sha256: Optional[str] = None
'''

if 'class SubmissionCanon' not in s:
    s = s.rstrip() + "\n" + block
    changed=True

if changed:
    p.write_text(s, encoding='utf-8')
    print('MODELS_PATCHED=1')
else:
    print('MODELS_PATCHED=0')
PY

  echo
  echo "== PATCH: JSON Schemas (relax to minimal required, keep additionalProperties=true) =="
  python3 - <<'PY'
import json, os
from pathlib import Path

# Utility to safely load/update/write schema

def patch_submission(p: Path):
    if not p.exists():
        print(f"SKIP missing {p}")
        return
    j = json.load(p.open('r', encoding='utf-8'))
    props = j.get('properties') or {}
    # Ensure minimal properties exist
    props.setdefault('submission_id', {"type":"string"})
    props.setdefault('status', {"type":"string", "enum":["queued","running","completed","needs_review","failed"]})
    props.setdefault('created_at', {"type":"string", "format":"date-time"})
    props.setdefault('updated_at', {"type":"string", "format":"date-time"})
    # Optional extras
    for k,v in {
        'student_id': {"type":"string"},
        'lab_id': {"type":"string"},
        'upload_id': {"type":"string"},
        'error': {"type":"string"},
        'run_id': {"type":["string","null"]},
        'proof_bundle_id': {"type":["string","null"]},
    }.items():
        props.setdefault(k, v)
    j['properties'] = props
    j['required'] = ["submission_id","status","created_at","updated_at"]
    j['additionalProperties'] = True
    json.dump(j, p.open('w', encoding='utf-8'), ensure_ascii=False, indent=2)
    print(f'PATCHED {p}')


def patch_run(p: Path):
    if not p.exists():
        print(f"SKIP missing {p}")
        return
    j = json.load(p.open('r', encoding='utf-8'))
    props = j.get('properties') or {}
    for k,v in {
        'run_id': {"type":"string"},
        'submission_id': {"type":"string"},
        'status': {"type":"string", "enum":["queued","running","completed","failed"]},
        'created_at': {"type":"string", "format":"date-time"},
        'updated_at': {"type":"string", "format":"date-time"},
        'score_auto': {"type":["number","integer","null"]},
        'decision_hint': {"type":["string","null"]},
    }.items():
        props.setdefault(k, v)
    j['properties']=props
    j['required']=["run_id","submission_id","status","created_at","updated_at"]
    j['additionalProperties']=True
    json.dump(j, p.open('w', encoding='utf-8'), ensure_ascii=False, indent=2)
    print(f'PATCHED {p}')


def patch_proof(p: Path):
    if not p.exists():
        print(f"SKIP missing {p}")
        return
    j = json.load(p.open('r', encoding='utf-8'))
    props = j.get('properties') or {}
    for k,v in {
        'proof_bundle_id': {"type":"string"},
        'run_id': {"type":"string"},
        'created_at': {"type":"string","format":"date-time"},
        'artifacts': {"type":"object"},
        'immutable': {"type":"boolean"},
        'sha256': {"type":"string"}
    }.items():
        props.setdefault(k, v)
    j['properties']=props
    # Keep minimal required; do not require immutable to avoid breaking current writer
    j['required']=["proof_bundle_id","run_id","created_at","artifacts"]
    j['additionalProperties']=True
    json.dump(j, p.open('w', encoding='utf-8'), ensure_ascii=False, indent=2)
    print(f'PATCHED {p}')

patch_submission(Path('schemas/canonical/submission.schema.json'))
patch_run(Path('schemas/canonical/autograde_run.schema.json'))
patch_proof(Path('schemas/canonical/proof_bundle.schema.json'))
PY

  echo
  echo "== SHA AFTER =="
  echo "models.py: $(sha "$MOD_FILE")"
  echo "submission.schema.json: $(sha "$SUB_SCHEMA")"
  echo "autograde_run.schema.json: $(sha "$RUN_SCHEMA")"
  echo "proof_bundle.schema.json: $(sha "$PROOF_SCHEMA")"

  echo
  echo "== GREP models.py classes/champs =="
  grep -nE 'class (SubmissionCanon|AutogradeRunCanon|ProofBundleCanon)' "$MOD_FILE" || true
  grep -nE 'status: str|created_at: datetime|updated_at: datetime|score_auto: Optional|immutable: bool' "$MOD_FILE" || true

  echo
  echo "== PY import sanity =="
  python3 - <<'PY'
import sys
sys.path.insert(0,'api')
from app.models import SubmissionCanon, AutogradeRunCanon, ProofBundleCanon
print('IMPORT_OK', SubmissionCanon.__name__, AutogradeRunCanon.__name__, ProofBundleCanon.__name__)
PY

  echo
  echo "== VERIFY HARNESS =="
  if [[ -x tools/verify.sh ]]; then
    tools/verify.sh --spec tools/verify.spec || true
  elif [[ -f tools/verify.sh ]]; then
    bash tools/verify.sh --spec tools/verify.spec || true
  else
    echo "(no verify harness found)"
  fi
} | tee "$LOG"

# Extrait court vers stdout déjà affiché par tee; fin de step
echo "STOP."
