
from __future__ import annotations

# --- std / third-party ---
from pathlib import Path
from typing import Any, Dict, List
import json, os

from fastapi import FastAPI, UploadFile, File, Form
from fastapi.responses import JSONResponse
from fastapi.staticfiles import StaticFiles

from PIL import Image, ImageDraw, ImageFilter
import numpy as np

from reportlab.lib.pagesizes import A4
from reportlab.pdfgen import canvas
from reportlab.lib.utils import ImageReader
from reportlab.pdfbase import pdfmetrics

# --- paths / app ---
BASE_DIR = Path(__file__).parent.resolve()
INBOX = BASE_DIR / "ai_inbox"
INBOX.mkdir(parents=True, exist_ok=True)

app = FastAPI()
app.mount("/files", StaticFiles(directory=str(INBOX)), name="files")

# --- helpers (без RTL и без TTF) ---
def _shape_rtl(text: str, locale: str) -> str:
    lc = (locale or "en").split("-",1)[0].lower()
    if not isinstance(text, str):
        text = str(text)
    if lc in ("ar","fa","ur","he"):
        return text[::-1]  # простая «визуальная» инверсия как заглушка
    return text

def _ensure_fonts() -> None:
    # Ничего не регистрируем — используем core Helvetica
    return
def _top_flags(feats, k: int):
    return []

    def draw_img(path, x, y):
        try:
            img = ImageReader(str(path))
            maxw, maxh = 240, 240
            c.drawImage(img, x, y- maxh + 20, width=maxw, height=maxh, preserveAspectRatio=True, anchor="sw")
        except Exception:
            pass
    left_png  = root / "heatmap_left.png"
    right_png = root / "heatmap_right.png"
    draw_img(left_png, 40,  h-320)
    draw_img(right_png, 320, h-320)
    c.showPage()
    c.save()
    return str(pdf_path)

# --- routes ---
@app.get("/")
def root():
    return {"status": "ok"}

@app.post("/analyze")
async def analyze(
    exam_id: str = Form(...),
    age: int = Form(...),
    gender: str = Form(...),
    locale: str = Form(default="en"),
    task: str = Form(default=""),
    left: UploadFile = File(...),
    right: UploadFile = File(...),
):
    Limg = Image.open(left.file).convert("RGB")
    Rimg = Image.open(right.file).convert("RGB")

    L = _score_map_and_features(Limg)
    R = _score_map_and_features(Rimg)

    out_dir = INBOX / exam_id
    out_dir.mkdir(parents=True, exist_ok=True)

    _save_heatmap_png(L["score_array"], out_dir / "heatmap_left.png")
    _save_heatmap_png(R["score_array"], out_dir / "heatmap_right.png")

    result = {
        "exam_id": exam_id,
        "age": age,
        "gender": gender,
        "task_received": task,
        "left": {
            "quality": L["quality"],
            "quality_flags": _flags_quality(L["quality"]),
            "top_zones": _top_flags([], 5),
            "score_map": "saved",
        },
        "right": {
            "quality": R["quality"],
            "quality_flags": _flags_quality(R["quality"]),
            "top_zones": _top_flags([], 5),
            "score_map": "saved",
        },
    }

    _save_report(exam_id, result)
    _save_report_txt(exam_id, result, out_dir)
    result["text_summary"] = _synthesize_text(result)
    _save_report_pdf(exam_id, result, out_dir, locale=locale)
    result["report_pdf"] = f"/files/{exam_id}/report.pdf"
    result["report_txt"] = f"/files/{exam_id}/report.txt"

    return JSONResponse(result)
def _score_map_and_features(img: Image.Image) -> Dict[str, Any]:
    arr = np.asarray(img.convert("L"), dtype=np.float32)
    gx = np.zeros_like(arr, dtype=np.float32)
    gy = np.zeros_like(arr, dtype=np.float32)
    gx[:, 1:] = np.abs(np.diff(arr, axis=1))
    gy[1:, :] = np.abs(np.diff(arr, axis=0))
    g = gx + gy
    mn, mx = float(g.min()), float(g.max())
    if mx > mn:
        g = (g - mn) / (mx - mn)
    else:
        g = np.zeros_like(g, dtype=np.float32)
    return {"quality": _basic_quality(img), "features": [], "score_array": g}



def _pick_font(locale: str | None) -> str:
    return "Helvetica"



from reportlab.pdfbase import pdfmetrics

def _wrap_lines_for_pdf(text: str, max_width: float, font_name: str, font_size: int, locale: str) -> list[str]:
    words = text.split(" ")
    lines = []
    line = ""
    for w in words:
        cand = (line + " " + w).strip()
        if pdfmetrics.stringWidth(cand, "Helvetica", font_size) <= max_width:
            line = cand
        else:
            if line:
                lines.append(line)
            line = w
    if line:
        lines.append(line)
    return [_shape_rtl(l, locale) for l in lines]



def _basic_quality(img: Image.Image) -> Dict[str, float]:
    g = np.asarray(img.convert("L"), dtype=np.uint8)
    bright = float(g.mean()/255.0)
    glare = float((g > 245).mean())
    gx = np.abs(np.diff(g.astype(np.float32), axis=1)).mean()
    gy = np.abs(np.diff(g.astype(np.float32), axis=0)).mean()
    sharp_lapvar = float(gx + gy)
    return {"brightness": bright, "glare": glare, "sharp_lapvar": sharp_lapvar}



def _flags_quality(q: Dict[str, float]) -> Dict[str, Any]:
    flags, ok = [], True
    if q.get("brightness", 0) < 0.12:
        ok = False; flags.append({"code":"too_dark","msg":"Недостаточная освещённость"})
    if q.get("glare", 0) > 0.12:
        ok = False; flags.append({"code":"glare","msg":"Сильные блики"})
    if q.get("sharp_lapvar", 0) < 1.0:
        ok = False; flags.append({"code":"blurry","msg":"Низкая резкость"})
    return {"ok": ok, "flags": flags}

