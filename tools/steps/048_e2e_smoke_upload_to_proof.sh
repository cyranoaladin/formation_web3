#!/usr/bin/env bash
# Step 048 — e2e_smoke_upload_to_proof
# Goal: Prove end-to-end flow: upload -> submission -> worker creates run + proof_bundle -> run has proof_bundle_id
# Proofs: HTTP statuses, JSON extracts, PASS/FAIL markers, worker logs tail, git status

set -euo pipefail

fail() { echo "E2E_SMOKE_PROOF=FAIL : $*"; exit 2; }

HEALTH_JSON=/tmp/048_health.json
UPLOAD_JSON=/tmp/048_upload.json
SUB_JSON=/tmp/048_submission.json
RUN_JSON=/tmp/048_run.json

# 1) Health check
echo "--- /health ---"
HTTP_H=$(curl -sS -w "\nHTTP=%{http_code}\n" http://localhost:8000/health -o "$HEALTH_JSON" || true)
cat "$HEALTH_JSON" || true; echo "$HTTP_H"
[[ "$HTTP_H" == *"HTTP=200"* ]] || fail "health_not_ok"

# 2) Upload minimal fixture
[[ -f tests/fixtures/minimal.zip ]] || fail "fixture_missing: tests/fixtures/minimal.zip"
echo "--- upload_zip ---"
HTTP_U=$(curl -sS -w "\nHTTP=%{http_code}\n" -o "$UPLOAD_JSON" \
  -F file=@tests/fixtures/minimal.zip -F student_id=smoke_048 -F lab_id=lab_demo \
  http://localhost:8000/submissions/upload_zip || true)
cat "$UPLOAD_JSON"; echo "$HTTP_U"
[[ "$HTTP_U" == *"HTTP=200"* ]] || fail "upload_http_not_200"

SUB_ID=$(python3 - <<'PY'
import json,sys
j=json.load(open('/tmp/048_upload.json'))
print(j.get('submission_id',''))
PY
)
[[ -n "$SUB_ID" ]] || fail "no_submission_id"

echo "SMOKE_SUBMISSION_ID=$SUB_ID"

# 3) Poll submission until terminal state
for i in $(seq 1 90); do
  curl -sS -o "$SUB_JSON" http://localhost:8000/submissions/$SUB_ID >/dev/null || true
  ST=$(python3 - <<'PY'
import json
print(json.load(open('/tmp/048_submission.json')).get('status',''))
PY
)
  [[ "$ST" != "queued" && "$ST" != "running" && -n "$ST" ]] && break
  sleep 1
done

echo "SMOKE_SUB_STATUS_FINAL=$ST"
[[ "$ST" == "needs_review" || "$ST" == "validated" || "$ST" == "failed" || "$ST" == "completed" ]] || fail "unexpected_final_status:$ST"

RUN_ID=$(python3 - <<'PY'
import json
print(json.load(open('/tmp/048_submission.json')).get('latest_run_id',''))
PY
)
[[ -n "$RUN_ID" ]] || fail "no_latest_run_id"
echo "SMOKE_LATEST_RUN_ID=$RUN_ID"

# 4) Fetch run and assert proof_bundle_id present
echo "--- get run ---"
curl -sS -o "$RUN_JSON" http://localhost:8000/runs/$RUN_ID >/dev/null || true

STATUS_AND_PROOF=$(python3 - <<'PY'
import json
j=json.load(open('/tmp/048_run.json'))
print(j.get('status',''), j.get('proof_bundle_id'))
PY
)
RUN_STATUS=$(echo "$STATUS_AND_PROOF" | awk '{print $1}')
PROOF_ID=$(echo "$STATUS_AND_PROOF" | awk '{print $2}')

echo "SMOKE_RUN_STATUS=$RUN_STATUS"
echo "SMOKE_RUN_PROOF_BUNDLE_ID=$PROOF_ID"

[[ "$RUN_STATUS" == "completed" ]] || fail "run_not_completed"
[[ -n "$PROOF_ID" && "$PROOF_ID" != "None" && "$PROOF_ID" == proof_* ]] || fail "missing_or_invalid_proof_bundle_id:$PROOF_ID"

# 5) Tail worker logs
echo "--- docker compose logs --tail=120 worker ---"
docker compose logs --tail=120 worker || true

# 6) PASS marker
echo "E2E_SMOKE_PROOF=PASS"

# 7) git status for traceability
echo "--- git status --porcelain ---"
git status --porcelain | sed -n '1,200p'
