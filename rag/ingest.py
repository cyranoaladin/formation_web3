import json
import os
import re
from html.parser import HTMLParser
from pathlib import Path
from typing import List, Dict, Iterable, Tuple

CHUNK_SIZE = 500


def chunk_text(text: str, size: int) -> List[str]:
    chunks = []
    buf = []
    count = 0
    for token in text.split():
        if count + len(token) + 1 > size and buf:
            chunks.append(" ".join(buf))
            buf = [token]
            count = len(token)
        else:
            buf.append(token)
            count += len(token) + 1
    if buf:
        chunks.append(" ".join(buf))
    return chunks


def load_text(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8")
    except Exception:
        return ""

class _HTMLTextExtractor(HTMLParser):
    def __init__(self) -> None:
        super().__init__()
        self._chunks: List[str] = []
        self._skip_depth = 0

    def handle_starttag(self, tag: str, attrs):
        if tag in {"script", "style"}:
            self._skip_depth += 1

    def handle_endtag(self, tag: str):
        if tag in {"script", "style"} and self._skip_depth > 0:
            self._skip_depth -= 1

    def handle_data(self, data: str):
        if self._skip_depth:
            return
        text = data.strip()
        if text:
            self._chunks.append(text)

    def text(self) -> str:
        return " ".join(self._chunks)

def extract_text_from_html(path: Path) -> str:
    try:
        raw = path.read_text(encoding="utf-8")
    except Exception:
        return ""
    parser = _HTMLTextExtractor()
    try:
        parser.feed(raw)
    except Exception:
        return ""
    text = parser.text()
    text = re.sub(r"\s+", " ", text).strip()
    return text

def iter_chapter_files(chapters_root: Path) -> Iterable[Tuple[Path, str]]:
    # Focus on track_solana_n1.html and tech_*.html
    if not chapters_root.exists():
        return []
    files = []
    track = chapters_root / "track_solana_n1.html"
    if track.is_file():
        files.append(track)
    files.extend(sorted(chapters_root.glob("tech_*.html")))
    return [(p, p.stem) for p in files if p.is_file()]


def main() -> None:
    root = Path(__file__).resolve().parents[1]
    labs_root = root / "labs" / "specs"
    knowledge_path = root / "rag" / "knowledge" / "solana_security_canon.md"
    out_path = root / "rag" / "db_local.json"
    chapters_root = Path(os.getenv("RBK_CHAPTERS_DIR", "/home/alaeddine/Bureau/chapters"))

    records: List[Dict[str, str]] = []

    if knowledge_path.is_file():
        canon_text = load_text(knowledge_path)
        for i, chunk in enumerate(chunk_text(canon_text, CHUNK_SIZE), start=1):
            records.append(
                {
                    "id": f"canon_chunk_{i}",
                    "text": chunk,
                    "source": "canon",
                }
            )

    if labs_root.exists():
        for lab_dir in sorted([p for p in labs_root.iterdir() if p.is_dir()]):
            instr = lab_dir / "INSTRUCTIONS.md"
            if not instr.is_file():
                continue
            text = load_text(instr)
            if not text.strip():
                continue
            for i, chunk in enumerate(chunk_text(text, CHUNK_SIZE), start=1):
                records.append(
                    {
                        "id": f"{lab_dir.name}_chunk_{i}",
                        "text": chunk,
                        "source": lab_dir.name,
                    }
                )

    # Syllabus chapters (HTML)
    if chapters_root.exists():
        for path, source in iter_chapter_files(chapters_root):
            text = extract_text_from_html(path)
            if not text:
                continue
            for i, chunk in enumerate(chunk_text(text, CHUNK_SIZE), start=1):
                records.append(
                    {
                        "id": f"{source}_chunk_{i}",
                        "text": chunk,
                        "source": f"chapters/{source}",
                    }
                )

    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text(json.dumps(records, ensure_ascii=True, indent=2), encoding="utf-8")


if __name__ == "__main__":
    main()
