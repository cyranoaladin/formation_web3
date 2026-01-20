#!/usr/bin/env python3
from __future__ import annotations

import sys
from pathlib import Path

def die(msg: str, code: int = 1) -> None:
    print(f"[safe_patch] ERROR: {msg}", file=sys.stderr)
    raise SystemExit(code)

def read(path: Path) -> str:
    return path.read_text(encoding="utf-8")

def write_atomic(path: Path, content: str) -> None:
    tmp = path.with_suffix(path.suffix + ".tmp")
    tmp.write_text(content, encoding="utf-8")
    tmp.replace(path)

def ensure_contains(path: Path, snippet: str) -> bool:
    """
    Ajoute `snippet` à la fin du fichier si absent.
    Retourne True si modification.
    """
    s = read(path)
    if snippet in s:
        print(f"[safe_patch] OK: already present in {path}")
        return False
    write_atomic(path, s.rstrip() + "\n\n" + snippet.strip() + "\n")
    print(f"[safe_patch] OK: appended to {path}")
    return True

def main() -> None:
    if len(sys.argv) < 2:
        die("Usage: tools/safe_patch.py <target-file>")

    target = Path(sys.argv[1])
    if not target.exists():
        die(f"Target file not found: {target}")

    # Patch “exemple” (ne fait rien de destructif) : ajoute un marqueur commenté
    snippet = "# patched-by: tools/safe_patch.py\n"
    ensure_contains(target, snippet)

if __name__ == "__main__":
    main()
