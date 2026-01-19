#!/usr/bin/env bash
set -euo pipefail
cat > .warp/skills/run_step.skill.md <<'EOF'
# Skill: run_step
- Purpose: execute a single step script
- Input: step filename
- Output: log file + stdout
- Usage: tools/run.sh <step>
EOF

cat > .warp/skills/diagnose.skill.md <<'EOF'
# Skill: diagnose
- Purpose: collect system state (ps, logs, curl)
- Output: raw, unmodified diagnostics
EOF

cat > .warp/skills/verify.skill.md <<'EOF'
# Skill: verify
- Purpose: check proofs against expectations
- Output: PASS / FAIL only
EOF
