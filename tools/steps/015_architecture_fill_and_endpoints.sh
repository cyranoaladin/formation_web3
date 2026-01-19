#!/usr/bin/env bash
set -euo pipefail

mkdir -p tools/logs
TS="$(date +%Y%m%d_%H%M%S)"
LOG="tools/logs/docs_fix_architecture_${TS}.txt"

echo "STEP=015 architecture fill + endpoints" | tee "$LOG" >/dev/null
sha() { sha256sum "$1" | awk '{print $1}'; }

PRE=$(sha ARCHITECTURE.md)
echo "PRE ARCHITECTURE.md ${PRE}" | tee -a "$LOG" >/dev/null

python3 - <<'PY' | tee -a "$LOG" >/dev/null
import re
p='ARCHITECTURE.md'
with open(p,encoding='utf-8') as f:
    t=f.read()

added_sections=[]; endpoints_added=0; updated_sections=[]

# Ensure a level-2 section 'Architecture Technique' exists and is populated
m=re.search(r'(?im)^##\s*Architecture\s*Technique\b', t)
arch_block=(
    "\n\n## Architecture Technique\n"
    "### Composants\n- API\n- Worker\n- UI\n- Mongo\n"
    "\n### Orchestration\n- docker-compose.yml (Docker Compose)\n"
    "\n### Ports\n- API: 8000\n- UI: 3000\n"
    "\n### Flux d’exécution\n- upload_zip → queued → worker → run → proof_bundle\n"
)
if not m:
    # insert after top title if present, else append
    top=re.search(r'(?m)^#\s+.*$', t)
    if top:
        insert_at=top.end()
        t=t[:insert_at].rstrip()+arch_block+"\n"+t[insert_at:]
    else:
        t=t.rstrip()+arch_block+"\n"
    added_sections.append('Architecture Technique')
else:
    # If section exists but body is empty (no non-heading text), fill it
    start=m.end()
    nxt=re.search(r'(?im)^##\s+[^#].*$', t[start:])
    end=start+(nxt.start() if nxt else len(t[start:]))
    body=t[start:end]
    non_heading=[ln for ln in body.splitlines() if ln.strip() and not ln.strip().startswith('#')]
    if not non_heading:
        t=t[:start].rstrip()+arch_block+"\n"+t[end:]
        updated_sections.append('Architecture Technique')

# Ensure an 'Endpoints' section exists with required entries
req=["GET /health","POST /submissions/upload_zip","POST /rag/query"]
me=re.search(r'(?im)^##\s*Endpoints\b', t)
if not me:
    ep_block="\n\n## Endpoints\n"+"\n".join(req)+"\n"
    t=t.rstrip()+ep_block+"\n"
    endpoints_added=len(req)
else:
    s=me.end()
    nxt=re.search(r'(?im)^##\s+[^#].*$', t[s:])
    e=s+(nxt.start() if nxt else len(t[s:]))
    body=t[s:e]
    missing=[r for r in req if not re.search(rf'(?m)^{re.escape(r)}\b', body)]
    if missing:
        add="\n"+"\n".join(missing)+"\n"
        t=t[:e].rstrip()+add+"\n"+t[e:]
        endpoints_added=len(missing)

with open(p,'w',encoding='utf-8') as f:
    f.write(t)
print(f"ADDED_SECTIONS={','.join(added_sections) if added_sections else 'none'}")
print(f"UPDATED_SECTIONS={','.join(updated_sections) if updated_sections else 'none'}")
print(f"ENDPOINTS_ADDED={endpoints_added}")
PY

POST=$(sha ARCHITECTURE.md)
echo "POST ARCHITECTURE.md ${POST}" | tee -a "$LOG" >/dev/null

echo "REPORT=$LOG" | tee -a "$LOG" >/dev/null
