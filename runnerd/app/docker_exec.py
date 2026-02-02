from __future__ import annotations

import subprocess
import time
import re
from pathlib import Path
from dataclasses import dataclass
from typing import Dict, List, Optional

@dataclass(frozen=True)
class ExecutionResult:
    exit_code: Optional[int]
    timed_out: bool
    docker_failed: bool
    oom_killed_hint: bool
    pids_limit_hint: bool
    stderr_snippet: str
    out_bytes_exceeded: bool


def _docker_cmd(
    *,
    container_name: str,
    image: str,
    workspace_in: Path,
    workspace_out: Path,
    user_argv: List[str],
    limits: Dict[str, object],
    env: Dict[str, str],
) -> List[str]:
    # Note: workspace_in mounted RO, workspace_out RW
    cmd: List[str] = [
        "docker",
        "run",
        "--name",
        container_name,
        "--network",
        "none",
        "--read-only",
        "--cap-drop",
        "ALL",
        "--security-opt",
        "no-new-privileges",
        "--pids-limit",
        str(int(limits["pids"])),
        "--memory",
        f"{int(limits['mem_mb'])}m",
        "--memory-swap",
        f"{int(limits['mem_mb'])}m",
        "--cpus",
        str(float(limits["cpu"])),
        "--user",
        "1000:1000",
        "--workdir",
        "/workspace/in",
        "--tmpfs",
        "/tmp:rw,noexec,nosuid,nodev,size=64m",
        "-v",
        f"{workspace_in}:/workspace/in:ro",
        "-v",
        f"{workspace_out}:/workspace/out:rw",
    ]

    # deny-by-default: only RBK_* from runnerd
    for k, v in env.items():
        cmd.extend(["-e", f"{k}={v}"])

    cmd.append(image)
    # Hard lock: runner-base entrypoint is the only writer of out/result.json and out/logs.jsonl.
    cmd.extend(["/runner/entrypoint.py", "--"])
    cmd.extend(user_argv)
    return cmd


def run_in_docker(
    *,
    container_name: str,
    image: str,
    workspace_in: Path,
    workspace_out: Path,
    argv: List[str],
    limits: Dict[str, object],
    env: Dict[str, str],
    max_out_bytes: int,
) -> ExecutionResult:
    timeout_s = int(limits["timeout_s"])

    cmd = _docker_cmd(
        container_name=container_name,
        image=image,
        workspace_in=workspace_in,
        workspace_out=workspace_out,
        user_argv=argv,
        limits=limits,
        env=env,
    )

    # Ensure host dirs exist to avoid docker creating them as root-owned unexpectedly
    workspace_in.mkdir(parents=True, exist_ok=True)
    workspace_out.mkdir(parents=True, exist_ok=True)

    proc = subprocess.Popen(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, text=True)

    deadline = time.monotonic() + timeout_s
    while True:
        rc = proc.poll()
        if rc is not None:
            break
        if time.monotonic() > deadline:
            # hard kill container
            try:
                subprocess.run(["docker", "rm", "-f", container_name], check=False, capture_output=True, text=True)
            except Exception:
                pass
            proc.kill()
            return ExecutionResult(
                exit_code=None,
                timed_out=True,
                docker_failed=False,
                oom_killed_hint=False,
                pids_limit_hint=False,
                stderr_snippet="",
                out_bytes_exceeded=False,
            )
        time.sleep(0.2)

    stderr = ""
    try:
        stderr = (proc.stderr.read() if proc.stderr else "")
    except Exception:
        stderr = ""

    stderr_snippet = (stderr or "")
    if len(stderr_snippet) > 4000:
        stderr_snippet = stderr_snippet[:4000]

    exit_code = int(rc) if rc is not None else None

    # Docker failure heuristic: non-zero exit before container starts often yields stderr.
    docker_failed = bool(exit_code and exit_code != 0 and "Error" in stderr_snippet)

    # Hints only (heuristic): only claim when matching strict known patterns.
    oom_patterns = [
        r"\boom\b",
        r"\bout of memory\b",
        r"\bmemory limit\b",
        r"\bkilled\s+process\b",
        r"\bexit code\s+137\b",
    ]
    pids_patterns = [
        r"\bfork\b.*\bresource temporarily unavailable\b",
        r"\bresource temporarily unavailable\b",
        r"\bcan't start new thread\b",
        r"\bunable to create new native thread\b",
        r"\bprocess limit\b",
    ]
    oom_hint = any(re.search(p, stderr_snippet, flags=re.IGNORECASE) for p in oom_patterns)
    pids_hint = any(re.search(p, stderr_snippet, flags=re.IGNORECASE) for p in pids_patterns)

    # Out size check (hard threshold)
    out_bytes_exceeded = False
    try:
        total = 0
        for p in workspace_out.rglob("*"):
            if p.is_file():
                total += p.stat().st_size
        if total > max_out_bytes:
            out_bytes_exceeded = True
    except Exception:
        return ExecutionResult(
            exit_code=exit_code,
            timed_out=False,
            docker_failed=True,
            oom_killed_hint=False,
            pids_limit_hint=False,
            stderr_snippet=stderr_snippet,
            out_bytes_exceeded=False,
        )

    # Always cleanup container to avoid residue (we removed --rm to enable post-mortem inspect if needed later)
    try:
        subprocess.run(["docker", "rm", "-f", container_name], check=False, capture_output=True, text=True)
    except Exception:
        pass

    return ExecutionResult(
        exit_code=exit_code,
        timed_out=False,
        docker_failed=docker_failed,
        oom_killed_hint=oom_hint,
        pids_limit_hint=pids_hint,
        stderr_snippet=stderr_snippet,
        out_bytes_exceeded=out_bytes_exceeded,
    )
