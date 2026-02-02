"""Unit tests for finalize_result_json (no Docker dependency)."""

from __future__ import annotations

import json
from datetime import datetime, timezone
from pathlib import Path

import runnerd.app.main as runnerd_main
from runnerd.app.docker_exec import ExecutionResult
from runnerd.app.models import RunRequest


def _utc_dt() -> datetime:
    return datetime(2026, 1, 1, 0, 0, 0, tzinfo=timezone.utc)


def _write_text(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8")


def _write_json(path: Path, obj: dict) -> None:
    _write_text(path, json.dumps(obj, ensure_ascii=False))


def _base_req(run_id: str) -> RunRequest:
    return RunRequest(
        run_id=run_id,
        lab_id="lab_demo",
        submission_id="sub_demo",
        command=["python3", "-c", "print('ok')"],
        allowed_executables=["python3"],
        limits={"timeout_s": 5, "cpu": 1.0, "mem_mb": 256, "pids": 128},
        env={},
    )


def test_finalize_raw_present_ok(tmp_path: Path) -> None:
    run_id = "run_test_0001"
    paths = {
        "base": tmp_path,
        "root": tmp_path / run_id,
        "in": tmp_path / run_id / "in",
        "out": tmp_path / run_id / "out",
        "lock": tmp_path / run_id / ".lock.json",
    }
    (paths["out"]).mkdir(parents=True, exist_ok=True)

    _write_json(
        paths["out"] / "result.raw.json",
        {
            "exit_code": 0,
            "started_at": "2026-01-01T00:00:00Z",
            "finished_at": "2026-01-01T00:00:01Z",
            "argv": ["python3", "-c", "print('ok')"],
            "truncated_logs": False,
        },
    )

    exec_result = ExecutionResult(
        exit_code=0,
        timed_out=False,
        docker_failed=False,
        oom_killed_hint=False,
        pids_limit_hint=False,
        stderr_snippet="",
        out_bytes_exceeded=False,
    )

    j = runnerd_main._finalize_result_json(
        paths=paths,
        req=_base_req(run_id),
        started_at=_utc_dt(),
        finished_at=_utc_dt(),
        duration_ms=0,
        exec_result=exec_result,
    )

    assert j["status"] == "OK"
    assert j["reason"] == "NONE"
    assert j["exit_code"] == 0
    assert "out/result.raw.json" in j["artifacts"]
    assert "out/logs.jsonl" in j["artifacts"]


def test_finalize_raw_missing_not_docker_failed(tmp_path: Path) -> None:
    run_id = "run_test_0002"
    paths = {
        "base": tmp_path,
        "root": tmp_path / run_id,
        "in": tmp_path / run_id / "in",
        "out": tmp_path / run_id / "out",
        "lock": tmp_path / run_id / ".lock.json",
    }
    (paths["out"]).mkdir(parents=True, exist_ok=True)

    exec_result = ExecutionResult(
        exit_code=None,
        timed_out=False,
        docker_failed=False,
        oom_killed_hint=False,
        pids_limit_hint=False,
        stderr_snippet="",
        out_bytes_exceeded=False,
    )

    j = runnerd_main._finalize_result_json(
        paths=paths,
        req=_base_req(run_id),
        started_at=_utc_dt(),
        finished_at=_utc_dt(),
        duration_ms=0,
        exec_result=exec_result,
    )

    assert j["status"] == "FAILED"
    assert j["reason"] == "ARTIFACT_WRITE_FAILED"


def test_finalize_raw_missing_docker_failed(tmp_path: Path) -> None:
    run_id = "run_test_0003"
    paths = {
        "base": tmp_path,
        "root": tmp_path / run_id,
        "in": tmp_path / run_id / "in",
        "out": tmp_path / run_id / "out",
        "lock": tmp_path / run_id / ".lock.json",
    }
    (paths["out"]).mkdir(parents=True, exist_ok=True)

    exec_result = ExecutionResult(
        exit_code=None,
        timed_out=False,
        docker_failed=True,
        oom_killed_hint=False,
        pids_limit_hint=False,
        stderr_snippet="Error: failed",
        out_bytes_exceeded=False,
    )

    j = runnerd_main._finalize_result_json(
        paths=paths,
        req=_base_req(run_id),
        started_at=_utc_dt(),
        finished_at=_utc_dt(),
        duration_ms=0,
        exec_result=exec_result,
    )

    assert j["status"] == "FAILED"
    assert j["reason"] == "DOCKER_EXEC_FAILED"


def test_finalize_raw_invalid_json_treated_as_missing(tmp_path: Path) -> None:
    run_id = "run_test_0004"
    paths = {
        "base": tmp_path,
        "root": tmp_path / run_id,
        "in": tmp_path / run_id / "in",
        "out": tmp_path / run_id / "out",
        "lock": tmp_path / run_id / ".lock.json",
    }
    (paths["out"]).mkdir(parents=True, exist_ok=True)

    _write_text(paths["out"] / "result.raw.json", "{not_json")

    exec_result = ExecutionResult(
        exit_code=None,
        timed_out=False,
        docker_failed=False,
        oom_killed_hint=False,
        pids_limit_hint=False,
        stderr_snippet="",
        out_bytes_exceeded=False,
    )

    j = runnerd_main._finalize_result_json(
        paths=paths,
        req=_base_req(run_id),
        started_at=_utc_dt(),
        finished_at=_utc_dt(),
        duration_ms=0,
        exec_result=exec_result,
    )

    assert j["status"] == "FAILED"
    assert j["reason"] == "ARTIFACT_WRITE_FAILED"
