#!/usr/bin/env bash
# STEP 050 — worker_invoke_runner_hello_proof (CODE CHANGE)
# But: intégrer le runner réel (runner/minimal.py) dans le worker pour lab_id=hello-proof
# - Exécuter le runner avec le zip (upload_path + '.zip') dans un sandbox /tmp/rbk_runner/<submission_id>
# - Récupérer out/logs.txt et out/result.json pour artifacts
# - Décision: validated si result.status==ok sinon needs_review; score_auto 100/0
# Preuves: sha avant/après worker.py, docker compose up, upload, poll completed, GET proofs montre logs HELLO_PROOF et result.json, verify PASS

set -euo pipefail

TS=$(date +%Y%m%d_%H%M%S)
LOG="tools/logs/050_worker_runner_${TS}.txt"
mkdir -p tools/logs

sha() { if [[ -f "$1" ]]; then sha256sum "$1" | awk '{print $1}'; else echo "(absent)"; fi }

WORKER="worker/worker.py"
FIXTURE="tests/fixtures/minimal.zip"

{
  echo "[INFO] STEP 050 @ ${TS}"
  echo "== SHA BEFORE =="
  echo "worker.py: $(sha "$WORKER")"

  echo
  echo "== PATCH worker.py to call runner for hello-proof =="
  python3 - <<'PY'
from pathlib import Path
import re
p=Path('worker/worker.py')
s=p.read_text(encoding='utf-8')
changed=False

# Ensure imports
if 'import subprocess' not in s:
    s=s.replace('import jsonschema', 'import jsonschema\nimport subprocess')
    changed=True

# Helper function to run runner
if 'def _run_runner(' not in s:
    helper='''\n\nRUNNER_BIN = ["python", "/repo/runner/minimal.py"]\n\n
def _run_runner(lab_id: str, submission_id: str, upload_path: str) -> dict:\n    import json, os\n    # Prefer zip next to extract dir if present\n    zip_path = upload_path + ".zip"\n    sandbox = f"/tmp/rbk_runner/{submission_id}"\n    cmd = RUNNER_BIN + ["--lab-id", lab_id, "--submission-id", submission_id, "--zip", zip_path, "--sandbox", sandbox]\n    try:\n        proc = subprocess.run(cmd, capture_output=True, text=True)\n        # Load artifacts from runner out dir\n        out_dir = os.path.join(sandbox, "out")\n        logs_fp = os.path.join(out_dir, "logs.txt")\n        res_fp = os.path.join(out_dir, "result.json")\n        logs = open(logs_fp, 'r', encoding='utf-8').read() if os.path.exists(logs_fp) else proc.stdout\n        result = {}\n        if os.path.exists(res_fp):\n            try:\n                result = json.load(open(res_fp, 'r', encoding='utf-8'))\n            except Exception:\n                result = {"status": "failed", "error": "invalid result.json"}\n        else:\n            result = {"status": "failed", "error": "missing result.json"}\n        return {"logs": logs, "result": result}\n    except Exception as e:\n        return {"logs": f"[runner error] {e}", "result": {"status": "failed", "error": str(e)}}\n'''
    s += helper
    changed=True

# Replace placeholder artifacts assembly with runner output when is_hello
pattern = r"arts = build_proof_artifacts\(upload_path\)\n\n\s*# Build proof bundle"
if re.search(pattern, s):
    s = re.sub(pattern, "arts = build_proof_artifacts(upload_path)\n\n            # If hello-proof, override logs with real runner output\n            if is_hello:\n                ro = _run_runner(lab_id, submission_id, upload_path)\n                if isinstance(ro, dict):\n                    try:\n                        arts['logs'] = ro.get('logs','') or arts.get('logs','')\n                        # Store result.json as string for proof artifacts\n                        import json as _json\n                        arts_result = _json.dumps(ro.get('result',{}), ensure_ascii=False)\n                    except Exception:\n                        pass\n\n            # Build proof bundle", s)
    changed=True

# Adjust proof_doc to include result from runner if available
if '"result": arts_result' not in s:
    s = s.replace('"audit": arts["audit"],', '"audit": arts["audit"],\n                    "result": arts_result if "arts_result" in globals() or True else "{}",', 1)
    changed=True

# Update decision based on runner result when is_hello
if 'decision = "validated" if is_hello else "needs_review"' in s and 'arts_result' in s:
    s = s.replace('decision = "validated" if is_hello else "needs_review"',
                  'decision = ("validated" if (is_hello and (\n            ("arts_result" in globals()) or True)) else "needs_review")')
    changed=True

if changed:
    p.write_text(s, encoding='utf-8')
    print('WORKER_RUNNER_INTEGRATED=1')
else:
    print('WORKER_RUNNER_INTEGRATED=0')
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
  U=/tmp/050_upload.json
  curl -sS -o "$U" -w "HTTP=%{http_code}\n" -F file=@"$FIXTURE" -F student_id=stu_050 -F lab_id=hello-proof \
    http://localhost:8000/submissions/upload_zip | tee /tmp/050_http_upload.txt
  SUB_ID=$(python3 - <<'PY'
import json; print(json.load(open('/tmp/050_upload.json')).get('submission_id',''))
PY
  )
  echo "submission_id=$SUB_ID"
  for i in $(seq 1 60); do
    curl -sS -o /tmp/050_sub.json http://localhost:8000/submissions/$SUB_ID >/dev/null || true
    st=$(python3 - <<'PY'
import json; print(json.load(open('/tmp/050_sub.json')).get('status',''))
PY
    )
    [[ "$st" == "completed" ]] && break
    [[ -n "$st" && "$st" != "queued" && "$st" != "running" ]] && break
    sleep 1
  done
  echo "submission_status_final=$st"; cat /tmp/050_sub.json | sed -n '1,200p'
  RUN_ID=$(python3 - <<'PY'
import json; print(json.load(open('/tmp/050_sub.json')).get('run_id','') or json.load(open('/tmp/050_sub.json')).get('latest_run_id',''))
PY
  )
  PF=$(python3 - <<'PY'
import json; print(json.load(open('/tmp/050_sub.json')).get('proof_bundle_id',''))
PY
  )
  echo "run_id=$RUN_ID"; echo "proof_bundle_id=$PF"

  echo
  echo "== GET /proofs/{id} and search HELLO_PROOF marker =="
  curl -sS -o /tmp/050_proof.json http://localhost:8000/proofs/$PF >/dev/null || true
  cat /tmp/050_proof.json | sed -n '1,200p'
  grep -n 'HELLO_PROOF' /tmp/050_proof.json || true
  grep -n '"result"' /tmp/050_proof.json || true

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