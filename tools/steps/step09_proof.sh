#!/usr/bin/env bash
set -euo pipefail
echo "----- .gitignore (first 30 lines) -----"
awk 'NR<=30{print}' .gitignore
echo "----- git status (porcelain) -----"
git status --porcelain
