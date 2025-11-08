#!/usr/bin/env bash
set -euo pipefail
cd /Users/rs/Downloads/iris_health
source .venv/bin/activate
exec python3 -m uvicorn iris_ai_server:app --host 0.0.0.0 --port "${PORT:-8000}" --reload
