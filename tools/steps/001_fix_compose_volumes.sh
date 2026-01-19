#!/usr/bin/env bash
set -euo pipefail

python3 - <<'PY'
from pathlib import Path
import re

p = Path("docker-compose.yml")
s = p.read_text(encoding="utf-8")

if not re.search(r'(?m)^services:\s*$', s):
    raise SystemExit("ERROR: no services:")

m = re.search(r'(?ms)^  ui:\n(.*?)(?=^  \S|\Z)', s)
if not m:
    raise SystemExit("ERROR: ui service not found")

ui_block = "  ui:\n" + m.group(1)
if "ui_node_modules:/ui/node_modules" not in ui_block:
    if re.search(r'(?m)^\s{4}volumes:\s*$', ui_block):
        ui_block = re.sub(
            r'(?m)^\s{4}volumes:\s*$',
            "    volumes:\n      - ./ui:/ui\n      - ui_node_modules:/ui/node_modules",
            ui_block
        )
    else:
        ui_block = re.sub(
            r'(?m)^  ui:\n',
            "  ui:\n    volumes:\n      - ./ui:/ui\n      - ui_node_modules:/ui/node_modules\n",
            ui_block
        )

s = s[:m.start()] + ui_block + s[m.end():]

if not re.search(r'(?m)^volumes:\s*$', s):
    s = s.rstrip() + "\n\nvolumes:\n  mongo_data:\n  ui_node_modules:\n"
else:
    if "mongo_data:" not in s:
        s = re.sub(r'(?m)^volumes:\s*$', "volumes:\n  mongo_data:", s)
    if "ui_node_modules:" not in s:
        s = re.sub(r'(?m)^volumes:\s*$', "volumes:\n  mongo_data:\n  ui_node_modules:", s)

p.write_text(s, encoding="utf-8")
print("OK: docker-compose.yml fixed (volumes + ui_node_modules)")
PY

docker compose config >/dev/null
echo "OK: compose config valid"
