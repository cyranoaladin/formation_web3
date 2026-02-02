from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field
from pathlib import Path
from typing import List, Optional
import json
import re

router = APIRouter(prefix="/rag", tags=["rag"])


def _repo_root() -> Path:
    return Path(__file__).resolve().parents[3]


def _load_db() -> List[dict]:
    db_path = Path(
        str(Path(__file__).resolve().parents[3] / "rag" / "db_local.json")
    )
    if not db_path.is_file():
        return []
    try:
        return json.loads(db_path.read_text(encoding="utf-8"))
    except Exception:
        return []


def _score(text: str, query: str, source: str, context_lab_id: Optional[str]) -> int:
    q = query.lower()
    t = text.lower()
    words = [w for w in re.split(r"\W+", q) if len(w) > 2]
    score = sum(1 for w in words if w in t)
    if context_lab_id and context_lab_id == source:
        score += 3
    return score


class RagQuery(BaseModel):
    query: str = Field(..., min_length=1)
    context_lab_id: Optional[str] = None


class RagChunk(BaseModel):
    id: str
    text: str
    source: str
    score: int


class RagResponse(BaseModel):
    system_prompt: str
    chunks: List[RagChunk]


@router.post("/query", response_model=RagResponse)
def rag_query(payload: RagQuery):
    db = _load_db()
    if not db:
        raise HTTPException(status_code=404, detail="rag_db_not_found")

    scored = []
    for item in db:
        text = item.get("text", "")
        source = item.get("source", "")
        s = _score(text, payload.query, source, payload.context_lab_id)
        if s > 0:
            scored.append(
                {
                    "id": item.get("id", ""),
                    "text": text,
                    "source": source,
                    "score": s,
                }
            )

    scored.sort(key=lambda x: x["score"], reverse=True)
    top = scored[:5]

    context_blob = "\n\n".join(
        [f"[source={c['source']}]\n{c['text']}" for c in top]
    )

    system_prompt = (
        "Tu es Zyno, un expert Solana. Utilise le contexte suivant pour repondre a l'etudiant. "
        "Ne donne pas la solution complete, donne des indices.\n\n"
        f"Contexte:\n{context_blob}"
    )

    return RagResponse(
        system_prompt=system_prompt,
        chunks=[RagChunk(**c) for c in top],
    )
