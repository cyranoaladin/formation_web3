#!/usr/bin/env bash
set -euo pipefail
root=$(git rev-parse --show-toplevel 2>/dev/null || true)
pwd=$(pwd)
echo "GIT_ROOT=${root}"
echo "PWD=${pwd}"
if [[ -z "$root" ]]; then
  echo "ERROR: Not inside a git repository." >&2
  exit 2
fi
if [[ "$root" != "$pwd" ]]; then
  echo "ERROR: Not at git repo root." >&2
  exit 3
fi
echo "OK: At git repo root."
