#!/usr/bin/env bash
# STEP 050a — worker_runner_refine_integration (CODE CHANGE)
# But: corriger l'intégration runner dans le worker: définir is_hello, initialiser arts_result,
#      surcharger logs correctement et déduire la décision depuis result.status

set -euo pipefail

TS=$(date +%Y%m%d_%H%M%S)
LOG="tools/logs/050a_worker_runner_refine_${TS}.txt"
mkdir -p tools/logs

WORKER="worker/worker.py"
FIXTURE="tests/fixtures/minimal.zip"

sha() { if [[ -f "$1" ]]; then sha256sum "$1" | awk '{print $1}'; else echo "(absent)"; fi }

{
  echo "[INFO] STEP 050a @ ${TS}"
  echo "== SHA BEFORE =="
  echo "worker.py: $(sha "$WORKER")"

  echo
  echo "== PATCH worker.py =="
  python3 - <<'PY'
from pathlib import Path
import re
p=Path('worker/worker.py')
s=p.read_text(encoding='utf-8')
changed=False

# 1) Ensure is_hello variable is defined near lab_id assignment
s_new = s
s_new = s_new.replace('lab_id = sub.get("lab_id")', 'lab_id = sub.get("lab_id")\n        is_hello = (lab_id == "hello-proof")')
if s_new != s:
    s = s_new
    changed=True

# 2) Initialize arts_result before potential use
if 'arts_result = ' not in s:
    s = s.replace('arts = build_proof_artifacts(upload_path)', 'arts = build_proof_artifacts(upload_path)\n\n            arts_result = "{}"  # default if runner not executed')
    changed=True

# 3) After calling _run_runner, set decision from runner result
if '_run_runner(lab_id, submission_id, upload_path)' in s and 'decision =' in s:
    # Replace static decision assignment with one based on result.status when is_hello
    s = s.replace('decision = ("validated" if (is_hello and (\n            ("arts_result" in globals()) or True)) else "needs_review")',
                  'decision = "validated" if (is_hello and ro.get("result",{}).get("status") == "ok") else ("needs_review")')
    changed=True

# 4) Proof artifacts: ensure we always include result=arts_result exactly once
# Normalize the artifacts insertion line
s = s.replace('"result": arts_result if "arts_result" in globals() or True else "{}",', '"result": arts_result,')

# 5) Ensure logs are overridden when is_hello
# Already sets arts['logs'] = ro logs; nothing to change unless missing

if changed:
    p.write_text(s, encoding='utf-8')
    print('WORKER_REFINED=1')
else:
    print('WORKER_REFINED=0')
PY

  echo
  echo "== SHA AFTER =="
  echo "worker.py: $(sha "$WORKER")"

  echo
  echo "== docker compose up -d --build worker api mongo =="
  docker compose up -d --build mongo api worker
  docker compose ps || true

  echo
  echo "== upload hello-proof and poll completed =="
  if [[ ! -f "$FIXTURE" ]]; then echo "(fixture missing) $FIXTURE"; exit 2; fi
  U=/tmp/050a_upload.json
  curl -sS -o "$U" -w "HTTP=%{http_code}\n" -F file=@"$FIXTURE" -F student_id=stu_050a -F lab_id=hello-proof \
    http://localhost:8000/submissions/upload_zip | tee /tmp/050a_http_upload.txt
  SUB_ID=$(python3 - <<'PY'
import json; print(json.load(open('/tmp/050a_upload.json')).get('submission_id',''))
PY
  )
  echo "submission_id=$SUB_ID"
  for i in $(seq 1 60); do
    curl -sS -o /tmp/050a_sub.json http://localhost:8000/submissions/$SUB_ID >/dev/null || true
    st=$(python3 - <<'PY'
import json; print(json.load(open('/tmp/050a_sub.json')).get('status',''))
PY
    )
    [[ "$st" == "completed" ]] && break
    [[ -n "$st" && "$st" != "queued" && "$st" != "running" ]] && break
    sleep 1
  done
  echo "submission_status_final=$st"; cat /tmp/050a_sub.json | sed -n '1,200p'
  PF=$(python3 - <<'PY'
import json; print(json.load(open('/tmp/050a_sub.json')).get('proof_bundle_id',''))
PY
  )

  echo
  echo "== GET /proofs/{id} and search HELLO_PROOF marker =="
  curl -sS -o /tmp/050a_proof.json http://localhost:8000/proofs/$PF >/dev/null || true
  cat /tmp/050a_proof.json | sed -n '1,200p'
  echo "-- grep HELLO_PROOF in logs:"; grep -n 'HELLO_PROOF' /tmp/050a_proof.json || true
  echo "-- show result.json snippet:"; grep -n '"result"' /tmp/050a_proof.json || true

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