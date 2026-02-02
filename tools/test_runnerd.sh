#!/usr/bin/env bash
set -euo pipefail

python3 -m venv .venv-runnerd
. .venv-runnerd/bin/activate
python -m pip install -U pip
python -m pip install -r runnerd/requirements.txt
python -m pytest -q runnerd/tests
