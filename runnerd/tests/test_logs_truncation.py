"""Unit test for runner-base log truncation (no Docker dependency)."""

from __future__ import annotations

import json
import os
import sys
from pathlib import Path

from runner.entrypoint import main as runner_entrypoint_main


def test_logs_truncation_writes_final_truncated_line(tmp_path: Path, monkeypatch) -> None:
    ws_in = tmp_path / "in"
    ws_out = tmp_path / "out"
    ws_in.mkdir(parents=True, exist_ok=True)
    ws_out.mkdir(parents=True, exist_ok=True)

    # Very small log budget to force truncation.
    monkeypatch.setenv("RBK_WORKSPACE_IN_DIR", str(ws_in))
    monkeypatch.setenv("RBK_WORKSPACE_OUT_DIR", str(ws_out))
    monkeypatch.setenv("RBK_MAX_LOG_BYTES", "1200")

    # Produce lots of output.
    cmd = ["python3", "-c", "print('x'*10000)\nprint('y'*10000, file=__import__('sys').stderr)"]

    old_argv = list(sys.argv)
    try:
        sys.argv = ["/runner/entrypoint.py", "--", *cmd]
        rc = runner_entrypoint_main()
    finally:
        sys.argv = old_argv

    assert rc == 0

    raw = json.loads((ws_out / "result.raw.json").read_text(encoding="utf-8"))
    assert raw["truncated_logs"] is True

    lines = (ws_out / "logs.jsonl").read_text(encoding="utf-8").splitlines()
    assert len(lines) >= 2

    last = json.loads(lines[-1])
    assert last["stream"] == "system"
    assert last["message"] == "TRUNCATED"
    assert last["truncated"] is True
    assert last["reason"] == "MAX_BYTES"

    # Ensure schema is message-based (no legacy keys).
    for ln in lines:
        obj = json.loads(ln)
        assert "message" in obj
        assert "stream" in obj
        assert "ts" in obj
        assert "truncated" in obj
        assert "line" not in obj
        assert "event" not in obj


def test_logs_truncation_invalid_config_fails_fast(tmp_path: Path, monkeypatch) -> None:
    ws_in = tmp_path / "in"
    ws_out = tmp_path / "out"
    ws_in.mkdir(parents=True, exist_ok=True)
    ws_out.mkdir(parents=True, exist_ok=True)

    monkeypatch.setenv("RBK_WORKSPACE_IN_DIR", str(ws_in))
    monkeypatch.setenv("RBK_WORKSPACE_OUT_DIR", str(ws_out))

    # Intentionally too small to ever fit the TRUNCATED line.
    monkeypatch.setenv("RBK_MAX_LOG_BYTES", "10")

    old_argv = list(sys.argv)
    try:
        sys.argv = ["/runner/entrypoint.py", "--", "python3", "-c", "print('x')"]
        rc = runner_entrypoint_main()
    finally:
        sys.argv = old_argv

    assert rc != 0
    raw = json.loads((ws_out / "result.raw.json").read_text(encoding="utf-8"))
    assert raw.get("error")
