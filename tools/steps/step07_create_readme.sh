#!/usr/bin/env bash
set -euo pipefail
cat > .warp/README.md <<'EOF'
# Warp Configuration for this Repo

## How Warp must operate
- All actions are file-backed. Terminal execution only runs existing files.
- Steps are atomic and single-purpose. One step = one responsibility.
- Every step defines proofs; without proofs, do not proceed.
- Ambiguity => STOP and request human validation.

## Not allowed
- No long inline shell commands or heredocs in the terminal.
- No mixing pasted commands with pasted outputs.
- No guessing file locations; always verify paths.

## Running steps
- Use the runner to execute steps:
  - `tools/run.sh tools/steps/<step>.sh`
- Logs are written under `tools/logs/`.
- For final verification of this setup, run `tools/steps/step99_summary.sh` via the runner.
EOF
