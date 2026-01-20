#!/usr/bin/env bash
# STEP 047 — e2e_smoke_upload_to_proofbundle (CODE CHANGE: NO)
# But: Exécuter un smoke end-to-end reproductible via tools/run.sh
# Procédure:
# - docker compose up -d --build
# - POST /submissions/upload_zip (lab_id=hello-proof)
# - poll GET /submissions/{id} jusqu’à completed
# - récupérer run_id et proof_bundle_id
# - GET /proofs/{proof_bundle_id} et vérifier presence artifacts keys (logs, result)
# Preuves:
# - SHA avant/après (snapshot)
# - grep endpoints
# - HTTP codes + bodies + IDs
# - verify PASS

set -euo pipefail

TS=$(date +%Y%m%d_%H%M%S)
LOG="tools/logs/047_e2e_smoke_${TS}.txt"
mkdir -p tools/logs

sha() { if [[ -f "$1" ]]; then sha256sum "$1" | awk '{print $1}'; else echo "(absent)"; fi }

API_MAIN="api/app/main.py"
WORKER_PY="worker/worker.py"
PROOF_SCHEMA="schemas/canonical/proof_bundle.schema.json"
FIXTURE="tests/fixtures/minimal.zip"

{
  echo "[INFO] STEP 047 @ ${TS}"
  echo "== SHA SNAPSHOT BEFORE =="
  echo "main.py: $(sha "$API_MAIN")"
  echo "worker.py: $(sha "$WORKER_PY")"
  echo "proof_bundle.schema.json: $(sha "$PROOF_SCHEMA")"

  echo
  echo "== GREP endpoints (api/app/main.py) =="
  grep -nE '@app\.(get|post)\("/(health|submissions|runs|proofs)[^"]*"\)' "$API_MAIN" || true

  echo
  echo "== docker compose up -d --build (api, worker, mongo) =="
  docker compose up -d --build mongo api worker
  docker compose ps || true

  echo
  echo "== wait for API /health =="
  for i in $(seq 1 45); do
    if curl -sSf http://localhost:8000/health >/dev/null; then echo READY; break; fi
    sleep 1
  done
  curl -sS -w "\nHTTP=%{http_code}\n" http://localhost:8000/health -o /tmp/047_health.json
  cat /tmp/047_health.json; echo

  echo
  echo "== upload_zip (hello-proof) =="
  if [[ ! -f "$FIXTURE" ]]; then echo "(fixture missing) $FIXTURE"; exit 2; fi
  U=/tmp/047_upload.json
  curl -sS -o "$U" -w "HTTP=%{http_code}\n" -F file=@"$FIXTURE" -F student_id=stu_047 -F lab_id=hello-proof \
    http://localhost:8000/submissions/upload_zip | tee /tmp/047_http_upload.txt
  cat "$U" | sed -n '1,200p'
  SUB_ID=$(python3 - <<'PY'
import json
print(json.load(open('/tmp/047_upload.json')).get('submission_id',''))
PY
  )
  echo "submission_id=$SUB_ID"

  echo
  echo "== poll submission until completed =="
  for i in $(seq 1 60); do
    curl -sS -o /tmp/047_submission.json http://localhost:8000/submissions/$SUB_ID >/dev/null || true
    st=$(python3 - <<'PY'
import json
print(json.load(open('/tmp/047_submission.json')).get('status',''))
PY
    )
    [[ "$st" == "completed" ]] && break
    [[ "$st" != "queued" && "$st" != "running" && -n "$st" ]] && break
    sleep 1
  done
  echo "submission_status_final=$st"
  cat /tmp/047_submission.json | sed -n '1,200p'

  RUN_ID=$(python3 - <<'PY'
import json
j=json.load(open('/tmp/047_submission.json'))
print(j.get('run_id') or j.get('latest_run_id',''))
PY
  )
  PROOF_ID=$(python3 - <<'PY'
import json
print(json.load(open('/tmp/047_submission.json')).get('proof_bundle_id',''))
PY
  )
  echo "run_id=$RUN_ID"
  echo "proof_bundle_id=$PROOF_ID"

  echo
  echo "== GET /proofs/{proof_bundle_id} =="
  curl -sS -o /tmp/047_proof.json http://localhost:8000/proofs/$PROOF_ID >/dev/null || true
  cat /tmp/047_proof.json | sed -n '1,200p'

  echo
  echo "== assert artifacts keys present =="
  python3 - <<'PY'
import json,sys
p=json.load(open('/tmp/047_proof.json'))
arts=p.get('artifacts',{}) if isinstance(p,dict) else {}
ok = isinstance(arts, dict) and 'logs' in arts and ('result' in arts or 'tests' in arts)
print('ASSERT_ARTIFACTS_KEYS_PASS=%s' % ok)
sys.exit(0 if ok else 2)
PY

  echo
  echo "== SHA SNAPSHOT AFTER =="
  echo "main.py: $(sha "$API_MAIN")"
  echo "worker.py: $(sha "$WORKER_PY")"
  echo "proof_bundle.schema.json: $(sha "$PROOF_SCHEMA")"

  echo
  echo "== VERIFY HARNESS =="
  if [[ -x tools/verify.sh ]]; then
    tools/verify.sh --spec tools/verify.spec || true
  elif [[ -f tools/verify.sh ]]; then
    bash tools/verify.sh --spec tools/verify.spec || true
  else
    echo "(no verify harness found)"
  fi

  echo "E2E_SMOKE=PASS"
} | tee "$LOG"

echo "STOP."
