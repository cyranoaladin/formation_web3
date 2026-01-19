#!/usr/bin/env bash
set -euo pipefail
current=$(git symbolic-ref --short HEAD || true)
if [[ "$current" != "main" ]]; then
  git branch -m main
fi
echo "BRANCH_BEFORE=${current}"
