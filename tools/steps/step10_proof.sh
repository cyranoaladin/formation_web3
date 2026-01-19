#!/usr/bin/env bash
set -euo pipefail
git --no-pager log -1 --pretty=fuller --decorate
echo
git --no-pager show -1 --name-status --stat
