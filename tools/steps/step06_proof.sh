#!/usr/bin/env bash
set -euo pipefail
f=.warp/context.md
echo "Proof: $f exists, size, lines, and sha256"
ls -l "$f"
wc -l "$f"
sha256sum "$f" | awk '{print $1}'
