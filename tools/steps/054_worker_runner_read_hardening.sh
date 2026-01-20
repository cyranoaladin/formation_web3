#!/usr/bin/env bash
# STEP 054 — worker_runner_read_hardening (CODE CHANGE)
# Harden worker/worker.py to read out/result.json + out/logs.txt and fallback properly.

set -euo pipefail

TARGET="worker/worker.py"
TS=$(date +%Y%m%d_%H%M%S)
LOG_FILE="tools/logs/step_054_worker_hardening_${TS}.txt"
mkdir -p tools/logs

{
  echo "[INFO] STEP 054 @ ${TS}"

  echo "== A) Patch worker/worker.py =="
  echo "Before SHA256: $(sha256sum $TARGET)"

  # We use python to robustly replace the logic inside 'if is_hello:' block
  cat << 'EOF' > tools/patch_054.py
import sys
from pathlib import Path

target = Path('worker/worker.py')
content = target.read_text(encoding='utf-8')

# We want to replace the logic inside 'if is_hello:' 
# Current state (approx):
#             arts_result = "{}"
#             files_count_calc = len(arts.get("files", []))
#             if is_hello:
#                 ro = _run_runner(lab_id, submission_id, upload_path)
#                 ... (patched block 052) ...
#                 except Exception:
#                     files_count_calc = len(arts.get('files', []))
#
#             # result from runner or default kept

# Identifiers for the start and end of the block to replace
start_marker = '            if is_hello:'
end_marker = '            # result from runner or default kept'

if start_marker not in content or end_marker not in content:
    print("[ERROR] Could not find start or end marker for patching.")
    sys.exit(1)

pre = content.split(start_marker)[0]
post = content.split(end_marker)[1]

# New robust logic
new_block = """            if is_hello:
                ro = _run_runner(lab_id, submission_id, upload_path)
                
                runner_logs = ""
                runner_result_str = "{}"
                
                # 1. Try to get from returned object
                if isinstance(ro, dict):
                    runner_logs = ro.get('logs', "")
                    res_obj = ro.get('result')
                    if res_obj:
                        import json as _json
                        runner_result_str = _json.dumps(res_obj, ensure_ascii=False)

                # 2. Hardening: Fallback to reading files from sandbox if missing
                try:
                    from pathlib import Path as _P
                    _sb = _P(f"/tmp/rbk_runner/{submission_id}")
                    _out_logs = _sb / "out" / "logs.txt"
                    _out_res = _sb / "out" / "result.json"
                    
                    if not runner_logs and _out_logs.exists():
                        runner_logs = _out_logs.read_text(encoding='utf-8', errors='replace')
                    
                    if (not runner_result_str or runner_result_str == "{}") and _out_res.exists():
                        runner_result_str = _out_res.read_text(encoding='utf-8', errors='replace')
                except Exception:
                    pass

                # 3. Final Fallback if result still missing
                if not runner_result_str or runner_result_str == "{}":
                    runner_result_str = '{"status":"failed","error":"missing result.json"}'
                    runner_logs += "\\n[worker] runner missing result.json"

                # 4. Assign outputs
                arts['logs'] = runner_logs if runner_logs else "[worker] no runner logs captured"
                arts_result = runner_result_str
                
                # 5. Derive decision from result (parsing it back)
                try:
                    import json as _json
                    _res_parsed = _json.loads(runner_result_str)
                    if _res_parsed.get('status') == 'ok':
                        decision = 'validated'
                except Exception:
                    pass

                # 6. Files Count Computation (Sandbox Robustness)
                try:
                    from pathlib import Path as _P
                    _sb = _P(f"/tmp/rbk_runner/{submission_id}")
                    files_count_calc = 0
                    if _sb.exists():
                        for _fp in _sb.rglob('*'):
                            if _fp.is_file():
                                if 'out/' in str(_fp) or str(_fp).endswith('/out'): continue
                                if _fp.suffix == '.zip': continue
                                files_count_calc += 1
                except Exception:
                    files_count_calc = len(arts.get('files', []))
"""

new_content = pre + start_marker + "\n" + new_block + "\n" + end_marker + post
target.write_text(new_content, encoding='utf-8')
EOF

  python3 tools/patch_054.py
  rm tools/patch_054.py

  echo "After SHA256: $(sha256sum $TARGET)"

  echo
  echo "== B) Grep Verification =="
  echo "Check out/logs.txt reading:"
  grep -n "_out_logs.read_text" "$TARGET"
  echo "Check out/result.json reading:"
  grep -n "_out_res.read_text" "$TARGET"
  echo "Check validation logic:"
  grep -n "decision = 'validated'" "$TARGET"
  echo "Check files_count:"
  grep -n "files_count_calc =" "$TARGET" | tail -n 5

  echo
  echo "== C) Rebuild Worker =="
  docker compose up -d --build worker 2>&1 | sed 's/^/  [docker] /'

  echo
  echo "== D) Verify Harness =="
  bash tools/verify.sh --spec tools/verify.spec

} | tee "$LOG_FILE"
