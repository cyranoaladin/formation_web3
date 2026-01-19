#!/usr/bin/env bash
set -euo pipefail
cat > .warp/rules/00_global.rules.md <<'EOF'
# Global Rules for Warp Execution

- You are an execution agent, not a chat agent.
- All actions must be file-backed.
- Terminal execution must only run existing files.
- No inline scripts longer than 5 lines.
- Any ambiguous situation must STOP execution.
EOF
