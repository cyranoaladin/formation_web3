from pydantic import BaseModel, Field
from typing import Optional, Dict, Any
from datetime import datetime
import uuid

def gen_id(prefix: str) -> str:
    return f"{prefix}_{uuid.uuid4().hex}"

def gen_id_short(prefix: str) -> str:
    return f"{prefix}_{uuid.uuid4().hex[:16]}"

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
    status: str = "queued"  # queued -> running -> completed/needs_review/failed
    upload_path: str
    upload_sha256: str
    created_at: datetime = Field(default_factory=datetime.utcnow)
    updated_at: datetime = Field(default_factory=datetime.utcnow)
    latest_run_id: Optional[str] = None

class AutogradeRunDoc(BaseModel):
    run_id: str = Field(default_factory=lambda: gen_id_short("run"))
    submission_id: str
    status: str = "queued"
    created_at: datetime = Field(default_factory=datetime.utcnow)
    updated_at: datetime = Field(default_factory=datetime.utcnow)
    runner: Dict[str, Any] = Field(default_factory=dict)
    result: Dict[str, Any] = Field(default_factory=dict)


# --- Canonical minimal models (Step 041) ---
from typing import Optional, Union, Dict, Any, List
from pydantic import BaseModel
from datetime import datetime

class SubmissionCanon(BaseModel):
    submission_id: str
    student_id: Optional[str] = None
    lab_id: Optional[str] = None
    status: str  # queued|running|completed|needs_review|failed
    created_at: datetime
    updated_at: datetime
    upload_id: Optional[str] = None
    error: Optional[str] = None
    run_id: Optional[str] = None
    proof_bundle_id: Optional[str] = None

class AutogradeRunCanon(BaseModel):
    run_id: str
    submission_id: str
    status: str  # queued|running|completed|failed
    created_at: datetime
    updated_at: datetime
    score_auto: Optional[int] = None
    decision_hint: Optional[str] = None

class ProofBundleCanon(BaseModel):
    proof_bundle_id: str
    run_id: str
    created_at: datetime
    artifacts: Union[Dict[str, Any], List[Any]]
    immutable: bool = True
    sha256: Optional[str] = None
