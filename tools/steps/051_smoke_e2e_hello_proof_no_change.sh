#!/usr/bin/env bash
# STEP 051 — rerun_smoke_e2e_hello_proof (NO-CODE CHANGE)
# Idempotent E2E smoke proving runner feeds artifacts.logs + artifacts.result for lab_id=hello-proof.
# Logs: tools/logs/smoke_e2e_hello_proof_YYYYMMDD_HHMMSS.txt

set -euo pipefail

TS=$(date +%Y%m%d_%H%M%S)
REPORT_PATH="tools/logs/smoke_e2e_hello_proof_${TS}.txt"
mkdir -p tools/logs tools/fixtures/hello-proof

sha() { if [[ -f "$1" ]]; then sha256sum "$1" | awk '{print $1}'; else echo "(absent)"; fi }

{
  echo "[INFO] STEP 051 @ ${TS}"

  echo
  echo "== A) Infra: compose up and wait health =="
  docker compose up -d --build mongo api worker
  for i in $(seq 1 60); do
    if curl -sSf http://localhost:8000/health >/dev/null; then echo READY; break; fi
    sleep 1
  done
  curl -sS -w "\nHTTP=%{http_code}\n" http://localhost:8000/health -o /tmp/051_health.json
  cat /tmp/051_health.json; echo

  echo
  echo "== B) Fixture: build tools/fixtures/hello-proof.zip =="
  echo "Hello Proof fixture $(date -u +%Y-%m-%dT%H:%M:%SZ)" > tools/fixtures/hello-proof/README.txt
  (cd tools/fixtures && rm -f hello-proof.zip && zip -X -r hello-proof.zip hello-proof >/dev/null)
  ls -la tools/fixtures/hello-proof.zip
  echo "ZIP_SHA256=$(sha tools/fixtures/hello-proof.zip)"

  echo
  echo "== C) Upload + polling =="
  UP=/tmp/051_upload.json
  UPSTAT=$(curl -sS -o "$UP" -w "HTTP=%{http_code}\n" \
    -F file=@tools/fixtures/hello-proof.zip -F student_id=smoke_051 -F lab_id=hello-proof \
    http://localhost:8000/submissions/upload_zip)
  echo "UPLOAD_HTTP=${UPSTAT}"; cat "$UP"; echo
  SUB_ID=$(python3 - <<'PY'
import json; print(json.load(open('/tmp/051_upload.json')).get('submission_id',''))
PY
  )
  echo "submission_id=${SUB_ID}"

  for i in $(seq 1 60); do
    curl -sS -o /tmp/051_sub.json http://localhost:8000/submissions/$SUB_ID >/dev/null || true
    ST=$(python3 - <<'PY'
import json; print(json.load(open('/tmp/051_sub.json')).get('status',''))
PY
    )
    [[ "$ST" == "completed" ]] && break
    [[ -n "$ST" && "$ST" != "queued" && "$ST" != "running" ]] && break
    sleep 1
  done
  echo "submission_status_final=${ST}"; cat /tmp/051_sub.json | sed -n '1,200p'

  RUN_ID=$(python3 - <<'PY'
import json
j=json.load(open('/tmp/051_sub.json'))
print(j.get('run_id') or j.get('latest_run_id',''))
PY
  )
  PF=$(python3 - <<'PY'
import json
print(json.load(open('/tmp/051_sub.json')).get('proof_bundle_id',''))
PY
  )
  echo "run_id=${RUN_ID}"; echo "proof_bundle_id=${PF}"

  echo
  echo "== D) Fetch proof and show artifacts snippets =="
  PR=/tmp/051_proof.json
  PFSTAT=$(curl -sS -o "$PR" -w "HTTP=%{http_code}\n" http://localhost:8000/proofs/$PF)
  echo "PROOF_HTTP=${PFSTAT}"; head -n 40 "$PR"

  echo "-- artifacts.result (minified or 20 lines) --"
  python3 - <<'PY'
import json, sys
p=json.load(open('/tmp/051_proof.json'))
arts=p.get('artifacts',{}) if isinstance(p,dict) else {}
res=arts.get('result')
try:
    if isinstance(res,str):
        j=json.loads(res)
    else:
        j=res
    s=json.dumps(j, ensure_ascii=False)
    print(s[:800])
except Exception:
    print(str(res)[:800])
PY

  echo "-- artifacts.logs (first 20 lines) --"
  python3 - <<'PY'
import json
p=json.load(open('/tmp/051_proof.json'))
arts=p.get('artifacts',{}) if isinstance(p,dict) else {}
logs=(arts.get('logs') or '')
lines=(logs.splitlines())[:20]
print('\n'.join(lines))
PY

  echo
  echo "== E) Verify harness =="
  if [[ -x tools/verify.sh ]]; then
    tools/verify.sh --spec tools/verify.spec
  else
    bash tools/verify.sh --spec tools/verify.spec
  fi

  echo
  echo "[SUMMARY]"
  echo "submission_id=${SUB_ID}"
  echo "run_id=${RUN_ID}"
  echo "proof_bundle_id=${PF}"
  echo "REPORT_PATH=${REPORT_PATH}"
} | tee "$REPORT_PATH"
