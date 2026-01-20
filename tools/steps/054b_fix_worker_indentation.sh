#!/usr/bin/env bash
# STEP 054b — fix_worker_indentation (HOTFIX)
# Fixes duplicated 'if is_hello:' line in worker.py introduced by step 054.

set -euo pipefail

TARGET="worker/worker.py"
TS=$(date +%Y%m%d_%H%M%S)
LOG_FILE="tools/logs/step_054b_fix_indent_${TS}.txt"
mkdir -p tools/logs

{
  echo "[INFO] STEP 054b @ ${TS}"
  echo "Before SHA256: $(sha256sum $TARGET)"

  # Remove the duplicate line 165 if it matches 'if is_hello:' logic
  # We use a careful python script to remove the SECOND occurrence if they are adjacent
  python3 -c "
from pathlib import Path
p = Path('$TARGET')
lines = p.read_text(encoding='utf-8').splitlines()
new_lines = []
for i, line in enumerate(lines):
    # Detect duplicate adjacent 'if is_hello:' lines
    if i > 0 and 'if is_hello:' in line and 'if is_hello:' in lines[i-1] and line.strip() == lines[i-1].strip():
        print(f'Removing duplicate line {i+1}: {line}')
        continue
    new_lines.append(line)
p.write_text('\n'.join(new_lines) + '\n', encoding='utf-8')
"

  echo "After SHA256: $(sha256sum $TARGET)"

  echo "== Verify =="
  grep -n "if is_hello:" "$TARGET"

  echo "== Rebuild Worker =="
  docker compose up -d --build worker

} | tee "$LOG_FILE"
