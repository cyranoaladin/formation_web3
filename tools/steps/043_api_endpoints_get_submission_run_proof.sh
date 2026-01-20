#!/usr/bin/env bash
# STEP 043 — api_endpoints_get_submission_run_proof (CODE CHANGE)
# But: exposer endpoints de lecture: GET /submissions/{id}, /runs/{id}, /proofs/{id}
# Action: ajouter GET /proofs/{proof_bundle_id} si absent; prouver avec un upload + polling
# Preuves: sha before/after, grep routes, curl HTTP codes + JSON, verify PASS

set -euo pipefail

TS=$(date +%Y%m%d_%H%M%S)
LOG="tools/logs/043_get_endpoints_${TS}.txt"
mkdir -p tools/logs

sha() { if [[ -f "$1" ]]; then sha256sum "$1" | awk '{print $1}'; else echo "(absent)"; fi }

API_MAIN="api/app/main.py"
FIXTURE="tests/fixtures/minimal.zip"

{
  echo "[INFO] STEP 043 @ ${TS}"
  echo "== SHA BEFORE =="
  echo "main.py: $(sha "$API_MAIN")"

  echo
  echo "== PATCH: add GET /proofs/{proof_bundle_id} if missing =="
  python3 - <<'PY'
from pathlib import Path
p=Path('api/app/main.py')
s=p.read_text(encoding='utf-8')
changed=False
if '@app.get("/proofs/{proof_bundle_id}")' not in s:
    block='''\n\n@app.get("/proofs/{proof_bundle_id}")\ndef get_proof(proof_bundle_id: str):\n    db = get_db()\n    doc = db.proof_bundles.find_one({"proof_bundle_id": proof_bundle_id}, {"_id": 0})\n    if not doc:\n        raise HTTPException(status_code=404, detail="proof_not_found")\n    return doc\n'''
    s = s + block
    p.write_text(s, encoding='utf-8')
    print('API_PROOFS_ENDPOINT_ADDED=1')
else:
    print('API_PROOFS_ENDPOINT_ADDED=0')
PY

  echo
  echo "== SHA AFTER =="
  echo "main.py: $(sha "$API_MAIN")"

  echo
  echo "== GREP routes =="
  grep -nE '@app.get\("/submissions/\{.*\}\)|@app.get\("/runs/\{.*\}\)|@app.get\("/proofs/\{.*\}\)' "$API_MAIN" || true

  echo
  echo "== docker compose up -d --build api worker mongo =="
  docker compose up -d --build mongo api worker
  docker compose ps || true

  echo
  echo "== wait for API /health =="
  for i in $(seq 1 30); do
    if curl -sSf http://localhost:8000/health >/dev/null; then echo READY; break; fi
    sleep 1
  done
  curl -sS http://localhost:8000/health | sed -n '1,120p'

  echo
  echo "== create upload (fixture) =="
  if [[ ! -f "$FIXTURE" ]]; then echo "(fixture missing) $FIXTURE"; exit 2; fi
  UP_OUT=/tmp/step043_upload.json
  curl -sS -o "$UP_OUT" -w "HTTP=%{http_code}\n" \
    -F file=@"$FIXTURE" -F student_id=stu_043 -F lab_id=hello-proof \
    http://localhost:8000/submissions/upload_zip | tee /tmp/step043_http_upload.txt
  cat "$UP_OUT" | sed -n '1,200p'
  SUB_ID=$(python3 - <<'PY'
import json
print(json.load(open('/tmp/step043_upload.json')).get('submission_id',''))
PY
  )
  echo "submission_id=$SUB_ID"

  echo
  echo "== poll submission until terminal =="
  for i in $(seq 1 60); do
    curl -sS -o /tmp/step043_sub.json http://localhost:8000/submissions/$SUB_ID >/dev/null || true
    ST=$(python3 - <<'PY'
import json
print(json.load(open('/tmp/step043_sub.json')).get('status',''))
PY
    )
    [[ "$ST" != "queued" && "$ST" != "running" && -n "$ST" ]] && break
    sleep 1
  done
  echo "submission_status_final=$ST"
  cat /tmp/step043_sub.json | sed -n '1,200p'
  RUN_ID=$(python3 - <<'PY'
import json
print(json.load(open('/tmp/step043_sub.json')).get('latest_run_id',''))
PY
  )
  echo "run_id=$RUN_ID"

  echo
  echo "== GET /runs/{run_id} =="
  curl -sS -o /tmp/step043_run.json http://localhost:8000/runs/$RUN_ID >/dev/null || true
  cat /tmp/step043_run.json | sed -n '1,200p'
  PROOF_ID=$(python3 - <<'PY'
import json
print(json.load(open('/tmp/step043_run.json')).get('proof_bundle_id',''))
PY
  )
  echo "proof_bundle_id=$PROOF_ID"

  echo
  echo "== GET /proofs/{proof_bundle_id} =="
  curl -sS -o /tmp/step043_proof.json http://localhost:8000/proofs/$PROOF_ID >/dev/null || true
  cat /tmp/step043_proof.json | sed -n '1,200p'

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
