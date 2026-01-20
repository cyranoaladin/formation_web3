#!/usr/bin/env bash
# STEP 045 — runner_minimal_execute_lab (CODE CHANGE)
# But: implémenter un runner réellement exécutable pour un lab minimal (hello-proof)
# - Input: zip fixture
# - Output: artifacts: logs.txt, result.json (dans un sandbox tmp)
# Preuves: sha256 avant/après des fichiers modifiés, import/exec du runner, ls/cat des artefacts, verify PASS

set -euo pipefail

TS=$(date +%Y%m%d_%H%M%S)
LOG="tools/logs/045_runner_${TS}.txt"
mkdir -p tools/logs

sha() { if [[ -f "$1" ]]; then sha256sum "$1" | awk '{print $1}'; else echo "(absent)"; fi }

RUNNER_DIR="runner"
RUNNER_MOD="runner/minimal.py"
RUNNER_INIT="runner/__init__.py"
FIXTURE="tests/fixtures/minimal.zip"
SANDBOX="/tmp/rbk_sandbox_045"

{
  echo "[INFO] STEP 045 @ ${TS}"
  echo "== SHA BEFORE =="
  echo "runner/__init__.py: $(sha "$RUNNER_INIT")"
  echo "runner/minimal.py: $(sha "$RUNNER_MOD")"

  echo
  echo "== WRITE runner package (idempotent) =="
  mkdir -p "$RUNNER_DIR"

  # __init__.py minimal
  if [[ ! -f "$RUNNER_INIT" ]]; then
    echo "# runner package" > "$RUNNER_INIT"
  fi

  # Write/ensure minimal.py with execute_lab and CLI
  python3 - <<'PY'
from pathlib import Path
p=Path('runner/minimal.py')
need=True
if p.exists():
    s=p.read_text(encoding='utf-8')
    need = 'def execute_lab(' not in s or 'if __name__ == "__main__"' not in s

if need:
    p.write_text('''#!/usr/bin/env python3
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

    logs = ''
    logs += f"$ {cmd}\n"
    logs += proc.stdout or ''
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
''', encoding='utf-8')
    print('RUNNER_WRITTEN=1')
else:
    print('RUNNER_WRITTEN=0')
PY

  echo
  echo "== SHA AFTER =="
  echo "runner/__init__.py: $(sha "$RUNNER_INIT")"
  echo "runner/minimal.py: $(sha "$RUNNER_MOD")"

  echo
  echo "== PY import sanity =="
  python3 - <<'PY'
import sys
sys.path.insert(0,'.')
from runner.minimal import execute_lab
print('RUNNER_IMPORT_OK', execute_lab.__name__)
PY

  echo
  echo "== RUN runner on fixture =="
  if [[ ! -f "$FIXTURE" ]]; then echo "(fixture missing) $FIXTURE"; exit 2; fi
  rm -rf "$SANDBOX" || true
  python3 -m runner.minimal --lab-id hello-proof --submission-id sub_045_demo --zip "$FIXTURE" --sandbox "$SANDBOX" | sed -n '1,200p'

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