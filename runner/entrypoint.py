#!/usr/bin/env python3
from __future__ import annotations

import json
import os
import selectors
import subprocess
import sys
import time
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import IO, Any, Dict, List, Optional, Tuple


def _utc_iso() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def _atomic_write_json(path: Path, payload: Dict[str, Any]) -> None:
    tmp = path.with_suffix(path.suffix + ".tmp")
    tmp.write_text(json.dumps(payload, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
    tmp.replace(path)


@dataclass
class _LogState:
    max_bytes: int
    reserved_bytes: int
    writable_bytes: int
    written_bytes: int
    truncated: bool


def _safe_int(value: str, default: int) -> int:
    try:
        return int(value)
    except Exception:
        return default


def _parse_argv(argv: List[str]) -> List[str]:
    if not argv or argv[0] != "--":
        return argv
    return argv[1:]


def _write_log_line(fp: IO[str], state: _LogState, obj: Dict[str, Any]) -> None:
    if state.truncated:
        return
    line = json.dumps(obj, ensure_ascii=False, separators=(",", ":")) + "\n"
    b = line.encode("utf-8")
    if state.written_bytes + len(b) > state.writable_bytes:
        state.truncated = True
        return
    fp.write(line)
    fp.flush()
    state.written_bytes += len(b)


def _drain_streams_to_logs(
    *,
    proc: subprocess.Popen[str],
    logs_fp: IO[str],
    state: _LogState,
) -> None:
    sel = selectors.DefaultSelector()

    def _register(pipe: Optional[IO[str]], stream_name: str) -> None:
        if pipe is None:
            return
        try:
            sel.register(pipe, selectors.EVENT_READ, data=stream_name)
        except Exception:
            return

    _register(proc.stdout, "stdout")
    _register(proc.stderr, "stderr")

    while sel.get_map():
        events = sel.select(timeout=0.2)
        if not events:
            if proc.poll() is not None:
                break
            continue
        for key, _mask in events:
            pipe = key.fileobj
            stream_name = str(key.data)
            try:
                chunk = pipe.readline()
            except Exception:
                chunk = ""
            if chunk == "":
                try:
                    sel.unregister(pipe)
                except Exception:
                    pass
                continue
            _write_log_line(
                logs_fp,
                state,
                {"ts": _utc_iso(), "stream": stream_name, "message": chunk.rstrip("\n"), "truncated": False},
            )

    for p in (proc.stdout, proc.stderr):
        if p is None:
            continue
        while True:
            try:
                chunk = p.readline()
            except Exception:
                chunk = ""
            if chunk == "":
                break
            _write_log_line(
                logs_fp,
                state,
                {
                    "ts": _utc_iso(),
                    "stream": "stdout" if p is proc.stdout else "stderr",
                    "message": chunk.rstrip("\n"),
                    "truncated": False,
                },
            )


def main() -> int:
    workspace_in_dir = Path(os.environ.get("RBK_WORKSPACE_IN_DIR", "/workspace/in"))
    out_dir = Path(os.environ.get("RBK_WORKSPACE_OUT_DIR", "/workspace/out"))
    out_dir.mkdir(parents=True, exist_ok=True)

    logs_path = out_dir / "logs.jsonl"
    result_path = out_dir / "result.raw.json"

    started_at = _utc_iso()

    user_argv = _parse_argv(sys.argv[1:])

    max_log_bytes = _safe_int(os.environ.get("RBK_MAX_LOG_BYTES", ""), 200_000)
    limits_json = os.environ.get("RBK_LIMITS_JSON", "{}")
    try:
        limits = json.loads(limits_json)
        if not isinstance(limits, dict):
            limits = {}
    except Exception:
        limits = {}

    exit_code: Optional[int] = None
    error: Optional[str] = None

    # Truncation MUST always emit a final TRUNCATED line.
    # We reserve exactly the UTF-8 bytes required for that line so it is always writable.
    trunc_line_obj = {
        "ts": _utc_iso(),
        "stream": "system",
        "message": "TRUNCATED",
        "truncated": True,
        "reason": "MAX_BYTES",
    }
    trunc_line_bytes = (
        json.dumps(trunc_line_obj, ensure_ascii=False, separators=(",", ":")) + "\n"
    ).encode("utf-8")
    reserved_bytes = len(trunc_line_bytes)
    if max_log_bytes < reserved_bytes:
        error = f"invalid_config: RBK_MAX_LOG_BYTES={max_log_bytes} < RESERVED_BYTES={reserved_bytes}"
        _atomic_write_json(
            out_dir / "result.raw.json",
            {
                "exit_code": None,
                "started_at": started_at,
                "finished_at": _utc_iso(),
                "argv": user_argv,
                "truncated_logs": True,
                "error": error,
            },
        )
        return 1
    writable_bytes = max_log_bytes - reserved_bytes
    state = _LogState(
        max_bytes=max_log_bytes,
        reserved_bytes=reserved_bytes,
        writable_bytes=writable_bytes,
        written_bytes=0,
        truncated=False,
    )

    try:
        with logs_path.open("w", encoding="utf-8") as logs_fp:
            _write_log_line(
                logs_fp,
                state,
                {"ts": _utc_iso(), "stream": "system", "message": "START", "truncated": False},
            )

            if not user_argv:
                exit_code = 127
            else:
                proc = subprocess.Popen(
                    user_argv,
                    cwd=str(workspace_in_dir),
                    text=True,
                    stdout=subprocess.PIPE,
                    stderr=subprocess.PIPE,
                )
                _drain_streams_to_logs(proc=proc, logs_fp=logs_fp, state=state)
                rc = proc.wait()
                exit_code = int(rc)

            _write_log_line(
                logs_fp,
                state,
                {"ts": _utc_iso(), "stream": "system", "message": "END", "truncated": False},
            )

            # TRUNCATED must be the last line.
            if state.truncated:
                logs_fp.write(trunc_line_bytes.decode("utf-8", errors="replace"))
                logs_fp.flush()

    except Exception as e:
        error = f"entrypoint_error: {type(e).__name__}: {e}"
        if exit_code is None:
            exit_code = 1

    finished_at = _utc_iso()
    try:
        runner_version = os.environ.get("RBK_RUNNER_VERSION")
        _atomic_write_json(
            result_path,
            {
                "exit_code": exit_code,
                "started_at": started_at,
                "finished_at": finished_at,
                "argv": user_argv,
                "limits": limits,
                "truncated_logs": bool(state.truncated),
                **({"runner_version": runner_version} if runner_version else {}),
                **({"error": error} if error else {}),
            },
        )
    except Exception:
        return 1

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
