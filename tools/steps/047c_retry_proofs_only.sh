#!/usr/bin/env bash
# Step 047c — retry_proofs_only
# Goal: After 047b rebuild, verify /health then run valid/invalid flows only (no rebuild).
# Proofs: /health, submission statuses, worker logs, git status

set -euo pipefail

# Wait briefly for API to finish startup
sleep 1

echo "--- curl /health ---"
curl -sS -w "\nHTTP=%{http_code}\n" http://localhost:8000/health -o /tmp/health_after_047c.json
cat /tmp/health_after_047c.json || true

# Valid flow
echo "--- VALID: upload_zip lab_demo ---"
VALID_OUT=/tmp/upl_047c_valid.json
curl -sS -o "$VALID_OUT" -w "HTTP=%{http_code}\n" -F file=@tests/fixtures/minimal.zip -F student_id=stu_valid_c -F lab_id=lab_demo http://localhost:8000/submissions/upload_zip
cat "$VALID_OUT"; echo
VALID_SUB=$(python3 - <<'PY'
import json,sys
j=json.load(open('/tmp/upl_047c_valid.json'))
print(j.get('submission_id',''))
PY
)

for i in $(seq 1 60); do
  curl -sS -o /tmp/sub_valid_c.json http://localhost:8000/submissions/$VALID_SUB >/dev/null || true
  st=$(python3 - <<'PY'
import json
print(json.load(open('/tmp/sub_valid_c.json')).get('status',''))
PY
)
  [[ "$st" != "queued" && "$st" != "running" && -n "$st" ]] && break
  sleep 1
done
echo "FINAL_STATUS_VALID_C=$st"; cat /tmp/sub_valid_c.json; echo

# Invalid flow
echo "--- INVALID: upload_zip invalid_proof ---"
INV_OUT=/tmp/upl_047c_invalid.json
curl -sS -o "$INV_OUT" -w "HTTP=%{http_code}\n" -F file=@tests/fixtures/minimal.zip -F student_id=stu_invalid_c -F lab_id=invalid_proof http://localhost:8000/submissions/upload_zip
cat "$INV_OUT"; echo
INV_SUB=$(python3 - <<'PY'
import json,sys
j=json.load(open('/tmp/upl_047c_invalid.json'))
print(j.get('submission_id',''))
PY
)
for i in $(seq 1 60); do
  curl -sS -o /tmp/sub_invalid_c.json http://localhost:8000/submissions/$INV_SUB >/dev/null || true
  st=$(python3 - <<'PY'
import json
print(json.load(open('/tmp/sub_invalid_c.json')).get('status',''))
PY
)
  [[ "$st" == "needs_review" ]] && break
  sleep 1
done
echo "FINAL_STATUS_INVALID_C=$st"; cat /tmp/sub_invalid_c.json; echo

# Logs for context
echo "--- docker compose logs --tail=120 worker ---"
docker compose logs --tail=120 worker || true

echo "--- git status --porcelain ---"
git status --porcelain | sed -n '1,200p'
