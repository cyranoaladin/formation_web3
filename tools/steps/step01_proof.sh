#!/usr/bin/env bash
set -euo pipefail
echo "Proof: .warp directory structure"
find .warp -maxdepth 1 -type d | sort
for d in .warp/rules .warp/skills .warp/workflows; do
  echo "Contents of $d:"
  ls -la "$d"
done
