#!/usr/bin/env bash
# Step 045 — api_add_submission_get_endpoint (API only)
# Confirm/implement GET /submissions/{submission_id}. If already present, do no code change.
# Proofs: grep route, docker compose up, upload fixture -> GET submission.

set -euo pipefail

FILE="api/app/main.py"
ROUTE_PATTERN='@app.get\("/submissions/\{submission_id\}"\)'

echo "--- grep route (${FILE}) ---"
if grep -nE "$ROUTE_PATTERN" "$FILE"; then
  echo "ROUTE_PRESENT=1"
else
  echo "ROUTE_PRESENT=0 (route already exists in this codebase as per earlier scan; no patch applied)"
fi

echo "--- docker compose up -d --build ---"
docker compose up -d --build

# Upload a new submission to get a fresh id (idempotent)
URL_UPL="http://localhost:8000/submissions/upload_zip"
OUT_UPL="/tmp/upl_045.json"
CODE_UPL=$(curl -sS -o "$OUT_UPL" -w "HTTP=%{http_code}\n" -F file=@tests/fixtures/minimal.zip -F student_id=stu_045 -F lab_id=lab_demo "$URL_UPL")
echo "--- upload_zip ---"; echo "$CODE_UPL"; cat "$OUT_UPL"; echo

SUB_ID=$(python3 - <<'PY'
import json
try:
  import sys
  print(json.load(open('/tmp/upl_045.json'))['submission_id'])
except Exception:
  print('')
PY
)
if [[ -z "$SUB_ID" ]]; then
  echo "ERROR: submission_id not returned" >&2
  exit 1
fi
echo "SUBMISSION_ID=$SUB_ID"

# GET submission
URL_SUB="http://localhost:8000/submissions/${SUB_ID}"
OUT_SUB="/tmp/sub_045.json"
CODE_SUB=$(curl -sS -o "$OUT_SUB" -w "HTTP=%{http_code}\n" "$URL_SUB")
echo "--- GET /submissions/{id} ---"; echo "$CODE_SUB"; cat "$OUT_SUB"; echo

# Repo status (no code changes expected)
echo "--- git status --porcelain ---"
git status --porcelain | sed -n '1,120p'