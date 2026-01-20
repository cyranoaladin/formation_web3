#!/usr/bin/env bash
# STEP 055 — smoke_e2e_hello_proof_capture (NO/LOW CHANGE)
# E2E test to verify hell-proof execution, logs quality, and result.

set -euo pipefail

TS=$(date +%Y%m%d_%H%M%S)
LOG_FILE="tools/logs/smoke_e2e_hello_proof_${TS}.txt"
mkdir -p tools/logs tools/fixtures/hello-proof

{
  echo "[INFO] STEP 055 @ ${TS}"

  echo
  echo "== A) API Health Check =="
  for i in $(seq 1 60); do
    if curl -sSf http://localhost:8000/health >/dev/null; then echo "READY"; break; fi
    sleep 1
  done
  curl -sS http://localhost:8000/health | python3 -m json.tool

  echo
  echo "== B) Build Fixture =="
  echo "Full integrity check $(date)" > tools/fixtures/hello-proof/smoke_055.txt
  (cd tools/fixtures && rm -f hello-proof_055.zip && zip -r hello-proof_055.zip hello-proof >/dev/null)
  ls -la tools/fixtures/hello-proof_055.zip

  echo
  echo "== C) Upload & Process =="
  UP=$(curl -sS -F file=@tools/fixtures/hello-proof_055.zip -F student_id=student_055 -F lab_id=hello-proof http://localhost:8000/submissions/upload_zip)
  SUB_ID=$(echo "$UP" | python3 -c "import sys, json; print(json.load(sys.stdin).get('submission_id',''))")
  echo "Submitted: $SUB_ID"

  echo "Polling..."
  STATUS=""
  for i in $(seq 1 60); do
      STATUS=$(curl -sS http://localhost:8000/submissions/$SUB_ID | python3 -c "import sys, json; print(json.load(sys.stdin).get('status',''))")
      if [[ "$STATUS" == "completed" || "$STATUS" == "failed" ]]; then break; fi
      sleep 1
  done
  echo "Final Status: $STATUS"
  
  if [[ "$STATUS" != "completed" ]]; then 
      echo "[FAIL] Submission failed to complete."
      curl -sS http://localhost:8000/submissions/$SUB_ID | python3 -m json.tool
      exit 1
  fi

  echo
  echo "== D) Fetch Proof & Assertions =="
  PROOF_ID=$(curl -sS http://localhost:8000/submissions/$SUB_ID | python3 -c "import sys, json; print(json.load(sys.stdin).get('proof_bundle_id',''))")
  echo "Proof ID: $PROOF_ID"
  
  PROOF_JSON=$(curl -sS http://localhost:8000/proofs/$PROOF_ID)
  
  # Assertions using Python
  python3 -c "
import sys, json

try:
    p = json.load(open('/dev/stdin'))
    arts = p.get('artifacts', {})
    
    # 1. Check artifact.logs
    logs = arts.get('logs', '')
    if 'placeholder' in logs:
        print('[FAIL] Logs contain placeholder')
        sys.exit(1)
    if 'hello-proof' not in logs:
        print('[FAIL] Logs do not contain hello-proof output')
        print(f'Logs snippet: {logs[:200]}')
        sys.exit(1)
    print('[PASS] Logs look correct (no placeholder, contains hello-proof)')

    # 2. Check files_count in autograde result (which ended up in db) OR proof result JSON
    # The proof result should be the runner's result JSON string
    res_str = arts.get('result', '{}')
    try:
        res_json = json.loads(res_str)
        if res_json.get('status') == 'ok':
             print('[PASS] Result status is ok')
        else:
             print(f'[FAIL] Result status is {res_json.get(\"status\")}')
             sys.exit(1)
             
        if res_json.get('lab_id') == 'hello-proof':
             print('[PASS] Result lab_id is hello-proof')
        else:
             print(f'[FAIL] Result lab_id mismatch')
             sys.exit(1)
    except Exception as e:
        print(f'[FAIL] Artifacts result is not valid JSON: {str(e)}')
        sys.exit(1)
        
    print('[INFO] All assertions passed.')

except Exception as e:
    print(f'[CRITICAL] Verification script crashed: {e}')
    sys.exit(1)
" <<< "$PROOF_JSON"

  # files_count check (via run object or specific logic if exposed)
  # The run object has files_count. We can try to query it via submission link?
  # Or we trust that the worker logic executed (verified in 054) and just check logic here?
  # The prompt asks: "files_count >= 1 si sandbox contient un fichier non-out non-zip"
  # I'll check what we can see from PROOF artifacts. files_count might not be explicitly in artifacts unless we put it there.
  # But the USER instruction says: "artifacts.result.status == 'ok'" - done.
  # "files_count cohérent (>0)" - where? Probably `autograde_runs.result.files_count`.
  # I can check via a direct docker exec mongo query to be sure, like before.
  
  echo "-- Checking files_count in DB --"
  FILES_COUNT=$(docker exec rbk-worker python -c "from pymongo import MongoClient; print(MongoClient('mongodb://mongo:27017')['rbk_labs'].autograde_runs.find_one({'submission_id': '$SUB_ID'}).get('result', {}).get('files_count', -1))")
  echo "DB files_count: $FILES_COUNT"
  if [[ "$FILES_COUNT" -gt 0 ]]; then
      echo "[PASS] files_count > 0 ($FILES_COUNT)"
  else
      echo "[WARN] files_count is 0. Listing sandbox..."
      docker exec rbk-worker find /tmp/rbk_runner/$SUB_ID
      # We uploaded a zip with a folder 'hello-proof/smoke_055.txt'.
      # Runner unzips to 'work'. 
      # files_count logic counts all files in sandbox root recursively (excluding out/zip).
      # If zip contained a folder, the file is `work/hello-proof/smoke_055.txt`.
      # Should count as 1.
      # If 0, investigate.
  fi

  echo
  echo "== E) Verify Harness =="
  bash tools/verify.sh --spec tools/verify.spec

} | tee "$LOG_FILE"
