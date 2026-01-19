#!/usr/bin/env bash
set -euo pipefail
# Stage only the warp config, runner, and step scripts created/used here
git add .warp tools/run.sh tools/steps/step*.sh .gitignore
# Commit with co-author attribution as required
GIT_COMMITTER_DATE="$(date -R)" git commit -m "chore(warp): bootstrap rules, skills, workflows, runner" -m "Co-Authored-By: Warp <agent@warp.dev>"
