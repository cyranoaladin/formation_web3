from __future__ import annotations

import os
import re
from pathlib import Path
from typing import Dict, List, Tuple

from .models import RunReason

RUN_ID_RE = re.compile(r"^[a-zA-Z0-9_-]{8,64}$")


def validate_run_id(run_id: str) -> Tuple[bool, str]:
    if not RUN_ID_RE.match(run_id):
        return False, "run_id_invalid_format"
    return True, ""


def realpath_within(base: Path, target: Path) -> bool:
    base_r = base.resolve()
    target_r = target.resolve()
    try:
        return str(target_r).startswith(str(base_r) + os.sep) or target_r == base_r
    except Exception:
        return False


def filter_env(env: Dict[str, str]) -> Dict[str, str]:
    allowed: Dict[str, str] = {}
    for k, v in env.items():
        if k.startswith("RBK_"):
            allowed[k] = v
    return allowed


def validate_command(
    command: List[str],
    allowed_executables: List[str],
    workspace_in: Path,
) -> Tuple[bool, RunReason, str]:
    if not isinstance(command, list) or not command or any(not isinstance(x, str) for x in command):
        return False, RunReason.COMMAND_FORMAT_NOT_ARGV, "command must be a non-empty string[]"

    exe = command[0]
    if exe not in allowed_executables:
        return False, RunReason.EXECUTABLE_NOT_ALLOWED, "executable not allowed"

    if exe == "bash":
        # Strict: bash <relative_script> only, no flags
        if len(command) < 2:
            return False, RunReason.ARGUMENT_NOT_ALLOWED, "bash requires script arg"
        if command[1].startswith("-"):
            return False, RunReason.ARGUMENT_NOT_ALLOWED, "bash flags not allowed"
        script_rel = command[1]
        if os.path.isabs(script_rel) or ".." in Path(script_rel).parts:
            return False, RunReason.ARGUMENT_NOT_ALLOWED, "bash script must be relative and non-traversing"
        script_path = (workspace_in / script_rel).resolve()
        if not realpath_within(workspace_in, script_path):
            return False, RunReason.ARGUMENT_NOT_ALLOWED, "bash script outside workspace/in"
        if script_path.is_symlink():
            return False, RunReason.ARGUMENT_NOT_ALLOWED, "bash script cannot be symlink"
        if not script_path.is_file():
            return False, RunReason.ARGUMENT_NOT_ALLOWED, "bash script not found"
        if len(command) > 2:
            return False, RunReason.ARGUMENT_NOT_ALLOWED, "bash extra args not allowed"

    # Hard forbid shell-like executables
    forbidden = {"sh", "dash", "zsh", "perl", "ruby", "php", "pwsh", "powershell"}
    if exe in forbidden:
        return False, RunReason.EXECUTABLE_NOT_ALLOWED, "executable forbidden"

    return True, RunReason.NONE, ""
