from fastapi import APIRouter
from pathlib import Path
import json
import os

router = APIRouter()


@router.get("")
def list_labs():
    repo_root = Path(os.getenv("RBK_REPO_ROOT", "/repo"))
    if not repo_root.exists():
        repo_root = Path(__file__).resolve().parents[3]
    labs_root = repo_root / "labs" / "specs"
    labs = []

    if not labs_root.exists():
        return {"labs": labs}

    for lab_dir in sorted([p for p in labs_root.iterdir() if p.is_dir()]):
        lab_path = lab_dir / "lab.json"
        if not lab_path.is_file():
            continue
        try:
            data = json.loads(lab_path.read_text(encoding="utf-8"))
        except Exception:
            continue

        labs.append(
            {
                "lab_id": data.get("lab_id", lab_dir.name),
                "title": data.get("title", "Untitled Lab"),
                "description": data.get("description", ""),
                "status": "active",
            }
        )

    return {"labs": labs}
