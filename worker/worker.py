import os
import time
import traceback
from datetime import datetime, timedelta
from pathlib import Path

from pymongo import MongoClient
import json
import jsonschema

MONGODB_URI = os.getenv("MONGODB_URI", "mongodb://mongo:27017")
MONGODB_DB = os.getenv("MONGODB_DB", "rbk_labs")

POLL_INTERVAL = int(os.getenv("WORKER_POLL_INTERVAL", "5"))
STALE_MIN = int(os.getenv("WORKER_STALE_MIN", "10"))  # minutes

SCHEMA_ROOT = "/repo/schemas/canonical"

def iso_now() -> str:
    # RFC3339 UTC with Z
    return datetime.utcnow().replace(microsecond=0).isoformat() + 'Z'

def now() -> datetime:
    return datetime.utcnow()

def gen_id(prefix: str) -> str:
    return f"{prefix}_{os.urandom(8).hex()}"

def _load_schema(name: str):
    import json, os
    path = os.path.join(SCHEMA_ROOT, f"{name}.schema.json")
    with open(path, 'r', encoding='utf-8') as f:
        return json.load(f)

def _validate(name: str, data: dict):
    schema = _load_schema(name)
    jsonschema.validate(instance=data, schema=schema)

def requeue_stale(db) -> int:
    cutoff = now() - timedelta(minutes=STALE_MIN)
    res = db.submissions.update_many(
        {"status": "running", "updated_at": {"$lt": cutoff}},
        {"$set": {"status": "queued", "updated_at": now(), "stale_requeued": True}},
    )
    return int(getattr(res, "modified_count", 0))

def safe_read(path: Path, limit: int = 50000) -> str:
    try:
        s = path.read_text(encoding="utf-8", errors="replace")
        return s if len(s) <= limit else s[:limit] + "\n...[truncated]\n"
    except Exception as e:
        return f"[unreadable:{path.name}] {e}"

def build_proof_artifacts(upload_path: str) -> dict:
    root = Path(upload_path)
    files = []
    if root.exists():
        for f in sorted(root.rglob("*")):
            if f.is_file():
                files.append(str(f.relative_to(root)))
    return {
        "logs": "RBK Worker Logs (placeholder)\\n- upload_path: %s\\n- files_count: %d\\n" % (upload_path, len(files)),
        "tests": "RBK Tests (placeholder)\\n- not executed yet\\n",
        "diff": safe_read(root / "patch.diff") if root.exists() else "[missing upload_path]",
        "audit": safe_read(root / "proofs" / "audit_note.md") if root.exists() else "[missing upload_path]",
        "files": files,
    }

def main():
    client = MongoClient(MONGODB_URI)
    db = client[MONGODB_DB]

    print(f"[worker] connected: {MONGODB_URI} db={MONGODB_DB}", flush=True)
    stale = requeue_stale(db)
    print(f"[worker] requeued stale running: {stale}", flush=True)

    while True:
        sub = db.submissions.find_one_and_update(
            {"status": "queued"},
            {"$set": {"status": "running", "updated_at": now()}},
            sort=[("created_at", 1)],
            return_document=True,
        )

        if not sub:
            print("[worker] idle: no queued submissions", flush=True)
            time.sleep(POLL_INTERVAL)
            continue

        submission_id = sub.get("submission_id")
        lab_id = sub.get("lab_id")
        invalid = (lab_id == "invalid_proof")
        is_hello = (lab_id == "hello-proof")
        decision = "validated" if is_hello else "needs_review"
        score_auto_val = 100 if is_hello else 50
        upload_path = sub.get("upload_path") or ""

        run_id = gen_id("run")
        proof_id = gen_id("proof")

        print(f"[worker] claimed submission_id={submission_id} upload_path={upload_path}", flush=True)

        try:
            # Build run document
            run_doc = {
                "run_id": run_id,
                "submission_id": submission_id,
                "status": "running",
                "created_at": now(),
                "updated_at": now(),
                "runner": {"kind": "placeholder"},
                "result": {},
                "proof_bundle_id": None,
            }
            # Validate JSON representation
            run_json = {
                **run_doc,
                "created_at": iso_now(),
                "updated_at": iso_now(),
            }
            _validate("autograde_run", run_json)
            db.autograde_runs.insert_one(run_doc)

            # Link submission -> latest_run
            db.submissions.update_one(
                {"submission_id": submission_id},
                {"$set": {"latest_run_id": run_id, "updated_at": now()}},
            )

            arts = build_proof_artifacts(upload_path)

            # Build proof bundle
            proof_doc = {
                "proof_bundle_id": proof_id,
                "run_id": run_id,
                "submission_id": submission_id,
                "lab_id": lab_id,
                "created_at": now(),
                "decision_hint": decision,
                "score": {"auto": score_auto_val, "rubric": "placeholder"},
                "artifacts": {
                    "logs": arts["logs"],
                    "tests": arts["tests"],
                    "diff": arts["diff"],
                    "audit": arts["audit"],
                }
            }

            # Validate/insert proof. If invalid_proof, trigger schema error
            try:
                if invalid:
                    _validate("proof_bundle", {"run_id": run_id})  # intentionally invalid
                proof_json = {**proof_doc, "created_at": iso_now()}
                _validate("proof_bundle", proof_json)
                db.proof_bundles.insert_one(proof_doc)

                # Complete run
                db.autograde_runs.update_one(
                    {"run_id": run_id},
                    {"$set": {
                        "status": "completed",
                        "updated_at": now(),
                        "proof_bundle_id": proof_id,
                        "result": {"ok": True, "decision_hint": decision, "score_auto": score_auto_val, "files_count": len(arts["files"])}
                    }},
                )

                # Mark submission as needs_review
                db.submissions.update_one(
                    {"submission_id": submission_id},
                    {"$set": {"status": ("validated" if is_hello else "needs_review"), "updated_at": now()}},
                )

                print(f"[worker] completed submission_id={submission_id} run_id={run_id} proof_id={proof_id}", flush=True)

            except jsonschema.ValidationError as e:
                db.submissions.update_one({"submission_id": submission_id}, {"$set": {"status": "needs_review", "updated_at": now(), "validation_error": str(e)}})
                print(f"[worker] proof validation error: {e}", flush=True)
                continue

        except Exception as e:
            import traceback
            err = "".join(traceback.format_exception(type(e), e, e.__traceback__))
            print(f"[worker] ERROR: {e}\n{err}", flush=True)
            db.submissions.update_one(
                {"submission_id": submission_id},
                {"$set": {"status": "failed", "updated_at": now()}},
            )

        time.sleep(0.2)

if __name__ == "__main__":
    main()
