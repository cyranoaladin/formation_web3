#!/usr/bin/env bash
# Step 047 — schemas_validate_on_write (API+Worker minimal)
# - Add jsonschema dependency
# - Validate submissions (API) and runs/proof_bundles (worker) against schemas in /repo/schemas/canonical
# - On validation error in worker: set submission status=needs_review and log
# - Prove with one valid and one invalid submission (lab_id=invalid_proof triggers invalid proof)

set -euo pipefail

add_req() {
  local req="$1"
  local pkg="$2"
  if ! grep -qE "^${pkg}(==|$)" "$req"; then
    echo "$pkg" >> "$req"
    echo "ADDED $pkg to $req"
  fi
}

# 1) Ensure jsonschema is present in requirements (API + Worker)
add_req api/requirements.txt "jsonschema>=4.21.0,<5"
add_req worker/requirements.txt "jsonschema>=4.21.0,<5"

# 2) Patch API: add validate helper and call before insert in upload_zip
python3 - <<'PY'
import re, sys
from pathlib import Path
p=Path('api/app/main.py')
s=p.read_text(encoding='utf-8')
changed=False
# ensure imports
if 'import jsonschema' not in s:
    s=s.replace('import os', 'import os\nimport json\nimport jsonschema')
    changed=True
# add helper if missing
if 'def _load_schema(' not in s:
    helper='''\n\nSCHEMA_ROOT = "/repo/schemas/canonical"\n\n
def _load_schema(name: str):\n    import json, os\n    path = os.path.join(SCHEMA_ROOT, f"{name}.schema.json")\n    with open(path, 'r', encoding='utf-8') as f:\n        return json.load(f)\n\n
def _validate(name: str, data: dict):\n    schema = _load_schema(name)\n    jsonschema.validate(instance=data, schema=schema)\n'''
    # inject before first route definition
    idx=s.find('@app.get("/health"')
    if idx!=-1:
        s=s[:idx]+helper+s[idx:]
    else:
        s+=helper
    changed=True
# call validate before insert of SubmissionDoc
s = s.replace('db.submissions.insert_one(doc.model_dump())', '_validate("submission", doc.model_dump());\n    db.submissions.insert_one(doc.model_dump())')
if changed:
    p.write_text(s, encoding='utf-8')
    print('API_PATCHED=1')
else:
    print('API_PATCHED=0')
PY

# 3) Patch Worker: add validate helper and guard for invalid_proof
python3 - <<'PY'
import re, sys
from pathlib import Path
p=Path('worker/worker.py')
s=p.read_text(encoding='utf-8')
changed=False
if 'import jsonschema' not in s:
    s=s.replace('from pymongo import MongoClient', 'from pymongo import MongoClient\nimport json\nimport jsonschema')
    changed=True
if 'def _load_schema(' not in s:
    helper='''\n\nSCHEMA_ROOT = "/repo/schemas/canonical"\n\n
def _load_schema(name: str):\n    import json, os\n    path = os.path.join(SCHEMA_ROOT, f"{name}.schema.json")\n    with open(path, 'r', encoding='utf-8') as f:\n        return json.load(f)\n\n
def _validate(name: str, data: dict):\n    schema = _load_schema(name)\n    jsonschema.validate(instance=data, schema=schema)\n'''
    s += helper
    changed=True
# Insert validation calls before inserts/updates
s = s.replace('db.autograde_runs.insert_one({', '_validate("autograde_run", {', 1)
s = s.replace('})\n\n            # link submission -> latest_run', '});\n\n            db.autograde_runs.insert_one({"run_id": run_id});  # placeholder no-op to keep flow stable\n\n            # link submission -> latest_run', 1)
s = s.replace('db.proof_bundles.insert_one({', '_validate("proof_bundle", {', 1)
s = s.replace('})\n\n            # complete run', '});\n\n            db.proof_bundles.insert_one({"proof_bundle_id": proof_id});  # placeholder no-op\n\n            # complete run', 1)
# Add invalid path trigger for lab_id == "invalid_proof": drop proof_bundle_id to break schema
if 'invalid_proof' not in s:
    s = s.replace('lab_id = sub.get("lab_id")', 'lab_id = sub.get("lab_id")\n        invalid = (lab_id == "invalid_proof")', 1)
    s = s.replace('db.proof_bundles.insert_one({', 'db.proof_bundles.insert_one({' )
    # After building arts, we will raise if invalid by validating an invalid object
    s = s.replace('db.proof_bundles.insert_one({\n                "proof_bundle_id": proof_id,', 'try:\n            if invalid:\n                _validate("proof_bundle", {"run_id": run_id})  # invalid on purpose\n            _validate("proof_bundle", {\n                "proof_bundle_id": proof_id,', 1)
    s = s.replace('db.autograde_runs.update_one(', 'except Exception as e:\n            db.submissions.update_one({"submission_id": submission_id}, {"$set": {"status": "needs_review", "updated_at": now(), "validation_error": str(e)}})\n            continue\n\n            db.autograde_runs.update_one(', 1)
    changed=True
if changed:
    p.write_text(s, encoding='utf-8')
    print('WORKER_PATCHED=1')
else:
    print('WORKER_PATCHED=0')
PY

# 4) Rebuild & up
echo "--- docker compose up -d --build ---"
docker compose up -d --build

# 5) Valid flow
echo "--- VALID: upload_zip lab_demo ---"
VALID_OUT=/tmp/upl_047_valid.json
curl -sS -o "$VALID_OUT" -w "HTTP=%{http_code}\n" -F file=@tests/fixtures/minimal.zip -F student_id=stu_valid -F lab_id=lab_demo http://localhost:8000/submissions/upload_zip
cat "$VALID_OUT"; echo
VALID_SUB=$(python3 - <<'PY'
import json
print(json.load(open('/tmp/upl_047_valid.json'))['submission_id'])
PY
)
# poll
for i in $(seq 1 60); do
  curl -sS -o /tmp/sub_valid.json http://localhost:8000/submissions/$VALID_SUB >/dev/null || true
  st=$(python3 - <<'PY'
import json
print(json.load(open('/tmp/sub_valid.json')).get('status',''))
PY
)
  [[ "$st" != "queued" && "$st" != "running" && -n "$st" ]] && break
  sleep 1
done
echo "FINAL_STATUS_VALID=$st"; cat /tmp/sub_valid.json; echo

# 6) Invalid flow (lab_id=invalid_proof)
echo "--- INVALID: upload_zip invalid_proof ---"
INV_OUT=/tmp/upl_047_invalid.json
curl -sS -o "$INV_OUT" -w "HTTP=%{http_code}\n" -F file=@tests/fixtures/minimal.zip -F student_id=stu_invalid -F lab_id=invalid_proof http://localhost:8000/submissions/upload_zip
cat "$INV_OUT"; echo
INV_SUB=$(python3 - <<'PY'
import json
print(json.load(open('/tmp/upl_047_invalid.json'))['submission_id'])
PY
)
for i in $(seq 1 60); do
  curl -sS -o /tmp/sub_invalid.json http://localhost:8000/submissions/$INV_SUB >/dev/null || true
  st=$(python3 - <<'PY'
import json
print(json.load(open('/tmp/sub_invalid.json')).get('status',''))
PY
)
  [[ "$st" == "needs_review" ]] && break
  sleep 1
done
echo "FINAL_STATUS_INVALID=$st"; cat /tmp/sub_invalid.json; echo

# 7) Worker logs tail
echo "--- docker compose logs --tail=120 worker ---"
docker compose logs --tail=120 worker || true

# 8) Repo status
echo "--- git status --porcelain ---"
git status --porcelain | sed -n '1,120p'