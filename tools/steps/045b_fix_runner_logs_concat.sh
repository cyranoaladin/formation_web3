#!/usr/bin/env bash
# STEP 045b — fix_runner_logs_concat (CODE CHANGE)
# But: corriger la concaténation des logs pour éviter EOL dans f-strings

set -euo pipefail

TS=$(date +%Y%m%d_%H%M%S)
LOG="tools/logs/045b_runner_fix_${TS}.txt"
mkdir -p tools/logs

RUNNER_MOD="runner/minimal.py"
FIXTURE="tests/fixtures/minimal.zip"
SANDBOX="/tmp/rbk_sandbox_045b"

sha() { if [[ -f "$1" ]]; then sha256sum "$1" | awk '{print $1}'; else echo "(absent)"; fi }

{
  echo "[INFO] STEP 045b @ ${TS}"
  echo "== SHA BEFORE =="
  echo "runner/minimal.py: $(sha "$RUNNER_MOD")"

  echo
  echo "== PATCH runner/minimal.py (logs concat) =="
  python3 - <<'PY'
from pathlib import Path
p=Path('runner/minimal.py')
s=p.read_text(encoding='utf-8')
s=s.replace('logs = f"$ {cmd}\\n" + (proc.stdout or \'\')', 'logs = "$ " + cmd + "\\n" + (proc.stdout or "")')
Path('runner/minimal.py').write_text(s, encoding='utf-8')
print('RUNNER_LOGS_CONCAT_FIXED=1')
PY

  echo
  echo "== SHA AFTER =="
  echo "runner/minimal.py: $(sha "$RUNNER_MOD")"

  echo
  echo "== RUN runner on fixture =="
  if [[ ! -f "$FIXTURE" ]]; then echo "(fixture missing) $FIXTURE"; exit 2; fi
  rm -rf "$SANDBOX" || true
  python3 -m runner.minimal --lab-id hello-proof --submission-id sub_045b_demo --zip "$FIXTURE" --sandbox "$SANDBOX" | sed -n '1,200p'

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