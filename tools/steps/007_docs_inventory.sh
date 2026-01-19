#!/usr/bin/env bash
set -euo pipefail

mkdir -p tools/logs
ts="$(date +%Y%m%d_%H%M%S)"
out="tools/logs/docs_inventory_${ts}.txt"

ls -la *.md .warp/*.md 2>/dev/null | tee "$out"

echo
echo "MD_FILES_COUNT=$(ls -1 *.md 2>/dev/null | wc -l | tr -d ' ')"
echo "WARP_MD_COUNT=$(ls -1 .warp/*.md 2>/dev/null | wc -l | tr -d ' ')"
echo "LOG=$out"
