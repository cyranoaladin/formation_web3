#!/usr/bin/env bash
set -euo pipefail

mkdir -p tools/logs
TS="$(date +%Y%m%d_%H%M%S)"
LOG="tools/logs/docs_fix_operations_fill_${TS}.txt"

echo "STEP=023 operations fill runbook+logs" | tee "$LOG" >/dev/null
sha() { sha256sum "$1" | awk '{print $1}'; }

PRE=$(sha OPERATIONS.md)
echo "PRE OPERATIONS.md ${PRE}" | tee -a "$LOG" >/dev/null

python3 - <<'PY' | tee -a "$LOG" >/dev/null
import re
p='OPERATIONS.md'
with open(p,encoding='utf-8') as f:
    t=f.read()
changed=False
flag={'changed':False}

RUNBOOK_LINES=[
    "- Vérifier l’état global :",
    "  docker compose ps",
    "- Vérifier la santé API :",
    "  curl -sS http://localhost:8000/health",
    "- Redémarrage ciblé :",
    "  docker compose restart api",
    "  docker compose restart worker",
    "- Redémarrage complet :",
    "  docker compose down",
    "  docker compose up -d --build",
]
LOGS_LINES=[
    "- Logs globaux :",
    "  docker compose logs --tail=100",
    "- Logs par service :",
    "  docker compose logs api",
    "  docker compose logs worker",
    "  docker compose logs ui",
]

H2=re.compile(r'(?im)^##\s*([^\n]+)\s*$')

def sec_range(txt,title):
    m=re.search(rf'(?im)^##\s*{re.escape(title)}\b', txt)
    if not m:
        return None
    s=m.end()
    nxt=re.search(r'(?im)^##\s+[^#].*$', txt[s:])
    e=s+(nxt.start() if nxt else len(txt[s:]))
    return s,e

def fill_section(txt,title,lines):
    global changed
    r=sec_range(txt,title)
    if not r:
        return txt
    s,e=r
    # Fix malformed header lines like '## Title- text' by rewriting header + moving remainder into body
    header_pat = rf'(?m)^(##\s*{re.escape(title)})(\S.*)$'
    def _fix_header(m):
        flag['changed']=True
        return m.group(1) + "\n" + m.group(2)
    txt = re.sub(header_pat, _fix_header, txt)
    if flag['changed']:
        changed=True
    # recompute range after potential header fix
    s,e = sec_range(txt,title)
    body=txt[s:e]
    # If empty (no non-heading text), replace by canonical
    non_heading=[ln for ln in body.splitlines() if ln.strip() and not ln.strip().startswith('#')]
    if not non_heading:
        new_body='\n'.join(lines).rstrip()+"\n"
        txt=txt[:s]+new_body+txt[e:]
        changed=True
        return txt
    # else, append only missing lines idempotently in order
    for line in lines:
        if not re.search(rf'(?m)^{re.escape(line)}\s*$', body):
            body=body.rstrip()+"\n"+line+"\n"
            changed=True
    return txt[:s]+body+txt[e:]

# Ensure both sections are filled
for title, lines in (("Runbook", RUNBOOK_LINES),("Logs", LOGS_LINES)):
    t=fill_section(t,title,lines)

if changed:
    with open(p,'w',encoding='utf-8') as f:
        f.write(t)
print(f"CHANGED={int(changed)}")
PY

POST=$(sha OPERATIONS.md)
echo "POST OPERATIONS.md ${POST}" | tee -a "$LOG" >/dev/null

echo "REPORT=$LOG" | tee -a "$LOG" >/dev/null
