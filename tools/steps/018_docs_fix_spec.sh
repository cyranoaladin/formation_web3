#!/usr/bin/env bash
set -euo pipefail

mkdir -p tools/logs
TS="$(date +%Y%m%d_%H%M%S)"
LOG="tools/logs/docs_fix_spec_${TS}.txt"

echo "STEP=018 spec doc-fix minimal" | tee "$LOG" >/dev/null
sha() { sha256sum "$1" | awk '{print $1}'; }

PRE=$(sha SPEC.md)
echo "PRE SPEC.md ${PRE}" | tee -a "$LOG" >/dev/null

python3 - <<'PY' | tee -a "$LOG" >/dev/null
import re, os
p='SPEC.md'
t=open(p,encoding='utf-8').read() if os.path.exists(p) else ''
changed=False

# Ensure unique H1
DESIRED_H1 = '# Spécification Fonctionnelle – RBK Labs'
if not re.search(r'(?m)^#\s+', t):
    t = DESIRED_H1 + '\n\n' + t
    changed=True
else:
    t2 = re.sub(r'(?m)^#\s+.*$', DESIRED_H1, t, count=1)
    if t2 != t:
        t = t2; changed=True

# Helper to get section range
H2 = re.compile(r'(?im)^##\s*([^\n]+)\s*$')

def sec_range(txt, title):
    m = re.search(rf'(?im)^##\s*{re.escape(title)}\b', txt)
    if not m:
        return None, None
    s = m.end()
    n = re.search(r'(?im)^##\s+[^#].*$', txt[s:])
    e = s + (n.start() if n else len(txt[s:]))
    return s, e

# Ensure or fill a section with exact body when empty/missing

def ensure_section(txt, title, body):
    global changed
    s,e = sec_range(txt, title)
    block = f"\n\n## {title}\n" + body.strip() + "\n"
    if s is None:
        txt = txt.rstrip() + block + "\n"
        changed=True
        return txt
    # existing: check if non-heading content exists
    seg = txt[s:e]
    non_heading = [ln for ln in seg.splitlines() if ln.strip() and not ln.strip().startswith('#')]
    if not non_heading:
        txt = txt[:s].rstrip() + "\n" + body.strip() + "\n" + txt[e:]
        changed=True
    return txt

# Ensure presence of required items inside an existing section (add only missing)

def ensure_lines(txt, title, req_lines):
    global changed
    s,e = sec_range(txt, title)
    if s is None:
        body = "\n".join(req_lines)
        return ensure_section(txt, title, body)
    seg = txt[s:e]
    for line in req_lines:
        if not re.search(rf'(?m)^{re.escape(line)}\s*$', seg):
            seg = seg.rstrip() + "\n" + line + "\n"
            changed=True
    return txt[:s] + seg + txt[e:]

# Minimal default bodies
body_objectif = "- Spécification fonctionnelle minimale du dépôt"
body_parcours = "- Parcours principal: upload_zip → queued → worker → run → proof_bundle"
body_objets   = "- submissions\n- runs\n- proof_bundle"
body_etats    = "- queued\n- needs_review\n- completed"
endpoints     = ["GET /health","POST /submissions/upload_zip","POST /rag/query"]
body_accept   = "- API répond 200 sur /health\n- Upload zip crée une submission en queued\n- Worker produit un run et un proof_bundle\n- RAG retourne une réponse via /rag/query"

# Apply sections
for title, body in (
    ("Objectif", body_objectif),
    ("Parcours utilisateur", body_parcours),
    ("Objets et données", body_objets),
    ("États canoniques", body_etats),
    ("Critères d’acceptation", body_accept),
):
    t = ensure_section(t, title, body)

# Endpoints: ensure section and required lines (no removals)
t = ensure_lines(t, "Endpoints", endpoints)

if changed:
    open(p,'w',encoding='utf-8').write(t)
print(f"CHANGED={int(changed)}")
PY

POST=$(sha SPEC.md)
echo "POST SPEC.md ${POST}" | tee -a "$LOG" >/dev/null

echo "REPORT=$LOG" | tee -a "$LOG" >/dev/null
