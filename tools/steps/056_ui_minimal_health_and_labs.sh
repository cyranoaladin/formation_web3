#!/usr/bin/env bash
# Step 056 — ui_minimal_health_and_labs
# Goal: Update UI to expose buttons for /health and /labs; fetch and show results in Output panel.
# Proofs: grep for onLabs in App.jsx, curl UI root HTML, curl API /labs (HTTP 200, hello-proof present), git status.

set -euo pipefail

# 1) Patch ui/src/App.jsx to add onLabs button and handler (idempotent)
python3 - <<'PY'
from pathlib import Path
p=Path('ui/src/App.jsx')
s=p.read_text(encoding='utf-8')
changed=False

if 'async function onLabs()' not in s:
    insert_fn='''\n  async function onLabs() {\n    setBusy(true);\n    setOut("");\n    try {\n      const j = await apiGet("/labs");\n      setOut(prettyJson(j));\n    } catch (e) {\n      setOut(String(e));\n    } finally {\n      setBusy(false);\n    }\n  }\n'''
    # Insert before return (
    s=s.replace('\n  return (', '\n'+insert_fn+'\n  return (')
    changed=True

# Add Labs button next to Health
if 'Labs' not in s:
    s=s.replace('Health</button>', 'Health</button>\n          <button disabled={busy} onClick={onLabs} style={{ padding: "8px 10px", marginLeft: 8 }}>Labs</button>')
    changed=True

if changed:
    p.write_text(s, encoding='utf-8')
    print('UI_PATCHED=1')
else:
    print('UI_PATCHED=0')
PY

# 2) Ensure UI container is up (it mounts ./ui so hot-reload applies); if not, bring it up
echo "--- docker compose up -d ui ---"
docker compose up -d ui

# 3) Proofs

echo "--- grep onLabs in App.jsx ---"
grep -n "onLabs" ui/src/App.jsx || true

echo "--- curl UI root (expect index.html, contains RBK Labs) ---"
curl -sS http://localhost:3000 | sed -n '1,40p'

echo "--- curl API /labs (for reference) ---"
LABS_JSON=/tmp/056_labs.json
curl -sS -w "\nHTTP=%{http_code}\n" http://localhost:8000/labs -o "$LABS_JSON"
cat "$LABS_JSON"; echo

python3 - <<'PY'
import json
j=json.load(open('/tmp/056_labs.json'))
ids=[x.get('lab_id') for x in j.get('labs',[])]
print('HAS_HELLO_PROOF=%s' % ('hello-proof' in ids))
print('LABS_COUNT=%d' % len(ids))
PY

# 4) Git status

echo "--- git status --porcelain ---"
git status --porcelain | sed -n '1,160p'
