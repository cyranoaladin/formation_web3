from fastapi import APIRouter, HTTPException, Depends
from pydantic import BaseModel
from typing import List, Optional
from ..db import get_db
from ..models import SubmissionDoc

router = APIRouter()

class ReviewRequest(BaseModel):
    decision: str  # "approved" | "rejected"
    feedback: Optional[str] = ""

@router.get("/pending", response_model=List[SubmissionDoc])
def list_pending_submissions():
    db = get_db()
    # Find all submissions with status 'needs_review'
    cursor = db.submissions.find({"status": "needs_review"}, {"_id": 0})
    return list(cursor)

@router.post("/verify/{submission_id}")
def verify_submission(submission_id: str, review: ReviewRequest):
    db = get_db()
    submission = db.submissions.find_one({"submission_id": submission_id})
    
    if not submission:
        raise HTTPException(status_code=404, detail="submission_not_found")
    
    if submission.get("status") != "needs_review":
        raise HTTPException(status_code=400, detail="submission_not_pending_review")

    new_status = "completed" if review.decision == "approved" else "failed"
    
    db.submissions.update_one(
        {"submission_id": submission_id},
        {
            "$set": {
                "status": new_status, 
                "mentor_feedback": review.feedback,
                "mentor_decision": review.decision
            }
        }
    )
    
    return {"status": "ok", "new_status": new_status}
