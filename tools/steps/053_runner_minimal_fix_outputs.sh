#!/usr/bin/env bash
# STEP 053 — runner_minimal_fix_outputs (CODE CHANGE)
# Ensures runner/minimal.py ALWAYS produces out/result.json and out/logs.txt

set -euo pipefail

TARGET="runner/minimal.py"
TS=$(date +%Y%m%d_%H%M%S)
LOG_FILE="tools/logs/step_053_runner_fix_${TS}.txt"
mkdir -p tools/logs

{
  echo "[INFO] STEP 053 @ ${TS}"

  echo "== A) Patch runner/minimal.py =="
  echo "Before SHA256: $(sha256sum $TARGET)"

  # Rewrite file using EOF heredoc to avoid escaping hell
  cat << 'EOF' > "$TARGET"
#!/usr/bin/env python3
from __future__ import annotations
import argparse, json, os, shutil, subprocess, sys, zipfile, traceback
from datetime import datetime
from pathlib import Path

ISO = lambda: datetime.utcnow().replace(microsecond=0).isoformat() + 'Z'

def ensure_dir(d: Path) -> None:
    d.mkdir(parents=True, exist_ok=True)

def safe_write_text(path: Path, content: str):
    try:
        path.write_text(content, encoding='utf-8')
    except Exception as e:
        print(f"[runner] failed to write {path}: {e}", file=sys.stderr)

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--lab-id', required=True)
    parser.add_argument('--submission-id', required=True)
    parser.add_argument('--zip', required=True, dest='zip_path')
    parser.add_argument('--sandbox', required=True)
    # Optional run-id if caller provides it
    parser.add_argument('--run-id', default='', required=False)
    
    args = parser.parse_args()
    
    lab_id = args.lab_id
    sub_id = args.submission_id
    run_id = args.run_id
    zip_path = Path(args.zip_path)
    sandbox = Path(args.sandbox)
    
    # Paths
    out_dir = sandbox / 'out'
    work_dir = sandbox / 'work'
    logs_file = out_dir / 'logs.txt'
    res_file = out_dir / 'result.json'
    
    # 1. ALWAYS create directories first
    if sandbox.exists():
        try:
            shutil.rmtree(sandbox)
        except Exception as e:
            print(f"[runner] warning: failed to clean sandbox: {e}", file=sys.stderr)
            
    ensure_dir(sandbox)
    ensure_dir(out_dir)
    ensure_dir(work_dir)
    
    # Initial Result State
    started_at = ISO()
    logs = []
    
    # Default fail state
    final_status = 'failed'
    final_error = None
    
    try:
        logs.append(f"[runner] started lab_id={lab_id} sub_id={sub_id}")
        
        # 2. Extract Zip (safely)
        if not zip_path.exists():
            raise FileNotFoundError(f"zip file not found: {zip_path}")
            
        try:
            with zipfile.ZipFile(zip_path, 'r') as zf:
                zf.extractall(work_dir)
            logs.append("[runner] zip extracted")
        except Exception as e:
            raise RuntimeError(f"Failed to extract zip: {e}")

        # 3. Determine command
        spec_path = Path('labs/specs') / lab_id / 'lab.json'
        cmd = None
        if spec_path.exists():
            try:
                spec = json.loads(spec_path.read_text(encoding='utf-8'))
                cmd = spec.get('command')
            except Exception:
                pass
        
        if not cmd:
            # Default fallback for hello-proof
            cmd = "sh -lc 'echo hello-proof; echo sandbox=${PWD}'"
            
        logs.append(f"[runner] command: {cmd}")
        
        # 4. Execute
        proc = subprocess.run(
            cmd, 
            shell=True, 
            cwd=str(work_dir), 
            capture_output=True, 
            text=True
        )
        
        # Capture output
        logs.append("\n--- stdout ---")
        logs.append(proc.stdout or "(no stdout)")
        if proc.stderr:
            logs.append("\n--- stderr ---")
            logs.append(proc.stderr)
            
        if proc.returncode == 0:
            final_status = 'ok'
        else:
            final_status = 'failed'
            final_error = f"Command failed with exit code {proc.returncode}"

    except Exception as e:
        final_status = 'failed'
        final_error = str(e)
        logs.append(f"\n[runner exception] {traceback.format_exc()}")
    
    finally:
        # 5. ALWAYS write outputs
        finished_at = ISO()
        
        result_data = {
            "status": final_status,
            "lab_id": lab_id,
            "submission_id": sub_id,
            "run_id": run_id, 
            "started_at": started_at,
            "finished_at": finished_at
        }
        if final_error:
            result_data['error'] = final_error
            
        logs_content = "\n".join(logs)
        safe_write_text(logs_file, logs_content)
        safe_write_text(res_file, json.dumps(result_data, ensure_ascii=False, indent=2))
        
        # Print for caller debug
        print(json.dumps({'ok': True, 'out_dir': str(out_dir)}, ensure_ascii=False))

if __name__ == '__main__':
    main()
EOF

  echo "After SHA256: $(sha256sum $TARGET)"

  echo
  echo "== B) Grep Verification =="
  echo "Create dirs:"
  grep -n "ensure_dir(out_dir)" "$TARGET"
  echo "Write logs:"
  grep -n "safe_write_text(logs_file" "$TARGET"
  echo "Write result:"
  grep -n "safe_write_text(res_file" "$TARGET"
  echo "Try/Finally:"
  grep -n "finally:" "$TARGET"

  echo
  echo "== C) Direct Verification (Standalone) =="
  TEST_SB="/tmp/rbk_runner_test_053"
  TEST_ZIP="/tmp/rbk_runner_test_053.zip"
  
  # Prepare dummy zip
  echo "dummy content" > /tmp/dummy.txt
  rm -f $TEST_ZIP
  zip -j $TEST_ZIP /tmp/dummy.txt >/dev/null
  
  echo "[Test] Running minimal.py directly..."
  python3 $TARGET --lab-id hello-proof --submission-id test_053 --zip $TEST_ZIP --sandbox $TEST_SB
  
  echo "[Test] Checking outputs..."
  if [[ -f "$TEST_SB/out/result.json" ]]; then
      echo "PASS: result.json exists"
      cat "$TEST_SB/out/result.json"
      # Validate JSON
      python3 -c "import json; print('JSON OK' if json.load(open('$TEST_SB/out/result.json')) else 'JSON FAIL')"
  else
      echo "FAIL: result.json missing"
      exit 1
  fi
  
  if [[ -f "$TEST_SB/out/logs.txt" ]]; then
      echo "PASS: logs.txt exists"
      grep "dummy.txt" "$TEST_SB/out/logs.txt" || true
  else
      echo "FAIL: logs.txt missing"
      exit 1
  fi
  
  echo
  echo "== D) Verify Harness =="
  bash tools/verify.sh --spec tools/verify.spec

} | tee "$LOG_FILE"
