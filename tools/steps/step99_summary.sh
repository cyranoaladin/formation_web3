#!/usr/bin/env bash
set -euo pipefail
echo "TREE of .warp/ (files and directories)"
find .warp -print | sort

echo
for f in $(find .warp -type f | sort); do
  echo "----- BEGIN $f (first 30 lines) -----"
  awk 'NR<=30{print}' "$f"
  echo "----- END $f -----"
  echo
done
