#!/usr/bin/env bash
# STEP 045a — fix_runner_newline_issue (CODE CHANGE)
# But: corriger l'erreur SyntaxError due aux sauts de ligne dans runner/minimal.py et re-valider

set -euo pipefail

TS=$(date +%Y%m%d_%H%M%S)
LOG="tools/logs/045a_runner_fix_${TS}.txt"
mkdir -p tools/logs

RUNNER_MOD="runner/minimal.py"
FIXTURE="tests/fixtures/minimal.zip"
SANDBOX="/tmp/rbk_sandbox_045a"

sha() { if [[ -f "$1" ]]; then sha256sum "$1" | awk '{print $1}'; else echo "(absent)"; fi }

{
  echo "[INFO] STEP 045a @ ${TS}"
  echo "== SHA BEFORE =="
  echo "runner/minimal.py: $(sha "$RUNNER_MOD")"

  echo
  echo "== PATCH runner/minimal.py =="
  python3 - <<'PY'
from pathlib import Path
p=Path('runner/minimal.py')
s='''#!/usr/bin/env python3
from __future__ import annotations
import json, os, shutil, subprocess, sys, zipfile
from datetime import datetime
from pathlib import Path

ISO = lambda: datetime.utcnow().replace(microsecond=0).isoformat()+"Z"

def ensure_dir(d: Path) -> None:
    d.mkdir(parents=True, exist_ok=True)

def unzip_to(zip_path: Path, dest: Path) -> None:
    ensure_dir(dest)
    with zipfile.ZipFile(zip_path, 'r') as zf:
        zf.extractall(dest)

def execute_lab(lab_id: str, submission_id: str, zip_path: Path, sandbox: Path) -> dict:
    # Prepare sandbox
    if sandbox.exists():
        shutil.rmtree(sandbox)
    work = sandbox / 'work'
    out = sandbox / 'out'
    ensure_dir(work); ensure_dir(out)
    unzip_to(zip_path, work)

    # Determine command from spec if present; else built-in hello-proof
    spec_path = Path('labs/specs')/lab_id/'lab.json'
    cmd = None
    if spec_path.exists():
        try:
            spec=json.loads(spec_path.read_text(encoding='utf-8'))
            cmd=spec.get('command')
        except Exception:
            cmd=None
    if not cmd:
        cmd = "sh -lc 'echo hello-proof; echo sandbox=${PWD}'"

    # Run command and capture
    started=ISO()
    proc = subprocess.run(cmd, shell=True, cwd=str(work), capture_output=True, text=True)
    finished=ISO()

    logs = f"$ {cmd}\n" + (proc.stdout or '')
    if proc.stderr:
        logs += "\n[stderr]\n" + proc.stderr
    (out / 'logs.txt').write_text(logs, encoding='utf-8')

    result = {
        'status': 'ok' if proc.returncode==0 else 'failed',
        'lab_id': lab_id,
        'submission_id': submission_id,
        'started_at': started,
        'finished_at': finished,
        'returncode': proc.returncode,
    }
    (out / 'result.json').write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding='utf-8')
    return {'out_dir': str(out), 'work_dir': str(work), 'result': result}

if __name__ == '__main__':
    import argparse
    ap = argparse.ArgumentParser()
    ap.add_argument('--lab-id', required=True)
    ap.add_argument('--submission-id', required=True)
    ap.add_argument('--zip', required=True)
    ap.add_argument('--sandbox', required=True)
    a=ap.parse_args()
    info = execute_lab(a.lab_id, a.submission_id, Path(a.zip), Path(a.sandbox))
    print(json.dumps({'ok': True, **info}, ensure_ascii=False))
'''
Path('runner').mkdir(parents=True, exist_ok=True)
p.write_text(s, encoding='utf-8')
print('RUNNER_FIXED=1')
PY

  echo
  echo "== SHA AFTER =="
  echo "runner/minimal.py: $(sha "$RUNNER_MOD")"

  echo
  echo "== RUN runner on fixture =="
  if [[ ! -f "$FIXTURE" ]]; then echo "(fixture missing) $FIXTURE"; exit 2; fi
  rm -rf "$SANDBOX" || true
  python3 -m runner.minimal --lab-id hello-proof --submission-id sub_045a_demo --zip "$FIXTURE" --sandbox "$SANDBOX" | sed -n '1,200p'

  echo
  echo "== LIST artifacts =="
  ls -la "$SANDBOX/out" | sed -n '1,200p'
  echo "-- logs.txt (head) --"; sed -n '1,40p' "$SANDBOX/out/logs.txt"
  echo "-- result.json --"; cat "$SANDBOX/out/result.json"

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