#!/usr/bin/env bash
# STEP 046 — labs_hello_proof_minimal (CODE CHANGE)
# But: créer/patcher un 1er lab réel, déterministe, sans dépendances externes
# - labs/specs/hello-proof/lab.json : ajouter "command" + "expected_artifacts"
# Preuves: sha256 avant/après, ls/cat extrait, validation JSON, verify PASS

set -euo pipefail

TS=$(date +%Y%m%d_%H%M%S)
LOG="tools/logs/046_labs_hello_${TS}.txt"
mkdir -p tools/logs

sha() { if [[ -f "$1" ]]; then sha256sum "$1" | awk '{print $1}'; else echo "(absent)"; fi }

SPEC_DIR="labs/specs/hello-proof"
SPEC_FILE="${SPEC_DIR}/lab.json"

{
  echo "[INFO] STEP 046 @ ${TS}"
  echo "== SHA BEFORE =="
  echo "${SPEC_FILE}: $(sha "$SPEC_FILE")"

  echo
  echo "== PATCH lab spec =="
  mkdir -p "$SPEC_DIR"
  python3 - <<'PY'
from pathlib import Path
import json
p=Path('labs/specs/hello-proof/lab.json')
if p.exists():
    j=json.load(p.open('r',encoding='utf-8'))
else:
    j={"lab_id":"hello-proof","title":"Hello Proof","version":"0.1.0","visibility":"public","rubric":"placeholder"}
# Deterministic command: echo marker + file count inside unzipped work dir
j.setdefault('command', "sh -lc 'echo HELLO_PROOF && echo files=$(find . -type f | wc -l)'")
j.setdefault('expected_artifacts', ["logs.txt","result.json"])
# Preserve other fields
p.write_text(json.dumps(j, ensure_ascii=False, indent=2), encoding='utf-8')
print('LAB_SPEC_PATCHED=1')
PY

  echo
  echo "== SHA AFTER =="
  echo "${SPEC_FILE}: $(sha "$SPEC_FILE")"

  echo
  echo "== LIST labs/specs =="
  find labs/specs -maxdepth 2 -type f -name 'lab.json' -printf '%p\n' | sort | sed -n '1,200p'

  echo
  echo "== CAT spec excerpt =="
  sed -n '1,80p' "$SPEC_FILE"

  echo
  echo "== Validate JSON (python -m json.tool) =="
  python3 -m json.tool "$SPEC_FILE" >/dev/null && echo VALID_JSON=1

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

echo "STOP."