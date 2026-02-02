import os
import time
import traceback
from datetime import datetime, timedelta
from pathlib import Path

from pymongo import MongoClient
import json
import jsonschema
import subprocess

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


# Environment variables for Runner config
RUNNER_BACKEND = os.getenv("RUNNER_BACKEND", "subprocess")  # "docker" or "subprocess"
HOST_PWD = os.getenv("HOST_PWD", os.getcwd())  # For Docker volume mounts
RBK_ENV = os.getenv("RBK_ENV", "dev")

def _run_runner(lab_id: str, submission_id: str, upload_path: str, run_id: str) -> dict:
    import json, os, subprocess
    
    # Paths definition
    zip_path = upload_path + ".zip"
    sandbox = f"/tmp/rbk_runner/{submission_id}"
    
    logs = ""
    result = {}
    
    try:
        if RUNNER_BACKEND == "docker":
            # --- DOCKER EXECUTION (SECURED) ---
            print(f"[worker] running in DOCKER mode for {submission_id}", flush=True)
            
            # Pre-create sandbox dir on host (worker) so it exists for binding
            os.makedirs(sandbox, exist_ok=True)
            os.makedirs(os.path.join(sandbox, "out"), exist_ok=True)
            os.makedirs(os.path.join(sandbox, "work"), exist_ok=True)
            
            # Strategy: Use 'docker cp' to avoid binding mounting issues with named volumes
            # This is more robust for DooD setups where paths might mismatch.
            
            c_name = f"rbk_run_{run_id}"
            
            # 1. Create container (Created state)
            # We assume 'rbk-runner:latest' is built and available (runner-base service)
            # We mount the repo code read-only (using HOST_PWD provided by docker-compose)
            # We assume HOST_PWD points to the repo root on the HOST.
            subprocess.run([
                "docker", "create", 
                "--name", c_name,
                "--network", "none",
                "--cpus", "1.0",
                "--memory", "512m",
                "-v", f"{HOST_PWD}:/repo:ro",
                "rbk-runner:latest", 
                "python", "/repo/runner/minimal.py",
                "--lab-id", lab_id,
                "--submission-id", submission_id,
                "--run-id", run_id,
                "--zip", "/tmp/input.zip", 
                "--sandbox", "/tmp/sandbox"
            ], check=True, capture_output=True)
            
            try:
                # 2. Copy Zip to container
                subprocess.run(["docker", "cp", zip_path, f"{c_name}:/tmp/input.zip"], check=True, capture_output=True)
                
                # 3. Start container and wait for completion
                proc = subprocess.run(["docker", "start", "-a", c_name], capture_output=True, text=True)
                logs = proc.stdout + "\n" + proc.stderr
                
                # 4. Copy Results back from container
                def read_cont_file(path_in_c):
                    local_dst = os.path.join(sandbox, os.path.basename(path_in_c))
                    # docker cp will fail if file doesn't exist, ignore error
                    subprocess.run(["docker", "cp", f"{c_name}:{path_in_c}", local_dst], capture_output=True)
                    if os.path.exists(local_dst):
                        return open(local_dst, "r", encoding="utf-8", errors="replace").read()
                    return None

                res_json_str = read_cont_file("/tmp/sandbox/out/result.json")
                if res_json_str:
                    try:
                        result = json.loads(res_json_str)
                    except Exception:
                        pass
                        
                logs_file_content = read_cont_file("/tmp/sandbox/out/logs.txt")
                if logs_file_content:
                    logs = logs_file_content
                    
            finally:
                # 5. Cleanup container
                subprocess.run(["docker", "rm", "-f", c_name], capture_output=True)
                
        else:
            # --- SUBPROCESS EXECUTION (LEGACY/DEV) ---
            RUNNER_BIN = ["python", "/repo/runner/minimal.py"]
            cmd = RUNNER_BIN + ["--lab-id", lab_id, "--submission-id", submission_id, "--run-id", run_id, "--zip", zip_path, "--sandbox", sandbox]
            proc = subprocess.run(cmd, capture_output=True, text=True)
            out_dir = os.path.join(sandbox, "out")
            logs_fp = os.path.join(out_dir, "logs.txt")
            res_fp = os.path.join(out_dir, "result.json")
            logs = open(logs_fp, 'r', encoding='utf-8').read() if os.path.exists(logs_fp) else proc.stdout
            if os.path.exists(res_fp):
                try:
                    result = json.load(open(res_fp, 'r', encoding='utf-8'))
                except Exception:
                    result = {"status": "failed", "error": "invalid result.json"}
            else:
                result = {"status": "failed", "error": "missing result.json"}
                
        return {"logs": logs, "result": result}
        
    except Exception as e:
        return {"logs": f"[runner error] {e}", "result": {"status": "failed", "error": str(e)}}




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
        is_hello = (lab_id == "hello-proof")
        invalid = (lab_id == "invalid_proof")
        decision = "needs_review"
        score_auto_val = 100 if is_hello else 50
        upload_path = sub.get("upload_path") or ""

        run_id = gen_id("run")
        proof_id = gen_id("proof")

        print(f"[worker] claimed submission_id={submission_id} upload_path={upload_path}", flush=True)
        # Allow external polling to observe the running state
        time.sleep(1.0)

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

            # runner integration for hello-proof: override logs and result from sandbox
            arts_result_raw = "{}"
            files_count_calc = len(arts.get("files", []))
            if is_hello:
                ro = _run_runner(lab_id, submission_id, upload_path, run_id)
                
                runner_logs = ""
                runner_result_str = "{}"
                
                # 1. Try to get from returned object
                if isinstance(ro, dict):
                    runner_logs = ro.get('logs', "")
                    res_obj = ro.get('result')
                    if res_obj:
                        import json as _json
                        runner_result_str = _json.dumps(res_obj, ensure_ascii=False)

                # 2. Hardening: Fallback to reading files from sandbox if missing
                try:
                    from pathlib import Path as _P
                    _sb = _P(f"/tmp/rbk_runner/{submission_id}")
                    _out_logs = _sb / "out" / "logs.txt"
                    _out_res = _sb / "out" / "result.json"
                    
                    if not runner_logs and _out_logs.exists():
                        runner_logs = _out_logs.read_text(encoding='utf-8', errors='replace')
                    
                    if (not runner_result_str or runner_result_str == "{}") and _out_res.exists():
                        runner_result_str = _out_res.read_text(encoding='utf-8', errors='replace')
                except Exception:
                    pass

                # 3. Final Fallback if result still missing
                if not runner_result_str or runner_result_str == "{}":
                    runner_result_str = '{"status":"failed","error":"missing result.json"}'
                    runner_logs += "\n[worker] runner missing result.json"

                # 4. Assign outputs
                arts['logs'] = runner_logs if runner_logs else "[worker] no runner logs captured"
                arts_result_raw = runner_result_str
                
                # 5. Derive decision from result (parsing it back)
                try:
                    import json as _json
                    _res_parsed = _json.loads(runner_result_str)
                    if _res_parsed.get('status') == 'ok':
                        decision = 'validated'
                except Exception:
                    pass

                # 6. Files Count Computation (Sandbox Robustness)
                try:
                    from pathlib import Path as _P
                    _sb = _P(f"/tmp/rbk_runner/{submission_id}")
                    files_count_calc = 0
                    if _sb.exists():
                        for _fp in _sb.rglob('*'):
                            if _fp.is_file():
                                if 'out/' in str(_fp) or str(_fp).endswith('/out'): continue
                                if _fp.suffix == '.zip': continue
                                files_count_calc += 1
                except Exception:
                    files_count_calc = len(arts.get('files', []))

            # result from runner or default kept
            result_obj = {
                "status": "ok",
                "lab_id": lab_id,
                "submission_id": submission_id,
                "run_id": run_id,
                "started_at": iso_now(),
                "finished_at": iso_now()
            }
            import json as _json
            if not is_hello:
                arts_result_raw = _json.dumps(result_obj, ensure_ascii=False)

            try:
                arts_result = _json.loads(arts_result_raw) if arts_result_raw else result_obj
            except Exception:
                arts_result = {"status": "failed", "error": "invalid result.json"}

            # Build proof bundle
            proof_doc = {
                "proof_bundle_id": proof_id,
                "run_id": run_id,
                "submission_id": submission_id,
                "lab_id": lab_id,
                "created_at": now(),
                "decision_hint": decision,
                "score": {"auto": score_auto_val, "rubric": "placeholder"},
                "immutable": True,
                "artifacts": {
                    "logs": arts["logs"],
                    "tests": arts["tests"],
                    "diff": arts["diff"],
                    "audit": arts["audit"],
                    "result": arts_result,
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
                        "result": {"ok": True, "decision_hint": decision, "score_auto": score_auto_val, "files_count": files_count_calc}
                    }},
                )

                # Mark submission as needs_review
                db.submissions.update_one(
                    {"submission_id": submission_id},
                    {"$set": {"status": "completed", "updated_at": now(), "run_id": run_id, "proof_bundle_id": proof_id}},
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
