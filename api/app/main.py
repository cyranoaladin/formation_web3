from fastapi import FastAPI, UploadFile, File, Form, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from .models import Health, SubmissionCreateResponse, SubmissionDoc, gen_id
from .db import get_db
from datetime import datetime
from pathlib import Path
import hashlib
import zipfile
import os
import shutil

app = FastAPI(title="RBK Labs API", version="0.1.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "http://localhost:3000",
        "http://127.0.0.1:3000",
    ],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

UPLOAD_ROOT = Path(os.getenv("UPLOAD_ROOT", "/tmp/rbk_uploads"))
MAX_ZIP_BYTES = int(os.getenv("MAX_ZIP_BYTES", str(50 * 1024 * 1024)))  # 50MB
MAX_FILES = int(os.getenv("MAX_ZIP_FILES", "500"))
MAX_UNZIPPED_BYTES = int(os.getenv("MAX_UNZIPPED_BYTES", str(200 * 1024 * 1024)))  # 200MB
ALLOWED_EXT = set(os.getenv("ALLOWED_EXT", ".md,.txt,.rs,.toml,.lock,.json,.yaml,.yml,.ts,.js,.diff").split(","))

def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()

def _within(base: Path, target: Path) -> bool:
    base_r = base.resolve()
    target_r = target.resolve()
    return str(target_r).startswith(str(base_r) + os.sep) or target_r == base_r

def safe_extract_zip(zip_path: Path, dest_dir: Path) -> dict:
    dest_dir.mkdir(parents=True, exist_ok=True)
    total_unzipped = 0
    file_count = 0

    with zipfile.ZipFile(zip_path, "r") as zf:
        infos = zf.infolist()
        if len(infos) > MAX_FILES:
            raise HTTPException(status_code=400, detail=f"zip_too_many_files>{MAX_FILES}")

        for info in infos:
            name = info.filename

            if name.startswith("/") or name.startswith("\\") or ":" in name:
                raise HTTPException(status_code=400, detail="zip_invalid_absolute_path")

            out_path = dest_dir / name
            if not _within(dest_dir, out_path):
                raise HTTPException(status_code=400, detail="zip_path_traversal")

            if name.endswith("/"):
                continue

            suffix = out_path.suffix.lower()
            if suffix and (suffix not in ALLOWED_EXT):
                raise HTTPException(status_code=400, detail=f"zip_disallowed_ext:{suffix}")

            total_unzipped += info.file_size
            file_count += 1
            if total_unzipped > MAX_UNZIPPED_BYTES:
                raise HTTPException(status_code=400, detail="zip_uncompressed_too_large")

        zf.extractall(dest_dir)

    return {"files": file_count, "bytes": total_unzipped}

@app.get("/health", response_model=Health)
def health():
    return Health()

@app.post("/submissions/upload_zip", response_model=SubmissionCreateResponse)
async def upload_zip(
    student_id: str = Form(...),
    lab_id: str = Form(...),
    file: UploadFile = File(...),
):
    if not file.filename.lower().endswith(".zip"):
        raise HTTPException(status_code=400, detail="only_zip_allowed")

    UPLOAD_ROOT.mkdir(parents=True, exist_ok=True)

    upload_id = gen_id("upl")
    sub_id = gen_id("sub")

    zip_path = UPLOAD_ROOT / f"{upload_id}.zip"
    extract_dir = UPLOAD_ROOT / upload_id

    written = 0
    with zip_path.open("wb") as out:
        while True:
            chunk = await file.read(1024 * 1024)
            if not chunk:
                break
            written += len(chunk)
            if written > MAX_ZIP_BYTES:
                raise HTTPException(status_code=400, detail="zip_too_large")
            out.write(chunk)

    zip_sha = sha256_file(zip_path)

    if extract_dir.exists():
        shutil.rmtree(extract_dir)
    safe_extract_zip(zip_path, extract_dir)

    now = datetime.utcnow()
    doc = SubmissionDoc(
        submission_id=sub_id,
        student_id=student_id,
        lab_id=lab_id,
        status="queued",
        upload_path=str(extract_dir),
        upload_sha256=zip_sha,
        created_at=now,
        updated_at=now,
    )

    db = get_db()
    db.submissions.insert_one(doc.model_dump())

    return SubmissionCreateResponse(submission_id=sub_id, status="queued", upload_id=upload_id)


@app.get("/submissions/{submission_id}")
def get_submission(submission_id: str):
    db = get_db()
    doc = db.submissions.find_one({"submission_id": submission_id}, {"_id": 0})
    if not doc:
        raise HTTPException(status_code=404, detail="submission_not_found")
    return doc

@app.get("/runs/{run_id}")
def get_run(run_id: str):
    db = get_db()
    doc = db.autograde_runs.find_one({"run_id": run_id}, {"_id": 0})
    if not doc:
        raise HTTPException(status_code=404, detail="run_not_found")
    return doc

# patched-by: tools/safe_patch.py
