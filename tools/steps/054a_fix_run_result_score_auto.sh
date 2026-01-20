#!/usr/bin/env bash
# Step 054a — fix_run_result_score_auto
# Goal: Ensure run.result.score_auto reflects score_auto_val (100 for hello-proof) instead of hardcoded 50.
# Proofs: rebuild worker, run hello-proof upload, assert run.result.score_auto=100 and decision_hint=validated.

set -euo pipefail

python3 - <<'PY'
from pathlib import Path
p=Path('worker/worker.py')
s=p.read_text(encoding='utf-8')
changed=False
old='"result": {"ok": True, "decision_hint": decision, "score_auto": 50, '
new='"result": {"ok": True, "decision_hint": decision, "score_auto": score_auto_val, '
if old in s:
    s=s.replace(old,new)
    changed=True
if changed:
    p.write_text(s, encoding='utf-8')
    print('RUN_RESULT_SCORE_PATCHED=1')
else:
    print('RUN_RESULT_SCORE_PATCHED=0')
PY

echo "--- docker compose up -d --build worker ---"
docker compose up -d --build worker

echo "--- HELLO-PROOF RECHECK ---"
HELLO_OUT=/tmp/upl_054a_hello.json
curl -sS -o "$HELLO_OUT" -w "HTTP=%{http_code}\n" \
  -F file=@tests/fixtures/minimal.zip -F student_id=stu_hello_a -F lab_id=hello-proof \
  http://localhost:8000/submissions/upload_zip
cat "$HELLO_OUT"; echo
HELLO_SUB=$(python3 - <<'PY'
import json
print(json.load(open('/tmp/upl_054a_hello.json')).get('submission_id',''))
PY
)

for i in $(seq 1 90); do
  curl -sS -o /tmp/sub_054a_hello.json http://localhost:8000/submissions/$HELLO_SUB >/dev/null || true
  st=$(python3 - <<'PY'
import json
print(json.load(open('/tmp/sub_054a_hello.json')).get('status',''))
PY
)
  [[ "$st" != "queued" && "$st" != "running" && -n "$st" ]] && break
  sleep 1
done

echo "FINAL_STATUS_HELLO_A=$st"; cat /tmp/sub_054a_hello.json; echo
HELLO_RUN=$(python3 - <<'PY'
import json
print(json.load(open('/tmp/sub_054a_hello.json')).get('latest_run_id',''))
PY
)

curl -sS -o /tmp/run_054a_hello.json http://localhost:8000/runs/$HELLO_RUN >/dev/null || true
HELLO_RS=$(python3 - <<'PY'
import json
r=json.load(open('/tmp/run_054a_hello.json'))
print(r.get('status',''), r.get('result',{}).get('decision_hint',''), r.get('result',{}).get('score_auto',''))
PY
)
echo "RUN_HELLO_A_SUMMARY=$HELLO_RS"

python3 - <<'PY'
import json, sys
hello = json.load(open('/tmp/run_054a_hello.json'))
print('ASSERT_HELLO_A_VALIDATED=%s' % (hello.get('status')=='completed' and hello.get('result',{}).get('decision_hint')=='validated' and hello.get('result',{}).get('score_auto')==100))
PY

# Tail worker logs for context
echo "--- docker compose logs --tail=120 worker ---"
docker compose logs --tail=120 worker || true

# Git status for traceability
echo "--- git status --porcelain ---"
git status --porcelain | sed -n '1,200p'
