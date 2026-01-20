#!/usr/bin/env bash
# Step 053 — api_add_labs_index_endpoint
# Goal: Add GET /labs that scans labs/specs/*/lab.json, validates against labs_index schema, and returns index.
# Proofs: rebuild API, curl /labs HTTP 200, show JSON with hello-proof present, worker unaffected, git status.

set -euo pipefail

# Patch api/app/main.py to add /labs endpoint (idempotent)
python3 - <<'PY'
from pathlib import Path
p=Path('api/app/main.py')
s=p.read_text(encoding='utf-8')
if '@app.get("/labs")' not in s:
    block='''\n\n@app.get("/labs")\ndef list_labs():\n    base = Path(os.getenv("LABS_ROOT", "/repo/labs/specs"))\n    labs = []\n    try:\n        if base.exists():\n            for d in sorted([pp for pp in base.iterdir() if pp.is_dir()]):\n                lp = d / "lab.json"\n                if lp.is_file():\n                    with lp.open('r', encoding='utf-8') as f:\n                        try:\n                            doc = json.load(f)\n                            labs.append(doc)\n                        except Exception:\n                            pass\n    except Exception:\n        pass\n    idx = {"labs": labs}\n    _validate("labs_index", idx)\n    return idx\n'''
    s = s + block
    p.write_text(s, encoding='utf-8')
    print('API_LABS_ENDPOINT_ADDED=1')
else:
    print('API_LABS_ENDPOINT_ADDED=0')
PY

# Rebuild API and bring it up
echo "--- docker compose up -d --build api ---"
docker compose up -d --build api

# Prove endpoint
echo "--- curl /labs ---"
LABS_JSON=/tmp/053_labs.json
curl -sS -w "\nHTTP=%{http_code}\n" http://localhost:8000/labs -o "$LABS_JSON"
cat "$LABS_JSON"; echo

# Assert hello-proof present
python3 - <<'PY'
import json
j=json.load(open('/tmp/053_labs.json'))
ids=[x.get('lab_id') for x in j.get('labs',[])]
print('LABS_COUNT=%d' % len(ids))
print('HAS_HELLO_PROOF=%s' % ('hello-proof' in ids))
PY

# Tail API logs for context
echo "--- docker compose logs --tail=120 api ---"
docker compose logs --tail=120 api || true

# Git status for traceability
echo "--- git status --porcelain ---"
git status --porcelain | sed -n '1,200p'
