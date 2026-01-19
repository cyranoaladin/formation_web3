#!/usr/bin/env bash
set -euo pipefail

mkdir -p tools/logs
TS="$(date +%Y%m%d_%H%M%S)"
LOG="tools/logs/docs_fix_deployment_sections_${TS}.txt"

echo "STEP=019 deployment add sections" | tee "$LOG" >/dev/null
sha() { sha256sum "$1" | awk '{print $1}'; }

PRE=$(sha DEPLOYMENT.md)
echo "PRE DEPLOYMENT.md ${PRE}" | tee -a "$LOG" >/dev/null

python3 - <<'PY' | tee -a "$LOG" >/dev/null
import re, os
p='DEPLOYMENT.md'
t=open(p,encoding='utf-8').read() if os.path.exists(p) else ''
changed=False

# Ensure H1 exists (do not force rename if a different H1 exists)
if not re.search(r'(?m)^#\s+.+$', t):
    t = '# Déploiement\n\n' + t
    changed=True

# Helper to check/add H2 sections idempotently
req = ['Prerequisites','Local','Server','Rollback']

def has_h2(txt,title):
    return re.search(rf'(?im)^##\s*{re.escape(title)}\b', txt) is not None

def append_section(txt,title):
    global changed
    block = f"\n\n## {title}\n\nTODO: à compléter\n"
    txt = txt.rstrip()+block+"\n"
    changed=True
    return txt

for title in req:
    if not has_h2(t,title):
        t = append_section(t,title)

if changed:
    with open(p,'w',encoding='utf-8') as f:
        f.write(t)
print(f"CHANGED={int(changed)}")
PY

POST=$(sha DEPLOYMENT.md)
echo "POST DEPLOYMENT.md ${POST}" | tee -a "$LOG" >/dev/null

echo "REPORT=$LOG" | tee -a "$LOG" >/dev/null
