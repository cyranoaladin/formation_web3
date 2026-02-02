#!/usr/bin/env bash
# Step 046 — api_add_run_get_endpoint (API only)
# Confirm GET /runs/{run_id} and exercise it end-to-end.
# No doc changes.

set -euo pipefail

FILE="api/app/main.py"
ROUTE_PATTERN='@app.get\("/runs/\{run_id\}"\)'

echo "--- grep route (${FILE}) ---"
if grep -nE "$ROUTE_PATTERN" "$FILE"; then
  echo "ROUTE_PRESENT=1"
else
  echo "ROUTE_PRESENT=0 (route not found)" >&2
  exit 1
fi

echo "--- docker compose up -d --build ---"
docker compose up -d --build

# Upload a submission so worker will create a run
URL_UPL="http://localhost:8000/submissions/upload_zip"
OUT_UPL="/tmp/upl_046.json"
CODE_UPL=$(curl -sS -o "$OUT_UPL" -w "HTTP=%{http_code}\n" -F file=@tests/fixtures/minimal.zip -F student_id=stu_046 -F lab_id=lab_demo "$URL_UPL")
echo "--- upload_zip ---"; echo "$CODE_UPL"; cat "$OUT_UPL"; echo

SUB_ID=$(python3 - <<'PY'
import json
try:
  print(json.load(open('/tmp/upl_046.json'))['submission_id'])
except Exception:
  print('')
PY
)
if [[ -z "$SUB_ID" ]]; then
  echo "ERROR: submission_id not returned" >&2
  exit 1
fi
echo "SUBMISSION_ID=$SUB_ID"

# Poll submission until latest_run_id available
URL_SUB="http://localhost:8000/submissions/${SUB_ID}"
OUT_SUB="/tmp/sub_046.json"
RUN_ID=""
for i in $(seq 1 120); do
  curl -sS -o "$OUT_SUB" "$URL_SUB" >/dev/null || true
  RUN_ID=$(python3 - <<'PY'
import json
try:
  d=json.load(open('/tmp/sub_046.json'))
  v=d.get('latest_run_id')
  print('' if v in (None, 'None') else v)
except Exception:
  print('')
PY
  )
  if [[ -n "$RUN_ID" ]]; then break; fi
  sleep 1
done

if [[ -z "$RUN_ID" ]]; then
  echo "ERROR: latest_run_id not set" >&2
  echo "--- submission snapshot ---"; cat "$OUT_SUB"; echo
  exit 1
fi
echo "RUN_ID=$RUN_ID"

echo "--- GET /runs/{run_id} ---"
OUT_RUN="/tmp/run_046.json"
CODE_RUN=$(curl -sS -o "$OUT_RUN" -w "HTTP=%{http_code}\n" "http://localhost:8000/runs/${RUN_ID}")
echo "$CODE_RUN"
cat "$OUT_RUN"; echo

# Repo status
echo "--- git status --porcelain ---"
git status --porcelain | sed -n '1,120p'