
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
    if not isinstance(text, str):
        text = str(text)
    return text

def _ensure_fonts() -> None:
    # Используем core Helvetica из ReportLab — ничего регистрировать не надо
    return None

def _wrap_lines_for_pdf(text: str, max_width: float, font_name: str, font_size: int, locale: str) -> List[str]:
    words = str(text).split(" ")
    lines, cur = [], ""
    for w in words:
        cand = (cur + " " + w).strip()
        if pdfmetrics.stringWidth(cand, "Helvetica", font_size) <= max_width:
            cur = cand
        else:
            if cur:
                lines.append(cur)
            cur = w
    if cur:
        lines.append(cur)
    return [ _shape_rtl(line, locale) for line in lines ]

# --- simple image analytics ---
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
    if q.get("brightness", 0) < 0.12: ok=False; flags.append({"code":"too_dark","msg":"Недостаточная освещённость"})
    if q.get("glare", 0) > 0.12: ok=False; flags.append({"code":"glare","msg":"Сильные блики"})
    if q.get("sharp_lapvar", 0) < 1500: ok=False; flags.append({"code":"blurry","msg":"Низкая резкость"})
    return {"ok": ok, "flags": flags}

def _score_map_and_features(img: Image.Image) -> Dict[str, Any]:
    # Простейшая «теплокарта» по градиенту (для smoke-теста)
    arr = np.asarray(img.convert("L"), dtype=np.float32)
    gx = np.abs(np.diff(arr, axis=1))
    gy = np.abs(np.diff(arr, axis=0))
    g = np.zeros_like(arr)
    g[:-1, :-1] = gx[:, :-1] + gy[:-1, :]
    if g.max() > g.min():
        g = (g - g.min()) / (g.max() - g.min())
    return {
        "quality": _basic_quality(img),
        "features": [],  # заглушка
        "score_array": g,
    }

def _top_flags(feats: List[Dict[str,Any]], k: int) -> List[Dict[str,Any]]:
    return []  # заглушка для smoke

# --- report writers ---
def _save_report(exam_id: str, result: dict) -> None:
    out_dir = INBOX / exam_id
    out_dir.mkdir(parents=True, exist_ok=True)
    (out_dir / "report.json").write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding="utf-8")
    (out_dir / "meta.json").write_text(json.dumps({"exam_id": exam_id}, ensure_ascii=False), encoding="utf-8")

def _save_report_txt(exam_id: str, result: dict, root: Path) -> None:
    lines = []
    lines.append(f"ID: {exam_id}")
    lines.append(f"Age: {result.get('age')}")
    lines.append(f"Gender: {result.get('gender')}")
    lines.append("")
    lines.append("== LEFT ==")
    lines.append(json.dumps(result.get("left", {}), ensure_ascii=False))
    lines.append("")
    lines.append("== RIGHT ==")
    lines.append(json.dumps(result.get("right", {}), ensure_ascii=False))
    (root / "report.txt").write_text("\n".join(lines), encoding="utf-8")

def _save_heatmap_png(score_array: np.ndarray, path: Path) -> None:
    # простая серошкальная карта
    arr = np.clip(score_array * 255.0, 0, 255).astype(np.uint8)
    im = Image.fromarray(arr, mode="L").convert("RGB")
    im = im.resize((800, 800))
    d = ImageDraw.Draw(im)
    d.rectangle((50,50,750,750), outline="black", width=4)
    im.save(path, quality=90)

def _synthesize_text(result: dict) -> str:
    Lq = result["left"]["quality"]; Rq = result["right"]["quality"]
    def fmt(q): return f"ярк={q['brightness']:.2f}, блик={q['glare']:.2f}, резк={q['sharp_lapvar']:.0f}"
    return "Краткое резюме:\nЛевый: " + fmt(Lq) + "\nПравый: " + fmt(Rq)

def _save_report_pdf(exam_id: str, result: dict, root: Path, locale: str = "en") -> str:
    _ensure_fonts()
    pdf_path = root / "report.pdf"
    c = canvas.Canvas(str(pdf_path), pagesize=A4)
    w, h = A4
    margin_x = 40
    y = h - 40

    title = f"Iris Auto-Report • ID={result.get('exam_id') or exam_id} • Age={result.get('age')} • Gender={result.get('gender')}"
    title = _shape_rtl(title, locale)
    c.setFont("Helvetica", 12)
    c.drawString(margin_x, y, title); y -= 24

    txt = result.get("text_summary") or result.get("summary") or "No text summary"
    txt = _shape_rtl(str(txt), locale)
    c.setFont("Helvetica", 10)
    max_width = w - margin_x*2
    for para in str(txt).splitlines():
        lines = _wrap_lines_for_pdf(para, max_width, "Helvetica", 10, locale)
        for line in lines:
            if y < 160:
                c.showPage(); y = h - 40; c.setFont("Helvetica", 10)
            c.drawString(margin_x, y, line); y -= 14
        if y < 160:
            c.showPage(); y = h - 40; c.setFont("Helvetica", 10)

    c.showPage()
    c.setFont("Helvetica", 12)
    c.drawString(margin_x, h-40, _shape_rtl("Heatmaps", locale))
    c.setFont("Helvetica", 10)
    c.drawString(margin_x, h-60, _shape_rtl("Left", locale))
    c.drawString(margin_x+280, h-60, _shape_rtl("Right", locale))
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

