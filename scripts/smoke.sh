#!/usr/bin/env bash
set -e

PORT=${PORT:-8010}
HOST="http://127.0.0.1:$PORT"

echo "[1] Preparing test images..."

if [ ! -f "L.jpg" ] || [ ! -f "R.jpg" ]; then
  echo "[ERR] L.jpg or R.jpg not found"
  exit 1
fi

echo "[OK] test images ready"

JSON=$(curl -fsS -X POST \
  -F "file_left=@L.jpg" \
  -F "file_right=@R.jpg" \
  "$HOST/analyze") || {
    echo "[ERR] analyze failed"
    exit 1
}

echo "HTTP=200"

TXT=$(echo "$JSON" | jq -r '.text_summary')
TXT_OK=False
if [ -n "$TXT" ] && [ "$TXT" != "null" ]; then TXT_OK=True; fi

echo "[TXT] $TXT_OK ${#TXT}"

PDF_URL=$(echo "$JSON" | jq -r '.pdf_url')

PDF_OK=False
if [ "$PDF_URL" != "null" ]; then
  TMP="tmp_test.pdf"
  curl -fsS "$HOST$PDF_URL" --output "$TMP" 2>/dev/null || true

  if [ -s "$TMP" ]; then PDF_OK=True; fi

  rm -f "$TMP"
fi

echo "[PDF] $PDF_OK"

if [ "$TXT_OK" = "True" ] && [ "$PDF_OK" = "True" ]; then
  echo "[ALL GOOD] Smoke test passed"
  exit 0
else
  echo "[WARN] Smoke test has issues"
  exit 1
fi

