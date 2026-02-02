from __future__ import annotations

from datetime import datetime
from enum import Enum
from typing import Any, Dict, List, Literal, Optional

from pydantic import BaseModel, Field


class RunStatus(str, Enum):
    OK = "OK"
    FAILED = "FAILED"
    TIMEOUT = "TIMEOUT"
    RESOURCE_LIMIT = "RESOURCE_LIMIT"
    INVALID_REQUEST = "INVALID_REQUEST"
    INVALID_COMMAND = "INVALID_COMMAND"
    DOCKER_EXEC_FAILED = "DOCKER_EXEC_FAILED"
    RUNNING = "RUNNING"


class RunReason(str, Enum):
    NONE = "NONE"
    INVALID_PAYLOAD = "INVALID_PAYLOAD"
    WORKSPACE_INVALID = "WORKSPACE_INVALID"
    IN_SYMLINK_DETECTED = "IN_SYMLINK_DETECTED"
    COMMAND_FORMAT_NOT_ARGV = "COMMAND_FORMAT_NOT_ARGV"
    EXECUTABLE_NOT_ALLOWED = "EXECUTABLE_NOT_ALLOWED"
    ARGUMENT_NOT_ALLOWED = "ARGUMENT_NOT_ALLOWED"
    DOCKER_EXEC_FAILED = "DOCKER_EXEC_FAILED"
    TIMEOUT_HARD = "TIMEOUT_HARD"
    PIDS_LIMIT = "PIDS_LIMIT"
    MEMORY_LIMIT = "MEMORY_LIMIT"
    OUTPUT_LIMIT_EXCEEDED = "OUTPUT_LIMIT_EXCEEDED"
    SYMLINK_ESCAPE_ATTEMPT = "SYMLINK_ESCAPE_ATTEMPT"
    ARTIFACT_WRITE_FAILED = "ARTIFACT_WRITE_FAILED"


class RunLimits(BaseModel):
    timeout_s: int = Field(..., ge=1, le=3600)
    cpu: float = Field(..., gt=0, le=8)
    mem_mb: int = Field(..., ge=64, le=16384)
    pids: int = Field(..., ge=16, le=4096)


class RunRequest(BaseModel):
    run_id: str
    lab_id: str
    submission_id: str
    command: List[str]
    allowed_executables: List[str]
    limits: RunLimits
    env: Dict[str, str] = Field(default_factory=dict)


class RunArtifacts(BaseModel):
    result_json_path: str
    logs_jsonl_path: str


class RunResponse(BaseModel):
    run_id: str
    lab_id: str
    submission_id: str
    status: RunStatus
    reason: RunReason
    exit_code: Optional[int]
    artifacts: RunArtifacts
    started_at: datetime
    finished_at: Optional[datetime]
    duration_ms: Optional[int]
    resource_observed: Optional[Dict[str, Any]] = None
    truncated_logs: bool = False
