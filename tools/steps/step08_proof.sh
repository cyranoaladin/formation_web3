#!/usr/bin/env bash
set -euo pipefail
echo "Proof: executable flags"
find tools -maxdepth 2 -type f -name "*.sh" -exec stat -c '%A %n' {} + | sort
