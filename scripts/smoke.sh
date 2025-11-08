#!/usr/bin/env bash
set -euo pipefail
cd /Users/rs/Downloads/iris_health
source .venv/bin/activate
python3 - <<'PY'
from PIL import Image,ImageDraw
for n,c in [("L.jpg","gray"),("R.jpg","lightgray")]:
    im=Image.new("RGB",(1000,1000),c)
    d=ImageDraw.Draw(im)
    d.ellipse((350,350,650,650),outline="black",width=8)
    d.ellipse((470,470,530,530),outline="black",width=8)
    im.save(n,quality=90)
print("[OK] test images ready")
PY
curl -sS -w "\nHTTP=%{http_code}\n" -o resp.json -X POST "http://127.0.0.1:${PORT:-8000}/analyze" \
  -F exam_id=TST001 -F age=31 -F gender=F -F locale=ru -F task=smoke \
  -F left=@L.jpg -F right=@R.jpg
python3 - <<'PY'
import json, pathlib
j=json.loads(pathlib.Path("resp.json").read_text())
print(j["text_summary"])
p=pathlib.Path("ai_inbox/TST001/report.txt")
q=pathlib.Path("ai_inbox/TST001/report.pdf")
print("[TXT]",p.exists(),p.stat().st_size,"[PDF]",q.exists(),q.stat().st_size)
PY
