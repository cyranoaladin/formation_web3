#!/usr/bin/env bash
set -euo pipefail

mkdir -p tools/logs
TS="$(date +%Y%m%d_%H%M%S)"
LOG="tools/logs/docs_fix_operations_sections_${TS}.txt"

echo "STEP=022 operations add sections" | tee "$LOG" >/dev/null
sha() { sha256sum "$1" | awk '{print $1}'; }

PRE=$(sha OPERATIONS.md)
echo "PRE OPERATIONS.md ${PRE}" | tee -a "$LOG" >/dev/null

python3 - <<'PY' | tee -a "$LOG" >/dev/null
import os,re
p='OPERATIONS.md'
with open(p,encoding='utf-8') as f:
    t=f.read()
changed=False

def ensure_h2(text,title):
    global changed
    if re.search(rf'(?im)^##\s*{re.escape(title)}\b', text):
        return text
    text = text.rstrip()+f"\n\n## {title}\n"
    changed=True
    return text

t = ensure_h2(t,'Runbook')
t = ensure_h2(t,'Logs')
if changed:
    with open(p,'w',encoding='utf-8') as f:
        f.write(t)
print(f"CHANGED={int(changed)}")
PY

POST=$(sha OPERATIONS.md)
echo "POST OPERATIONS.md ${POST}" | tee -a "$LOG" >/dev/null

echo "REPORT=$LOG" | tee -a "$LOG" >/dev/null
