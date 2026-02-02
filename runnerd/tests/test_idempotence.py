"""runnerd idempotence and state machine tests (no Docker dependency)."""

from __future__ import annotations

import json
import time
from pathlib import Path
from datetime import datetime, timezone

import runnerd.app.main as runnerd_main
from runnerd.app.docker_exec import ExecutionResult
from runnerd.app.models import RunReason, RunStatus


def _write_json(path: Path, data: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")


def _utc_iso() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def test_post_returns_final_when_result_exists(runnerd_client):
    run_id = "run_test_0001"
    workspaces_dir = Path(runnerd_main.get_settings().runnerd_workspaces_dir)
    out_dir = workspaces_dir / run_id / "out"

    _write_json(
        out_dir / "result.json",
        {
            "run_id": run_id,
            "lab_id": "lab_demo",
            "submission_id": "sub_demo",
            "status": "OK",
            "reason": "NONE",
            "exit_code": 0,
            "argv": ["python3", "-c", "print('OK')"],
            "limits": {"timeout_s": 5, "cpu": 1.0, "mem_mb": 256, "pids": 128},
            "started_at": "2026-01-01T00:00:00Z",
            "finished_at": "2026-01-01T00:00:01Z",
            "duration_ms": 1000,
            "euid": 1000,
            "egid": 1000,
            "cap_eff": "0000000000000000",
            "artifacts": {"logs": "out/logs.jsonl", "result": "out/result.json"},
            "truncated_logs": False,
        },
    )

    resp = runnerd_client.post(
        "/v1/runs",
        json={
            "run_id": run_id,
            "lab_id": "lab_demo",
            "submission_id": "sub_demo",
            "command": ["python3", "-c", "print('OK')"],
            "allowed_executables": ["python3"],
            "limits": {"timeout_s": 5, "cpu": 1.0, "mem_mb": 256, "pids": 128},
            "env": {"RBK_FOO": "bar"},
        },
    )

    assert resp.status_code == 200
    body = resp.json()
    assert body["status"] == "OK"
    assert body["reason"] == "NONE"


def test_post_returns_running_when_lock_exists(runnerd_client):
    run_id = "run_test_0002"
    workspaces_dir = Path(runnerd_main.get_settings().runnerd_workspaces_dir)
    ws_root = workspaces_dir / run_id
    ws_root.mkdir(parents=True, exist_ok=True)

    lock_path = ws_root / ".lock.json"
    _write_json(
        lock_path,
        {
            "run_id": run_id,
            "pid": 123,
            "started_at": _utc_iso(),
            "container_name": f"rbk-run-{run_id}",
        },
    )

    resp = runnerd_client.post(
        "/v1/runs",
        json={
            "run_id": run_id,
            "lab_id": "lab_demo",
            "submission_id": "sub_demo",
            "command": ["python3", "-c", "print('OK')"],
            "allowed_executables": ["python3"],
            "limits": {"timeout_s": 5, "cpu": 1.0, "mem_mb": 256, "pids": 128},
            "env": {"RBK_FOO": "bar"},
        },
    )

    assert resp.status_code == 200
    body = resp.json()
    assert body["status"] == "RUNNING"


def test_post_stale_lock_recovery_writes_system_jsonl(monkeypatch, runnerd_client):
    run_id = "run_test_0003"
    workspaces_dir = Path(runnerd_main.get_settings().runnerd_workspaces_dir)
    ws_root = workspaces_dir / run_id
    in_dir = ws_root / "in"
    out_dir = ws_root / "out"
    in_dir.mkdir(parents=True, exist_ok=True)
    out_dir.mkdir(parents=True, exist_ok=True)

    stale_started_at = "2026-01-01T00:00:00Z"
    _write_json(
        ws_root / ".lock.json",
        {
            "run_id": run_id,
            "pid": 123,
            "started_at": stale_started_at,
            "container_name": f"rbk-run-{run_id}",
        },
    )

    # Ensure lock is considered stale (fixture sets stale_after_s=1)
    time.sleep(1.1)

    def _fake_run_in_docker(**kwargs):
        ws_out = kwargs["workspace_out"]
        _write_json(
            ws_out / "result.raw.json",
            {
                "exit_code": 1,
                "started_at": "2026-01-01T00:00:00Z",
                "finished_at": "2026-01-01T00:00:01Z",
                "argv": ["python3", "-c", "print('OK')"],
                "truncated_logs": False,
            },
        )
        (ws_out / "logs.jsonl").write_text("", encoding="utf-8")
        return ExecutionResult(
            exit_code=1,
            timed_out=False,
            docker_failed=False,
            oom_killed_hint=False,
            pids_limit_hint=False,
            stderr_snippet="",
            out_bytes_exceeded=False,
        )

    monkeypatch.setattr(runnerd_main, "run_in_docker", _fake_run_in_docker)

    resp = runnerd_client.post(
        "/v1/runs",
        json={
            "run_id": run_id,
            "lab_id": "lab_demo",
            "submission_id": "sub_demo",
            "command": ["python3", "-c", "print('OK')"],
            "allowed_executables": ["python3"],
            "limits": {"timeout_s": 5, "cpu": 1.0, "mem_mb": 256, "pids": 128},
            "env": {"RBK_FOO": "bar"},
        },
    )

    assert resp.status_code == 200
    body = resp.json()
    assert body["status"] in {"FAILED", "RUNNING"}

    sys_fp = out_dir / "system.jsonl"
    assert sys_fp.exists()
    line = json.loads(sys_fp.read_text(encoding="utf-8").splitlines()[-1])
    assert "ts" in line and isinstance(line["ts"], str) and len(line["ts"]) > 0
    assert line["stream"] == "system"
    assert line["message"] == "STALE_LOCK_RECOVERED"


def test_get_404_when_workspace_absent(runnerd_client):
    resp = runnerd_client.get("/v1/runs/run_test_0004")
    assert resp.status_code == 404


def test_get_running_when_lock_exists(runnerd_client):
    run_id = "run_test_0005"
    workspaces_dir = Path(runnerd_main.get_settings().runnerd_workspaces_dir)
    ws_root = workspaces_dir / run_id
    ws_root.mkdir(parents=True, exist_ok=True)
    _write_json(
        ws_root / ".lock.json",
        {
            "run_id": run_id,
            "pid": 123,
            "started_at": "2026-01-01T00:00:00Z",
            "container_name": f"rbk-run-{run_id}",
        },
    )

    resp = runnerd_client.get(f"/v1/runs/{run_id}")
    assert resp.status_code == 200
    assert resp.json()["status"] == "RUNNING"


def test_get_final_when_result_exists(runnerd_client):
    run_id = "run_test_0006"
    workspaces_dir = Path(runnerd_main.get_settings().runnerd_workspaces_dir)
    out_dir = workspaces_dir / run_id / "out"

    _write_json(
        out_dir / "result.json",
        {
            "run_id": run_id,
            "lab_id": "lab_demo",
            "submission_id": "sub_demo",
            "status": "FAILED",
            "reason": "DOCKER_EXEC_FAILED",
            "exit_code": 1,
            "argv": ["python3", "-c", "print('OK')"],
            "limits": {"timeout_s": 5, "cpu": 1.0, "mem_mb": 256, "pids": 128},
            "started_at": "2026-01-01T00:00:00Z",
            "finished_at": "2026-01-01T00:00:01Z",
            "duration_ms": 1000,
            "euid": 1000,
            "egid": 1000,
            "cap_eff": "0000000000000000",
            "artifacts": {"logs": "out/logs.jsonl", "result": "out/result.json"},
            "truncated_logs": False,
        },
    )

    resp = runnerd_client.get(f"/v1/runs/{run_id}")
    assert resp.status_code == 200
    body = resp.json()
    assert body["status"] == "FAILED"
    assert body["reason"] == "DOCKER_EXEC_FAILED"


def test_get_failed_workspace_invalid_when_workspace_exists_but_no_result_no_lock_but_system_log_exists(runnerd_client):
    run_id = "run_test_0007"
    workspaces_dir = Path(runnerd_main.get_settings().runnerd_workspaces_dir)
    out_dir = workspaces_dir / run_id / "out"
    out_dir.mkdir(parents=True, exist_ok=True)

    sys_fp = out_dir / "system.jsonl"
    sys_fp.write_text(
        json.dumps({"ts": "2026-01-01T00:00:00Z", "stream": "system", "message": "STALE_LOCK_RECOVERED"}) + "\n",
        encoding="utf-8",
    )

    resp = runnerd_client.get(f"/v1/runs/{run_id}")
    assert resp.status_code == 200
    body = resp.json()
    assert body["status"] == "FAILED"
    assert body["reason"] == "WORKSPACE_INVALID"
