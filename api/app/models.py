from pydantic import BaseModel, Field
from typing import Optional, Dict, Any
from datetime import datetime
import uuid

def gen_id(prefix: str) -> str:
    return f"{prefix}_{uuid.uuid4().hex}"

class Health(BaseModel):
    status: str = "ok"
    service: str = "rbk-api"

class SubmissionCreateResponse(BaseModel):
    submission_id: str
    status: str
    upload_id: str

class SubmissionDoc(BaseModel):
    submission_id: str = Field(default_factory=lambda: gen_id("sub"))
    student_id: str
    lab_id: str
    status: str = "queued"  # queued -> processing -> needs_review/done/failed
    upload_path: str
    upload_sha256: str
    created_at: datetime = Field(default_factory=datetime.utcnow)
    updated_at: datetime = Field(default_factory=datetime.utcnow)
    latest_run_id: Optional[str] = None

class AutogradeRunDoc(BaseModel):
    run_id: str = Field(default_factory=lambda: gen_id("run"))
    submission_id: str
    status: str = "queued"
    created_at: datetime = Field(default_factory=datetime.utcnow)
    updated_at: datetime = Field(default_factory=datetime.utcnow)
    runner: Dict[str, Any] = Field(default_factory=dict)
    result: Dict[str, Any] = Field(default_factory=dict)
