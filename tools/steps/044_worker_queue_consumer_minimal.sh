#!/usr/bin/env bash
# STEP 044 — worker_queue_consumer_minimal (CODE CHANGE)
# But: rendre le worker réellement utile (queued -> running -> completed) avec run et proof bundle
# Actions:
# - run: status running -> completed
# - proof_bundle: immutable true + artifacts {logs, result}
# - submission: status completed + lier run_id + proof_bundle_id (et latest_run_id conservé)
# - idempotent patch (textual), pas de duplication
# Preuves: sha256 avant/après, grep marqueurs, compose logs, curl GET endpoints, verify PASS

set -euo pipefail

TS=$(date +%Y%m%d_%H%M%S)
LOG="tools/logs/044_worker_${TS}.txt"
mkdir -p tools/logs

sha() { if [[ -f "$1" ]]; then sha256sum "$1" | awk '{print $1}'; else echo "(absent)"; fi }

WORKER="worker/worker.py"
API_MAIN="api/app/main.py"
FIXTURE="tests/fixtures/minimal.zip"

{
  echo "[INFO] STEP 044 @ ${TS}"
  echo "== SHA BEFORE =="
  echo "worker.py: $(sha "$WORKER")"

  echo
  echo "== PATCH worker.py =="
  python3 - <<'PY'
from pathlib import Path
p=Path('worker/worker.py')
s=p.read_text(encoding='utf-8')
changed=False

# Ensure immutable True in proof_doc
if '"immutable": True' not in s:
    s = s.replace('"artifacts": {', '"immutable": True,\n                "artifacts": {', 1)
    changed=True

# Inject result artifact (result.json content) by building a small JSON string
if 'arts["result"]' not in s and '"result": arts["result"]' not in s:
    # Add composition of result JSON right after arts = build_proof_artifacts(upload_path)
    if 'arts = build_proof_artifacts(upload_path)' in s:
        s = s.replace(
            'arts = build_proof_artifacts(upload_path)',
            'arts = build_proof_artifacts(upload_path)\n\n            # build result.json artifact (minimal deterministic)\n            result_obj = {\n                "status": "ok",\n                "lab_id": lab_id,\n                "submission_id": submission_id,\n                "run_id": run_id,\n                "started_at": iso_now(),\n                "finished_at": iso_now()\n            }\n            import json as _json\n            arts_result = _json.dumps(result_obj, ensure_ascii=False)'
        )
        changed=True
    # Insert the result into proof_doc artifacts mapping
    s = s.replace('"audit": arts["audit"],', '"audit": arts["audit"],\n                    "result": arts_result,', 1)
    changed=True

# Ensure final submission status is completed and links include run_id and proof_bundle_id
if '"$set": {"status": ("validated" if is_hello else "needs_review"), "updated_at": now()}' in s:
    s = s.replace('"$set": {"status": ("validated" if is_hello else "needs_review"), "updated_at": now()}',
                  '"$set": {"status": "completed", "updated_at": now(), "run_id": run_id, "proof_bundle_id": proof_id}', 1)
    changed=True
elif '"$set": {"status": "needs_review", "updated_at": now()}' in s:
    s = s.replace('"$set": {"status": "needs_review", "updated_at": now()}',
                  '"$set": {"status": "completed", "updated_at": now(), "run_id": run_id, "proof_bundle_id": proof_id}', 1)
    changed=True

# Ensure run.result.score_auto keeps previous value (score_auto_val if defined), otherwise leave as-is
# If constant 50 is present, replace with score_auto_val when available
if '"score_auto": 50,' in s and 'score_auto_val' in s:
    s = s.replace('"score_auto": 50,', '"score_auto": score_auto_val,', 1)
    changed=True

if changed:
    p.write_text(s, encoding='utf-8')
    print('WORKER_PATCHED=1')
else:
    print('WORKER_PATCHED=0')
PY

  echo
  echo "== SHA AFTER =="
  echo "worker.py: $(sha "$WORKER")"

  echo
  echo "== GREP markers =="
  grep -nE 'immutable|result"|status": "completed"|run_id|proof_bundle_id' "$WORKER" || true

  echo
  echo "== docker compose up -d --build (worker, api, mongo) =="
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
  echo "== upload fixture and poll -> completed =="
  if [[ ! -f "$FIXTURE" ]]; then echo "(fixture missing) $FIXTURE"; exit 2; fi
  OUT=/tmp/step044_upload.json
  curl -sS -o "$OUT" -w "HTTP=%{http_code}\n" \
    -F file=@"$FIXTURE" -F student_id=stu_044 -F lab_id=hello-proof \
    http://localhost:8000/submissions/upload_zip | tee /tmp/step044_http_upload.txt
  cat "$OUT" | sed -n '1,120p'
  SUB_ID=$(python3 - <<'PY'
import json
print(json.load(open('/tmp/step044_upload.json')).get('submission_id',''))
PY
  )
  echo "submission_id=$SUB_ID"

  for i in $(seq 1 60); do
    curl -sS -o /tmp/step044_sub.json http://localhost:8000/submissions/$SUB_ID >/dev/null || true
    ST=$(python3 - <<'PY'
import json
print(json.load(open('/tmp/step044_sub.json')).get('status',''))
PY
    )
    [[ "$ST" != "queued" && "$ST" != "running" && -n "$ST" ]] && break
    sleep 1
  done
  echo "submission_status_final=$ST"
  cat /tmp/step044_sub.json | sed -n '1,160p'

  RUN_ID=$(python3 - <<'PY'
import json
print(json.load(open('/tmp/step044_sub.json')).get('run_id','') or json.load(open('/tmp/step044_sub.json')).get('latest_run_id',''))
PY
  )
  PROOF_ID=$(python3 - <<'PY'
import json
print(json.load(open('/tmp/step044_sub.json')).get('proof_bundle_id',''))
PY
  )
  echo "run_id=$RUN_ID"
  echo "proof_bundle_id=$PROOF_ID"

  echo
  echo "== GET /runs/{run_id} =="
  curl -sS -o /tmp/step044_run.json http://localhost:8000/runs/$RUN_ID >/dev/null || true
  cat /tmp/step044_run.json | sed -n '1,200p'

  echo
  echo "== GET /proofs/{proof_bundle_id} =="
  curl -sS -o /tmp/step044_proof.json http://localhost:8000/proofs/$PROOF_ID >/dev/null || true
  cat /tmp/step044_proof.json | sed -n '1,200p'

  echo
  echo "== docker compose logs --tail=120 worker =="
  docker compose logs --tail=120 worker || true

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