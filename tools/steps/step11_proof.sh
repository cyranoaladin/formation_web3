#!/usr/bin/env bash
set -euo pipefail
echo -n "CURRENT_BRANCH="
git symbolic-ref --short HEAD
