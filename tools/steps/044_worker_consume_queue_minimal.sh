#!/usr/bin/env bash
# Step 044 — worker_consume_queue_minimal (Worker only)
# Proof that worker consumes queued submissions, creates run + proof_bundle, and finalizes status.
# No doc changes.

set -euo pipefail

# 1) Show key transitions in worker code
echo "--- grep transitions (worker/worker.py) ---"
grep -nE 'status\": \"queued\"|status\": \"running\"|proof_bundle|autograde_runs|needs_review|completed' worker/worker.py || true

# 2) Ensure stack up
echo "--- docker compose up -d --build ---"
docker compose up -d --build

# 3) Upload a submission (fixture)
URL_UPL="http://localhost:8000/submissions/upload_zip"
OUT_UPL="/tmp/upl_044.json"
CODE_UPL=$(curl -sS -o "$OUT_UPL" -w "HTTP=%{http_code}\n" -F file=@tests/fixtures/minimal.zip -F student_id=stu_worker -F lab_id=lab_demo "$URL_UPL")
echo "--- upload_zip ---"
echo "$CODE_UPL"; cat "$OUT_UPL"; echo

# Extract submission_id
SUB_ID=$(python3 - <<'PY'
import json,sys
try:
  print(json.load(open('/tmp/upl_044.json'))['submission_id'])
except Exception:
  print('')
PY
)
if [[ -z "$SUB_ID" ]]; then
  echo "ERROR: submission_id not returned" >&2
  exit 1
fi
echo "SUBMISSION_ID=$SUB_ID"

# 4) Poll submission until status not in queued/running/uploaded
URL_SUB="http://localhost:8000/submissions/${SUB_ID}"
OUT_SUB="/tmp/sub_044.json"
STATUS=""
for i in $(seq 1 120); do
  curl -sS -o "$OUT_SUB" "$URL_SUB" >/dev/null || true
  STATUS=$(python3 - <<'PY'
import json
try:
  d=json.load(open('/tmp/sub_044.json'))
  print(d.get('status',''))
except Exception:
  print('')
PY
  )
  if [[ "$STATUS" != "queued" && "$STATUS" != "running" && "$STATUS" != "uploaded" && -n "$STATUS" ]]; then
    break
  fi
  sleep 1
done

echo "--- final submission ---"
cat "$OUT_SUB"; echo

# 5) If run id present, fetch run
RUN_ID=$(python3 - <<'PY'
import json
try:
  d=json.load(open('/tmp/sub_044.json'))
  print(d.get('latest_run_id',''))
except Exception:
  print('')
PY
)
if [[ -n "$RUN_ID" && "$RUN_ID" != "None" ]]; then
  echo "RUN_ID=$RUN_ID"
  echo "--- GET /runs/{run_id} ---"
  curl -sS "http://localhost:8000/runs/${RUN_ID}"; echo
fi

# 6) Worker logs
echo "--- docker compose logs --tail=200 worker ---"
docker compose logs --tail=200 worker || true

# 7) Repo status (no changes expected besides steps)
echo "--- git status --porcelain ---"
git status --porcelain | sed -n '1,120p'