#!/usr/bin/env bash
# STEP 042 — api_endpoint_upload_zip_real (CODE CHANGE? NO-CHANGE if already implemented)
# But: implémenter/vérifier POST /submissions/upload_zip (multipart) réellement.
# Preuves: sha256 avant/après (api/app/main.py), grep route, docker compose up, curl upload (HTTP+body), verify PASS.

set -euo pipefail

TS=$(date +%Y%m%d_%H%M%S)
LOG="tools/logs/042_upload_zip_${TS}.txt"
mkdir -p tools/logs

sha() { if [[ -f "$1" ]]; then sha256sum "$1" | awk '{print $1}'; else echo "(absent)"; fi }

API_MAIN="api/app/main.py"
FIXTURE="tests/fixtures/minimal.zip"

{
  echo "[INFO] STEP 042 @ ${TS}"
  echo "== SHA BEFORE =="
  echo "main.py: $(sha "$API_MAIN")"

  echo
  echo "== GREP route =="
  grep -nE '@app.post\("/submissions/upload_zip"' "$API_MAIN" || echo "(route not found)"

  echo
  echo "== docker compose up -d --build (api, worker, mongo) =="
  docker compose up -d --build mongo api worker
  docker compose ps || true

  echo
  echo "== curl upload_zip =="
  if [[ ! -f "$FIXTURE" ]]; then
    echo "(fixture missing) $FIXTURE"; exit 2
  fi
  OUT=/tmp/step042_upload.json
  set +e
  CURL_STAT=$(curl -sS -o "$OUT" -w "HTTP=%{http_code}\n" \
    -F file=@"$FIXTURE" -F student_id=stu_042 -F lab_id=hello-proof \
    http://localhost:8000/submissions/upload_zip)
  RC=$?
  set -e
  echo "CURL_RC=$RC"
  echo "$CURL_STAT"
  sed -n '1,200p' "$OUT" || true

  echo
  echo "== parse submission_id =="
  SUB_ID=$(python3 - <<'PY'
import json,sys
try:
  j=json.load(open('/tmp/step042_upload.json'))
  print(j.get('submission_id',''))
except Exception as e:
  print('')
PY
  )
  echo "submission_id=$SUB_ID"

  echo
  echo "== SHA AFTER =="
  echo "main.py: $(sha "$API_MAIN")"

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
