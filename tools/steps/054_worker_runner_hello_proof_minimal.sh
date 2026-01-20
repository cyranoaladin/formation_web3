#!/usr/bin/env bash
# Step 054 — worker_runner_hello_proof_minimal
# Goal: Make worker validate and auto-pass lab_id=hello-proof (decision=validated, score_auto=100),
#       keep default path (needs_review, score_auto=50) for others.
# Proofs: rebuild worker, run two uploads (hello-proof vs lab_demo), assert statuses and run results,
#         tail worker logs, show git status.

set -euo pipefail

# 1) Patch worker to set decision/score based on lab_id (idempotent textual patch)
python3 - <<'PY'
from pathlib import Path
p=Path('worker/worker.py')
s=p.read_text(encoding='utf-8')
changed=False

# Inject decision variables after lab_id/invalid
needle = 'invalid = (lab_id == "invalid_proof")\n        upload_path = sub.get("upload_path") or ""'
if needle in s and 'is_hello' not in s:
    s = s.replace(
        needle,
        'invalid = (lab_id == "invalid_proof")\n        is_hello = (lab_id == "hello-proof")\n        decision = "validated" if is_hello else "needs_review"\n        score_auto_val = 100 if is_hello else 50\n        upload_path = sub.get("upload_path") or ""'
    )
    changed=True

# Update proof_doc decision_hint and score.auto
if '"decision_hint": "needs_review"' in s:
    s = s.replace('"decision_hint": "needs_review"', '"decision_hint": decision')
    changed=True
if '"score": {"auto": 50, "rubric": "placeholder"}' in s:
    s = s.replace('"score": {"auto": 50, "rubric": "placeholder"}', '"score": {"auto": score_auto_val, "rubric": "placeholder"}')
    changed=True

# Update run result decision_hint and score_auto
if '"result": {"ok": True, "decision_hint": "needs_review", "score_auto": 50, ' in s:
    s = s.replace('"result": {"ok": True, "decision_hint": "needs_review", "score_auto": 50, ', '"result": {"ok": True, "decision_hint": decision, "score_auto": score_auto_val, ')
    changed=True

# Update final submission status based on lab_id
if '"$set": {"status": "needs_review", "updated_at": now()}' in s:
    s = s.replace('"$set": {"status": "needs_review", "updated_at": now()}', '"$set": {"status": ("validated" if is_hello else "needs_review"), "updated_at": now()}')
    changed=True

if changed:
    p.write_text(s, encoding='utf-8')
    print('WORKER_HELLO_PROOF_PATCHED=1')
else:
    print('WORKER_HELLO_PROOF_PATCHED=0')
PY

# 2) Rebuild worker only
echo "--- docker compose up -d --build worker ---"
docker compose up -d --build worker

# 3) Valid (hello-proof) flow
echo "--- VALIDATED PATH: lab_id=hello-proof ---"
HELLO_OUT=/tmp/upl_054_hello.json
curl -sS -o "$HELLO_OUT" -w "HTTP=%{http_code}\n" \
  -F file=@tests/fixtures/minimal.zip -F student_id=stu_hello -F lab_id=hello-proof \
  http://localhost:8000/submissions/upload_zip
cat "$HELLO_OUT"; echo
HELLO_SUB=$(python3 - <<'PY'
import json
print(json.load(open('/tmp/upl_054_hello.json')).get('submission_id',''))
PY
)

for i in $(seq 1 90); do
  curl -sS -o /tmp/sub_054_hello.json http://localhost:8000/submissions/$HELLO_SUB >/dev/null || true
  st=$(python3 - <<'PY'
import json
print(json.load(open('/tmp/sub_054_hello.json')).get('status',''))
PY
)
  [[ "$st" != "queued" && "$st" != "running" && -n "$st" ]] && break
  sleep 1
done

echo "FINAL_STATUS_HELLO=$st"; cat /tmp/sub_054_hello.json; echo
HELLO_RUN=$(python3 - <<'PY'
import json
print(json.load(open('/tmp/sub_054_hello.json')).get('latest_run_id',''))
PY
)

curl -sS -o /tmp/run_054_hello.json http://localhost:8000/runs/$HELLO_RUN >/dev/null || true
HELLO_RS=$(python3 - <<'PY'
import json
r=json.load(open('/tmp/run_054_hello.json'))
print(r.get('status',''), r.get('result',{}).get('decision_hint',''), r.get('result',{}).get('score_auto',''))
PY
)
echo "RUN_HELLO_SUMMARY=$HELLO_RS"

# 4) Control (lab_demo) path stays needs_review
echo "--- CONTROL PATH: lab_id=lab_demo ---"
CTRL_OUT=/tmp/upl_054_ctrl.json
curl -sS -o "$CTRL_OUT" -w "HTTP=%{http_code}\n" \
  -F file=@tests/fixtures/minimal.zip -F student_id=stu_ctrl -F lab_id=lab_demo \
  http://localhost:8000/submissions/upload_zip
cat "$CTRL_OUT"; echo
CTRL_SUB=$(python3 - <<'PY'
import json
print(json.load(open('/tmp/upl_054_ctrl.json')).get('submission_id',''))
PY
)

for i in $(seq 1 90); do
  curl -sS -o /tmp/sub_054_ctrl.json http://localhost:8000/submissions/$CTRL_SUB >/dev/null || true
  st=$(python3 - <<'PY'
import json
print(json.load(open('/tmp/sub_054_ctrl.json')).get('status',''))
PY
)
  [[ "$st" != "queued" && "$st" != "running" && -n "$st" ]] && break
  sleep 1
done

echo "FINAL_STATUS_CTRL=$st"; cat /tmp/sub_054_ctrl.json; echo
CTRL_RUN=$(python3 - <<'PY'
import json
print(json.load(open('/tmp/sub_054_ctrl.json')).get('latest_run_id',''))
PY
)

curl -sS -o /tmp/run_054_ctrl.json http://localhost:8000/runs/$CTRL_RUN >/dev/null || true
CTRL_RS=$(python3 - <<'PY'
import json
r=json.load(open('/tmp/run_054_ctrl.json'))
print(r.get('status',''), r.get('result',{}).get('decision_hint',''), r.get('result',{}).get('score_auto',''))
PY
)
echo "RUN_CTRL_SUMMARY=$CTRL_RS"

# 5) Assertions
python3 - <<'PY'
import json, sys
hello = json.load(open('/tmp/run_054_hello.json'))
ctrl = json.load(open('/tmp/run_054_ctrl.json'))

h_ok = (hello.get('status')=='completed' and hello.get('result',{}).get('decision_hint')=='validated' and hello.get('result',{}).get('score_auto')==100)
c_ok = (ctrl.get('status')=='completed' and ctrl.get('result',{}).get('decision_hint')=='needs_review' and ctrl.get('result',{}).get('score_auto')==50)

print('ASSERT_HELLO_VALIDATED_PASS=%s' % h_ok)
print('ASSERT_CTRL_NEEDS_REVIEW_PASS=%s' % c_ok)

if not (h_ok and c_ok):
    sys.exit(2)
PY

# 6) Worker logs
Echo="--- docker compose logs --tail=120 worker ---"

echo "$Echo"
docker compose logs --tail=120 worker || true

# 7) Git status for traceability
echo "--- git status --porcelain ---"
git status --porcelain | sed -n '1,200p'
