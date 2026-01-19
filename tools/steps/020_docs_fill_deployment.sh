#!/usr/bin/env bash
set -euo pipefail

mkdir -p tools/logs
TS="$(date +%Y%m%d_%H%M%S)"
LOG="tools/logs/docs_fix_deployment_fill_${TS}.txt"

echo "STEP=020 deployment fill minimal instructions" | tee "$LOG" >/dev/null
sha() { sha256sum "$1" | awk '{print $1}'; }

PRE=$(sha DEPLOYMENT.md)
echo "PRE DEPLOYMENT.md ${PRE}" | tee -a "$LOG" >/dev/null

python3 - <<'PY' | tee -a "$LOG" >/dev/null
import re, sys, os
p='DEPLOYMENT.md'
with open(p,encoding='utf-8') as f:
    t=f.read()

changed=False
updated=[]

H2=re.compile(r'(?im)^##\s*([^\n]+)\s*$')

def sec_range(txt,title):
    # match header line even if inline text trails the title
    m=re.search(rf'(?im)^(##\s*{re.escape(title)}\b.*)$', txt)
    if not m:
        return None
    header_line=m.group(1)
    s=m.end()
    # move start past trailing newline if present
    if s < len(txt) and txt[s:s+1]=='\n':
        s += 1
    n=re.search(r'(?im)^##\s+[^#].*$', txt[s:])
    e=s+(n.start() if n else len(txt[s:]))
    bad_inline = not re.match(rf'(?im)^##\s*{re.escape(title)}\s*$', header_line)
    return (m.start(), s, e, bad_inline)

def ensure_body(txt,title, body_lines):
    global changed
    r=sec_range(txt,title)
    if not r:
        return txt
    hs, s, e, bad_inline = r
    seg=txt[s:e]
    # If TODO placeholder present, empty, or header had inline content, replace with canonical body
    has_todo = re.search(r'(?im)^\s*TODO\s*:', seg) is not None
    non_heading=[ln for ln in seg.splitlines() if ln.strip() and not ln.strip().startswith('#')]
    canonical='\n'.join(body_lines).rstrip()+"\n"
    if has_todo or not non_heading or bad_inline:
        # rewrite header if inline content polluted the header line
        if bad_inline:
            txt = txt[:hs] + f"## {title}\n" + canonical + txt[e:]
        else:
            txt = txt[:s] + canonical + txt[e:]
        changed=True
        updated.append(f"REPLACED {title}")
        return txt
    # Otherwise, append missing lines idempotently
    for line in body_lines:
        if not re.search(rf'(?m)^{re.escape(line)}\s*$', seg):
            seg = (seg.rstrip()+"\n"+line+"\n")
            changed=True
            updated.append(f"ADDED line in {title}: {line}")
    return txt[:s]+seg+txt[e:]

# Normalize malformed headers with inline content
for title in ("Prerequisites","Local","Server","Rollback"):
    t2 = re.sub(rf'(?im)^##\s*{re.escape(title)}(\S.+)$', rf'## {title}\n\1', t)
    if t2 != t:
        t = t2; changed=True; updated.append(f"NORMALIZED header {title}")
# targeted fixes for previously malformed lines
_t = re.sub(r'(?im)^##\s*Localcommandes\s*:', '## Local\ncommandes :', t)
if _t != t:
    t = _t; changed=True; updated.append("NORMALIZED header Local (commandes)")
_t = re.sub(r'(?im)^##\s*Rollback```', '## Rollback\n```', t)
if _t != t:
    t = _t; changed=True; updated.append("NORMALIZED header Rollback (code fence)")

# Canonical bodies
prereq=[
"- Docker installé",
"- Docker Compose installé",
"- (optionnel) curl pour tester",
]
local=[
"commandes :",
"```bash",
"docker compose up -d --build",
"docker compose ps",
"```",
"",
"tests :",
"```bash",
"curl -sS http://localhost:8000/health",
"curl -sS http://localhost:3000/  # optionnel (UI dev)",
"```",
]
server=[
"- Ouvrir les ports 8000 et 3000",
"- Se positionner dans le répertoire du dépôt",
"",
"```bash",
"docker compose up -d --build",
"docker compose ps",
"```",
]
rollback=[
"```bash",
"docker compose down",
"docker image ls | head  # optionnel",
"```",
"",
"- Rollback simple = revenir au commit précédent et rebuild :",
"```bash",
"git checkout <commit>",
"docker compose up -d --build",
"```",
]

for title, body in (
    ("Prerequisites", prereq),
    ("Local", local),
    ("Server", server),
    ("Rollback", rollback),
):
    t=ensure_body(t,title,body)

if changed:
    with open(p,'w',encoding='utf-8') as f:
        f.write(t)
print("UPDATED:")
for u in updated:
    print("- "+u)
print(f"CHANGED={int(changed)}")
PY

POST=$(sha DEPLOYMENT.md)
echo "POST DEPLOYMENT.md ${POST}" | tee -a "$LOG" >/dev/null

echo "REPORT=$LOG" | tee -a "$LOG" >/dev/null
