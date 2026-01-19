#!/usr/bin/env bash
set -euo pipefail
f=.warp/README.md
echo "Proof: $f exists, size, lines, and sha256"
ls -l "$f"
wc -l "$f"
sha256sum "$f" | awk '{print $1}'
