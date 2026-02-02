from __future__ import annotations

import json
import os
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, Optional

from fastapi import FastAPI, HTTPException, Response

from .docker_exec import ExecutionResult, run_in_docker
from .models import RunArtifacts, RunReason, RunRequest, RunResponse, RunStatus
from .security import filter_env, realpath_within, validate_command, validate_run_id
from .settings import get_settings


app = FastAPI(title="RBK runnerd", version="1.0.0")


def _utc_now() -> datetime:
    return datetime.now(timezone.utc).replace(microsecond=0)


def _rfc3339_now() -> str:
    return _utc_now().isoformat().replace("+00:00", "Z")


def _workspace_paths(run_id: str) -> Dict[str, Path]:
    settings = get_settings()
    base = Path(settings.runnerd_workspaces_dir)
    root = (base / run_id)
    ws_in = root / "in"
    ws_out = root / "out"
    lock = root / ".lock.json"
    return {"base": base, "root": root, "in": ws_in, "out": ws_out, "lock": lock}


def _read_json(path: Path) -> Optional[Dict[str, Any]]:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except Exception:
        return None


def _write_json_atomic(path: Path, obj: Dict[str, Any]) -> None:
    tmp = path.with_suffix(path.suffix + ".tmp")
    tmp.write_text(json.dumps(obj, ensure_ascii=False, indent=2), encoding="utf-8")
    tmp.replace(path)


def _append_system_event(paths: Dict[str, Path], message: str) -> None:
    # Do not write into logs.jsonl if it doesn't exist.
    # Use out/system.jsonl for runnerd-only events.
    out_dir = paths["out"]
    out_dir.mkdir(parents=True, exist_ok=True)
    fp = out_dir / "system.jsonl"
    line = {
        "ts": _rfc3339_now(),
        "stream": "system",
        "message": message,
    }
    payload = json.dumps(line, ensure_ascii=False) + "\n"
    if not fp.exists():
        fp.write_text(payload, encoding="utf-8", errors="replace")
        return
    with fp.open("a", encoding="utf-8", errors="replace") as f:
        f.write(payload)


def _result_paths() -> RunArtifacts:
    return RunArtifacts(result_json_path="out/result.json", logs_jsonl_path="out/logs.jsonl")


def _result_abs(paths: Dict[str, Path]) -> Dict[str, Path]:
    return {
        "result": paths["out"] / "result.json",
        "result_raw": paths["out"] / "result.raw.json",
        "logs": paths["out"] / "logs.jsonl",
    }


def _http_error(status_code: int, run_id: str, lab_id: str, submission_id: str, status: RunStatus, reason: RunReason, message: str) -> HTTPException:
    payload = {
        "run_id": run_id,
        "lab_id": lab_id,
        "submission_id": submission_id,
        "status": status,
        "reason": reason,
        "message": message,
    }
    raise HTTPException(status_code=status_code, detail=payload)


def _is_lock_stale(paths: Dict[str, Path]) -> bool:
    settings = get_settings()
    lock = paths["lock"]
    if not lock.exists():
        return False
    res = paths["out"] / "result.json"
    if res.exists():
        return False

    lock_data = _read_json(lock) or {}
    started_at_str = str(lock_data.get("started_at") or "")
    if not started_at_str:
        return True
    try:
        started_at = datetime.fromisoformat(started_at_str.replace("Z", "+00:00"))
    except Exception:
        return True
    age_s = (_utc_now() - started_at).total_seconds()
    return age_s > int(settings.runnerd_lock_stale_after_s)


def _map_exec_result_to_status_reason(exec_result: ExecutionResult) -> tuple[RunStatus, RunReason]:
    if exec_result.timed_out:
        return RunStatus.TIMEOUT, RunReason.TIMEOUT_HARD
    if exec_result.out_bytes_exceeded:
        return RunStatus.RESOURCE_LIMIT, RunReason.OUTPUT_LIMIT_EXCEEDED
    if exec_result.oom_killed_hint:
        return RunStatus.RESOURCE_LIMIT, RunReason.MEMORY_LIMIT
    if exec_result.pids_limit_hint:
        return RunStatus.RESOURCE_LIMIT, RunReason.PIDS_LIMIT
    if exec_result.docker_failed:
        return RunStatus.FAILED, RunReason.DOCKER_EXEC_FAILED
    return RunStatus.FAILED, RunReason.DOCKER_EXEC_FAILED


def _finalize_result_json(
    *,
    paths: Dict[str, Path],
    req: RunRequest,
    started_at: datetime,
    finished_at: datetime,
    duration_ms: int,
    exec_result: ExecutionResult,
) -> Dict[str, Any]:
    res_abs = _result_abs(paths)
    raw = _read_json(res_abs["result_raw"]) if res_abs["result_raw"].exists() else None

    if raw is None:
        # Missing/invalid raw artifact is an artifact-write failure.
        # Do not infer TIMEOUT/RESOURCE_LIMIT without artifacts.
        status, run_reason = RunStatus.FAILED, RunReason.ARTIFACT_WRITE_FAILED
        if exec_result.docker_failed:
            status, run_reason = RunStatus.FAILED, RunReason.DOCKER_EXEC_FAILED
        exit_code = None
        truncated_logs = False
        raw_started_at = None
        raw_finished_at = None
    else:
        exit_code = raw.get("exit_code")
        truncated_logs = bool(raw.get("truncated_logs", False))
        # With raw present, runnerd can safely apply its classification.
        status, run_reason = _map_exec_result_to_status_reason(exec_result)
        if status == RunStatus.FAILED and run_reason == RunReason.DOCKER_EXEC_FAILED:
            if isinstance(exit_code, int) and exit_code == 0:
                status, run_reason = RunStatus.OK, RunReason.NONE
            else:
                status, run_reason = RunStatus.FAILED, RunReason.NONE

    payload: Dict[str, Any] = {
        "status": status.value,
        "reason": run_reason.value,
        "exit_code": exit_code,
        "started_at": started_at.isoformat().replace("+00:00", "Z"),
        "finished_at": finished_at.isoformat().replace("+00:00", "Z"),
        "argv": req.command,
        "limits": req.limits.model_dump(),
        "truncated_logs": truncated_logs,
        "artifacts": [
            "out/result.raw.json",
            "out/logs.jsonl",
            "out/system.jsonl" if (paths["out"] / "system.jsonl").exists() else None,
        ],
        "stderr_snippet": exec_result.stderr_snippet or None,
    }
    payload["artifacts"] = [x for x in payload["artifacts"] if x]
    _write_json_atomic(res_abs["result"], payload)
    return payload


@app.post("/v1/runs", response_model=RunResponse)
def create_run(req: RunRequest, response: Response):
    ok, err = validate_run_id(req.run_id)
    if not ok:
        _http_error(400, req.run_id, req.lab_id, req.submission_id, RunStatus.INVALID_REQUEST, RunReason.INVALID_PAYLOAD, err)

    paths = _workspace_paths(req.run_id)
    if not realpath_within(paths["base"], paths["root"]):
        _http_error(400, req.run_id, req.lab_id, req.submission_id, RunStatus.INVALID_REQUEST, RunReason.WORKSPACE_INVALID, "workspace outside base")

    paths["root"].mkdir(parents=True, exist_ok=True)
    paths["in"].mkdir(parents=True, exist_ok=True)
    paths["out"].mkdir(parents=True, exist_ok=True)

    # Idempotence: if result exists, return it
    res_abs = _result_abs(paths)["result"]
    if res_abs.exists():
        j = _read_json(res_abs) or {}
        started = datetime.fromisoformat(str(j.get("started_at")).replace("Z", "+00:00")) if j.get("started_at") else _utc_now()
        finished = datetime.fromisoformat(str(j.get("finished_at")).replace("Z", "+00:00")) if j.get("finished_at") else _utc_now()
        dur = int(j.get("duration_ms")) if j.get("duration_ms") is not None else None
        return RunResponse(
            run_id=req.run_id,
            lab_id=req.lab_id,
            submission_id=req.submission_id,
            status=RunStatus(str(j.get("status") or RunStatus.FAILED.value)),
            reason=RunReason(str(j.get("reason") or RunReason.NONE.value)),
            exit_code=j.get("exit_code"),
            artifacts=_result_paths(),
            started_at=started,
            finished_at=finished,
            duration_ms=dur,
            resource_observed=j.get("resource_observed"),
            truncated_logs=bool(j.get("truncated_logs", False)),
        )

    # stale lock recovery
    if _is_lock_stale(paths):
        try:
            paths["lock"].unlink(missing_ok=True)
        except Exception:
            pass
        _append_system_event(paths, "STALE_LOCK_RECOVERED")

    # If lock exists now, treat as running
    if paths["lock"].exists():
        response.status_code = 200
        return RunResponse(
            run_id=req.run_id,
            lab_id=req.lab_id,
            submission_id=req.submission_id,
            status=RunStatus.RUNNING,
            reason=RunReason.NONE,
            exit_code=None,
            artifacts=_result_paths(),
            started_at=_utc_now(),
            finished_at=None,
            duration_ms=None,
            resource_observed=None,
            truncated_logs=False,
        )

    # Defense-in-depth: reject symlinks in /in
    for p in paths["in"].rglob("*"):
        try:
            if p.is_symlink():
                _http_error(400, req.run_id, req.lab_id, req.submission_id, RunStatus.INVALID_REQUEST, RunReason.IN_SYMLINK_DETECTED, "symlink in workspace/in")
        except Exception:
            _http_error(400, req.run_id, req.lab_id, req.submission_id, RunStatus.INVALID_REQUEST, RunReason.IN_SYMLINK_DETECTED, "symlink check failed")

    # Validate env and command
    env = filter_env(req.env)
    env = {
        "RBK_RUN_ID": req.run_id,
        "RBK_LAB_ID": req.lab_id,
        "RBK_SUBMISSION_ID": req.submission_id,
        "RBK_MAX_LOG_BYTES": str(get_settings().runnerd_max_log_bytes),
        "RBK_LIMITS_JSON": json.dumps(req.limits.model_dump(), ensure_ascii=False, separators=(",", ":")),
        **env,
    }

    ok_cmd, reason, msg = validate_command(req.command, req.allowed_executables, paths["in"])
    if not ok_cmd:
        # Chosen rule: INVALID_COMMAND => 400
        _http_error(400, req.run_id, req.lab_id, req.submission_id, RunStatus.INVALID_COMMAND, reason, msg)

    container_name = f"rbk-run-{req.run_id}"

    # Create lock atomically
    lock_payload = {
        "run_id": req.run_id,
        "pid": os.getpid(),
        "started_at": _rfc3339_now(),
        "container_name": container_name,
    }
    try:
        _write_json_atomic(paths["lock"], lock_payload)
    except Exception:
        _http_error(500, req.run_id, req.lab_id, req.submission_id, RunStatus.DOCKER_EXEC_FAILED, RunReason.DOCKER_EXEC_FAILED, "failed to create lock")

    started_at = _utc_now()
    settings = get_settings()
    exec_result = run_in_docker(
        container_name=container_name,
        image=settings.runnerd_runner_image,
        workspace_in=paths["in"],
        workspace_out=paths["out"],
        argv=req.command,
        limits=req.limits.model_dump(),
        env=env,
        max_out_bytes=settings.runnerd_max_out_bytes,
    )

    finished_at = _utc_now()
    duration_ms = int((finished_at - started_at).total_seconds() * 1000)

    # Artifacts contract (Model A): runner-base writes out/result.raw.json + out/logs.jsonl.
    # runnerd always writes out/result.json (final, source-of-truth).
    try:
        j = _finalize_result_json(
            paths=paths,
            req=req,
            started_at=started_at,
            finished_at=finished_at,
            duration_ms=duration_ms,
            exec_result=exec_result,
        )
    except Exception:
        _http_error(
            500,
            req.run_id,
            req.lab_id,
            req.submission_id,
            RunStatus.DOCKER_EXEC_FAILED,
            RunReason.DOCKER_EXEC_FAILED,
            "failed to finalize result.json",
        )

    # Remove lock
    try:
        paths["lock"].unlink(missing_ok=True)
    except Exception:
        pass

    response.status_code = 200
    return RunResponse(
        run_id=req.run_id,
        lab_id=req.lab_id,
        submission_id=req.submission_id,
        status=RunStatus(str(j.get("status") or RunStatus.FAILED.value)),
        reason=RunReason(str(j.get("reason") or RunReason.NONE.value)),
        exit_code=j.get("exit_code"),
        artifacts=_result_paths(),
        started_at=started_at,
        finished_at=finished_at,
        duration_ms=duration_ms,
        resource_observed=None,
        truncated_logs=bool(j.get("truncated_logs", False)),
    )


@app.get("/v1/runs/{run_id}", response_model=RunResponse)
def get_run(run_id: str):
    ok, err = validate_run_id(run_id)
    if not ok:
        raise HTTPException(status_code=400, detail={"status": RunStatus.INVALID_REQUEST, "reason": RunReason.INVALID_PAYLOAD, "message": err})

    paths = _workspace_paths(run_id)
    if not paths["root"].exists():
        raise HTTPException(status_code=404, detail={"status": "NOT_FOUND"})

    result_path = paths["out"] / "result.json"
    if result_path.exists():
        j = _read_json(result_path) or {}
        started = datetime.fromisoformat(str(j.get("started_at")).replace("Z", "+00:00")) if j.get("started_at") else _utc_now()
        finished = datetime.fromisoformat(str(j.get("finished_at")).replace("Z", "+00:00")) if j.get("finished_at") else _utc_now()
        dur = int(j.get("duration_ms")) if j.get("duration_ms") is not None else None
        return RunResponse(
            run_id=str(j.get("run_id", run_id)),
            lab_id=str(j.get("lab_id", "")),
            submission_id=str(j.get("submission_id", "")),
            status=RunStatus(str(j.get("status") or RunStatus.FAILED.value)),
            reason=RunReason(str(j.get("reason") or RunReason.NONE.value)),
            exit_code=j.get("exit_code"),
            artifacts=_result_paths(),
            started_at=started,
            finished_at=finished,
            duration_ms=dur,
            resource_observed=j.get("resource_observed"),
            truncated_logs=bool(j.get("truncated_logs", False)),
        )

    if paths["lock"].exists():
        return RunResponse(
            run_id=run_id,
            lab_id="",
            submission_id="",
            status=RunStatus.RUNNING,
            reason=RunReason.NONE,
            exit_code=None,
            artifacts=_result_paths(),
            started_at=_utc_now(),
            finished_at=None,
            duration_ms=None,
            resource_observed=None,
            truncated_logs=False,
        )

    # Workspace exists but no lock and no result.
    # Deterministic rule:
    # - If there are runner artifacts (logs or system events), return FAILED WORKSPACE_INVALID (never 500).
    # - Otherwise consider it unknown/incomplete and return 404.
    logs_fp = paths["out"] / "logs.jsonl"
    sys_fp = paths["out"] / "system.jsonl"
    if logs_fp.exists() or sys_fp.exists():
        return RunResponse(
            run_id=run_id,
            lab_id="",
            submission_id="",
            status=RunStatus.FAILED,
            reason=RunReason.WORKSPACE_INVALID,
            exit_code=None,
            artifacts=_result_paths(),
            started_at=_utc_now(),
            finished_at=_utc_now(),
            duration_ms=None,
            resource_observed=None,
            truncated_logs=False,
        )

    raise HTTPException(status_code=404, detail={"status": "NOT_FOUND"})
