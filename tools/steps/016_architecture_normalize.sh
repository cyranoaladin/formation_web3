#!/usr/bin/env bash
set -euo pipefail

mkdir -p tools/logs
TS="$(date +%Y%m%d_%H%M%S)"
LOG="tools/logs/docs_fix_architecture_norm_${TS}.txt"

echo "STEP=016 architecture normalize" | tee "$LOG" >/dev/null
sha() { sha256sum "$1" | awk '{print $1}'; }

PRE=$(sha ARCHITECTURE.md)
echo "PRE ARCHITECTURE.md ${PRE}" | tee -a "$LOG" >/dev/null

python3 -c "import re,sys; p='ARCHITECTURE.md'; t=open(p,encoding='utf-8').read();
# extract helper for a level-2 section

def sec(text,name):
    m=re.search(r'(?im)^##\s*'+re.escape(name)+r'\b', text)
    if not m: return ''
    s=m.end()
    nxt=re.search(r'(?im)^##\s+[^#].*$', text[s:])
    e=s+(nxt.start() if nxt else len(text[s:]))
    body=text[s:e].strip('\n')
    return body.strip()

schema=sec(t,'Schéma logique')
principes=sec(t,'Principes')
# canonical rebuild
parts=[]
parts.append('# Architecture Technique')
parts.append('')
parts.append('## Vue d’ensemble')
if schema:
    parts.append('### Schéma logique')
    parts.append(schema)
if principes:
    parts.append('')
    parts.append('### Principes')
    parts.append(principes)
parts.append('')
parts.append('## Composants')
parts.append('- API : FastAPI (port 8000)')
parts.append('- Worker : file queued → run/proof_bundle')
parts.append('- UI : Vite + React (port 3000)')
parts.append('- Données : Local : Mongo (container mongo:7); Prod (optionnel) : MongoDB Atlas / Atlas Vector Search (pour RAG)')
parts.append('')
parts.append('## Orchestration')
parts.append('- docker-compose.yml orchestre api, worker, ui, mongo')
parts.append('')
parts.append('## Ports')
parts.append('- API: 8000')
parts.append('- UI: 3000')
parts.append('')
parts.append('## Flux')
parts.append('- upload_zip → queued → worker → run → proof_bundle')
parts.append('')
parts.append('## Endpoints')
parts.append('GET /health')
parts.append('POST /submissions/upload_zip')
parts.append('POST /rag/query')
new='\n'.join(parts).rstrip()+'\n'
changed=int(new!=t)
if changed:
    open(p,'w',encoding='utf-8').write(new)
print(f'CHANGED={changed}')
" | tee -a "$LOG" >/dev/null

POST=$(sha ARCHITECTURE.md)
echo "POST ARCHITECTURE.md ${POST}" | tee -a "$LOG" >/dev/null

echo "REPORT=$LOG" | tee -a "$LOG" >/dev/null
