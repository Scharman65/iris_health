#!/usr/bin/env bash
set -e
cd "$(dirname "$0")"
lsof -tiTCP:8000 -sTCP:LISTEN | xargs -r kill -9
pkill -f "uvicorn .*iris_ai_server" || true
source .venv/bin/activate
exec uvicorn iris_ai_server:app --host 0.0.0.0 --port 8000 --reload
