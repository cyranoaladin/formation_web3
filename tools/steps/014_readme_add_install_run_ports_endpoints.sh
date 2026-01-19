#!/usr/bin/env bash
set -euo pipefail

mkdir -p tools/logs
TS="$(date +%Y%m%d_%H%M%S)"
LOG="tools/logs/docs_fix_readme_${TS}.txt"

echo "STEP=014 readme add minimal sections" | tee "$LOG" >/dev/null
sha() { sha256sum "$1" | awk '{print $1}'; }

PRE=$(sha README.md)
echo "PRE README.md ${PRE}" | tee -a "$LOG" >/dev/null

echo "BEFORE_PORT48:" | tee -a "$LOG" >/dev/null
grep -nE '(port 48|:48\b)' README.md || true | tee -a "$LOG" >/dev/null

python3 - <<'PY' >> "$LOG" 2>/dev/null
import re,sys
p='README.md'
with open(p,encoding='utf-8') as f:
    t=f.read()

# Fix false positive 'Durée : 48' (not a port)
t = re.sub(r'(?i)\bDurée\s*:\s*48\b','Durée 48',t)
# If any explicit 'port 48' remains, default to 3000 (UI) conservatively
t = re.sub(r'(?i)\bport\s*48\b','port 3000',t)

# Section helpers
DEF = {
  'Installation': 'prérequis: Docker + Docker Compose',
  'Run': 'docker compose up -d --build\n\ndocker compose ps',
  'Ports': 'API: 8000\n\nUI: 3000',
  'Endpoints': 'GET /health (API)\n\nPOST /submissions/upload_zip (API)\n\nPOST /rag/query (API)'
}

def has_section(title, text):
    return re.search(rf'(?im)^##\s*{re.escape(title)}\b', text) is not None

# Determine insertion anchor: after "## Architecture" section if present, else EOF
anch = re.search(r'(?im)^##\s*Architecture\b', t)
insert_at = len(t)
if anch:
    # find next level-2 heading after anchor
    m = re.search(r'(?im)^##\s+.*$', t[anch.end():])
    insert_at = anch.end() + (m.start() if m else len(t[anch.end():]))

missing = [k for k in ['Installation','Run','Ports','Endpoints'] if not has_section(k, t)]
blocks = ''
for k in missing:
    blocks += f"\n\n## {k}\n" + DEF[k] + "\n"

if blocks:
    if insert_at>=len(t):
        t = t.rstrip() + blocks + "\n"
        print(f"ADDED_AFTER=EOF sections={'/'.join(missing)}")
    else:
        t = t[:insert_at].rstrip() + blocks + "\n" + t[insert_at:]
        print(f"ADDED_AFTER=Architecture sections={'/'.join(missing)}")
else:
    print("ADDED_AFTER=none (sections already present)")

with open(p,'w',encoding='utf-8') as f:
    f.write(t)
PY

echo "AFTER_PORT48:" | tee -a "$LOG" >/dev/null
grep -nE '(port 48|:48\b)' README.md || true | tee -a "$LOG" >/dev/null

POST=$(sha README.md)
echo "POST README.md ${POST}" | tee -a "$LOG" >/dev/null

echo "REPORT=$LOG" | tee -a "$LOG" >/dev/null
