#!/usr/bin/env bash
set -euo pipefail

python3 - <<'PY'
from pathlib import Path
import re

p = Path("api/app/main.py")
s = p.read_text(encoding="utf-8")

if "CORSMiddleware" in s and "app.add_middleware(CORSMiddleware" in s:
    print("OK: CORS already enabled in api/app/main.py")
    raise SystemExit(0)

if "from fastapi.middleware.cors import CORSMiddleware" not in s:
    s = re.sub(
        r'(?m)^from fastapi import (.*)$',
        lambda m: m.group(0) + "\nfrom fastapi.middleware.cors import CORSMiddleware",
        s,
        count=1
    )

m = re.search(r'(?m)^app\s*=\s*FastAPI\(', s)
if not m:
    raise SystemExit("ERROR: cannot find app = FastAPI(...) in api/app/main.py")

insert = """
app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "http://localhost:3000",
        "http://127.0.0.1:3000",
    ],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)
""".strip() + "\n\n"

lines = s.splitlines(True)
idx = None
for i, line in enumerate(lines):
    if re.match(r'^app\s*=\s*FastAPI\(', line):
        idx = i
        break

j = idx
while j < len(lines) and not lines[j].rstrip().endswith(")"):
    j += 1
if j >= len(lines):
    raise SystemExit("ERROR: could not locate end of FastAPI(...) call")

k = j + 1
while k < len(lines) and (lines[k].strip() == "" or lines[k].lstrip().startswith("#")):
    k += 1

lines.insert(k, insert)
p.write_text("".join(lines), encoding="utf-8")
print("OK: added CORS middleware to api/app/main.py")
PY

docker compose up -d --build --force-recreate api

curl -sS -m 3 http://localhost:8000/health ; echo
