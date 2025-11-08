#!/usr/bin/env bash
set -euo pipefail

PORT="${PORT:-8010}"
PIDFILE="/tmp/iris_ai.${PORT}.pid"
LOGFILE="/tmp/iris_ai.${PORT}.log"
LOCKDIR="/tmp/iris_ai.${PORT}.lock"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VENV="${ROOT}/.venv"
APP="iris_ai_server:app"

if command -v lsof >/dev/null && lsof -ti "tcp:${PORT}" >/dev/null 2>&1; then
  exit 0
fi

if [[ -d "${LOCKDIR}" ]]; then
  exit 0
fi
mkdir "${LOCKDIR}" || exit 0

cleanup() { rm -rf "${LOCKDIR}" || true; }
trap cleanup EXIT

if [[ -f "${PIDFILE}" ]]; then
  OLD="$(cat "${PIDFILE}" || true)"
  if [[ -n "${OLD}" ]] && ps -p "${OLD}" >/dev/null 2>&1; then
    exit 0
  fi
fi

if [[ -d "${VENV}" ]]; then
  source "${VENV}/bin/activate"
fi

cd "${ROOT}"
echo $$ > "${PIDFILE}"

exec uvicorn "${APP}" --host 0.0.0.0 --port "${PORT}" --log-level info >> "${LOGFILE}" 2>&1
