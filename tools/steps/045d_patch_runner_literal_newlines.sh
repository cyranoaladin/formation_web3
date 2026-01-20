#!/usr/bin/env bash
# STEP 045d — patch_runner_literal_newlines (CODE CHANGE)
# But: remplacer les sauts de ligne littéraux dans les chaînes par des \n échappés

set -euo pipefail

TS=$(date +%Y%m%d_%H%M%S)
LOG="tools/logs/045d_runner_patch_${TS}.txt"
mkdir -p tools/logs

RUNNER_MOD="runner/minimal.py"
FIXTURE="tests/fixtures/minimal.zip"
SANDBOX="/tmp/rbk_sandbox_045d"

sha() { if [[ -f "$1" ]]; then sha256sum "$1" | awk '{print $1}'; else echo "(absent)"; fi }

{
  echo "[INFO] STEP 045d @ ${TS}"
  echo "== SHA BEFORE =="
  echo "runner/minimal.py: $(sha "$RUNNER_MOD")"

  echo
  echo "== PATCH file in-place =="
  python3 - <<'PY'
from pathlib import Path
p=Path('runner/minimal.py')
s=p.read_text(encoding='utf-8')
# Replace the problematic sequences exactly as observed
s=s.replace('"\n" + (proc.stdout or "")','"\\n" + (proc.stdout or "")')
s=s.replace('"\n[stderr]\n" + proc.stderr','"\\n[stderr]\\n" + proc.stderr')
# Also handle case where the newline is split across lines
s=s.replace('"\n\n"','"\\n\\n"')
# If still multi-line literal, forcibly rewrite the block
if 'logs = "$ " + cmd + "\n"' not in s:
    s=s.replace('logs = "$ " + cmd + "\n" + (proc.stdout or "")','logs = "$ " + cmd + "\\n" + (proc.stdout or "")')
    s=s.replace('logs += "\n[stderr]\n" + proc.stderr','logs += "\\n[stderr]\\n" + proc.stderr')
# Fallback: normalize any occurrences of a closing quote followed by newline and quote
s=s.replace('"\n"\n"','"\\n""')
Path('runner/minimal.py').write_text(s, encoding='utf-8')
print('RUNNER_NEWLINES_PATCHED=1')
PY

  echo
  echo "== SHA AFTER =="
  echo "runner/minimal.py: $(sha "$RUNNER_MOD")"

  echo
  echo "== RUN runner on fixture =="
  if [[ ! -f "$FIXTURE" ]]; then echo "(fixture missing) $FIXTURE"; exit 2; fi
  rm -rf "$SANDBOX" || true
  python3 -m runner.minimal --lab-id hello-proof --submission-id sub_045d_demo --zip "$FIXTURE" --sandbox "$SANDBOX" | sed -n '1,200p'

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