#!/usr/bin/env bash
# Step 042 — api_add_upload_zip_endpoint (API only)
# Ensure POST /submissions/upload_zip exists; if present, do nothing. Then build and curl with fixture.
# No doc changes.

set -euo pipefail

FILE="api/app/main.py"
ROUTE_PATTERN='@app.post\("/submissions/upload_zip"'

echo "--- grep route (${FILE}) ---"
if grep -nE "$ROUTE_PATTERN" "$FILE"; then
  echo "ROUTE_PRESENT=1"
  CHANGED=0
else
  echo "ROUTE_PRESENT=0"
  # Minimal patch (only if missing)
  python3 - "$FILE" <<'PY'
import sys
from pathlib import Path
p=Path(sys.argv[1])
s=p.read_text(encoding='utf-8', errors='ignore')
if 'def upload_zip' in s:
    print('NO_PATCH')
    sys.exit(0)
ins='''\n\nfrom fastapi import UploadFile, File, Form\nfrom datetime import datetime\nfrom pathlib import Path as _P\nimport os, hashlib, zipfile, shutil\n\nUPLOAD_ROOT = _P(os.getenv("UPLOAD_ROOT", "/tmp/rbk_uploads"))\n\n@app.post("/submissions/upload_zip")\nasync def upload_zip(file: UploadFile = File(...), student_id: str = Form(None), lab_id: str = Form(None)):\n    if not file.filename.lower().endswith('.zip'):\n        raise HTTPException(status_code=400, detail='only_zip_allowed')\n    UPLOAD_ROOT.mkdir(parents=True, exist_ok=True)\n    upload_id = hashlib.sha1(os.urandom(16)).hexdigest()[:12]\n    sub_id = f"sub_{hashlib.sha1(os.urandom(8)).hexdigest()[:10]}"\n    zip_path = UPLOAD_ROOT / f"{upload_id}.zip"\n    with zip_path.open('wb') as out:\n        while True:\n            chunk = await file.read(1024*1024)\n            if not chunk: break\n            out.write(chunk)\n    extract_dir = UPLOAD_ROOT / upload_id\n    if extract_dir.exists(): shutil.rmtree(extract_dir)\n    with zipfile.ZipFile(zip_path,'r') as zf: zf.extractall(extract_dir)\n    now = datetime.utcnow()\n    db = get_db()\n    db.submissions.insert_one({\n        'submission_id': sub_id, 'student_id': student_id, 'lab_id': lab_id,\n        'status': 'queued', 'upload_path': str(extract_dir), 'created_at': now, 'updated_at': now\n    })\n    return {'submission_id': sub_id, 'status': 'queued'}\n'''
# naive append at end
p.write_text(s+ins, encoding='utf-8')
print('PATCHED')
PY
  CHANGED=1
fi

echo "--- docker compose up -d --build ---"
docker compose up -d --build

echo "--- curl upload (using tests/fixtures/minimal.zip) ---"
URL="http://localhost:8000/submissions/upload_zip"
OUT="/tmp/upload_042.json"
CODE=$(curl -sS -o "$OUT" -w "HTTP=%{http_code}\n" -F file=@tests/fixtures/minimal.zip -F student_id=stu_demo -F lab_id=lab_demo "$URL" || true)
echo "$CODE"
cat "$OUT" || true

echo "--- git diff --name-only (should be API only if any) ---"
git diff --name-only | sed -n '1,120p'