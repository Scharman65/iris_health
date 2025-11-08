from __future__ import annotations

from fastapi import FastAPI, UploadFile, File, Form
from fastapi.responses import JSONResponse
from fastapi.staticfiles import StaticFiles
from pathlib import Path
from typing import Any, Dict, List
from PIL import Image
import numpy as np
import json

# --- reportlab для PDF (Helvetica-только) ---
from reportlab.lib.pagesizes import A4
from reportlab.pdfgen import canvas
from reportlab.pdfbase import pdfmetrics

BASE_DIR = Path(__file__).parent.resolve()
INBOX = BASE_DIR / "ai_inbox"
INBOX.mkdir(parents=True, exist_ok=True)

app = FastAPI()
app.mount("/files", StaticFiles(directory=str(INBOX)), name="files")

@app.get("/health")
async def health():
    return {"status": "ok"}

# --- Текст (упрощённая RTL-заглушка) ---
def _shape_rtl(text: str, locale: str) -> str:
    lc = (locale or "en").split("-",1)[0].lower()
    if not isinstance(text, str):
        text = str(text)
    if lc in ("ar","fa","ur","he"):
        return text[::-1]
    return text

def _wrap_lines_for_pdf(text: str, max_width: float, font_name: str, font_size: int, locale: str) -> List[str]:
    words = text.split(" ")
    lines, line = [], ""
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

# --- Метрики качества и карта скорингов ---
def _basic_quality(img: Image.Image) -> Dict[str, float]:
    g = np.asarray(img.convert("L"), dtype=np.uint8)
    bright = float(g.mean()/255.0)
    glare = float((g > 245).mean())
    gx = np.abs(np.diff(g.astype(np.float32), axis=1)).mean()
    gy = np.abs(np.diff(g.astype(np.float32), axis=0)).mean()
    sharp_lapvar = float(gx + gy)
    return {"brightness": bright, "glare": glare, "sharp_lapvar": sharp_lapvar}

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

def _flags_quality(q: Dict[str, float]) -> Dict[str, Any]:
    flags, ok = [], True
    if q.get("brightness", 0) < 0.12:
        ok = False; flags.append({"code":"too_dark","msg":"Недостаточная освещённость"})
    if q.get("glare", 0) > 0.12:
        ok = False; flags.append({"code":"glare","msg":"Сильные блики"})
    if q.get("sharp_lapvar", 0) < 0.60:
        ok = False; flags.append({"code":"blurry","msg":"Низкая резкость"})
    return {"ok": ok, "flags": flags}

def _top_flags(feats: List[Any], k: int):
    return []

def _save_heatmap_png(arr: np.ndarray, path: Path) -> None:
    a = np.asarray(arr, dtype=np.float32)
    mn, mx = float(a.min()), float(a.max())
    if mx > mn:
        a = (a - mn) / (mx - mn)
    else:
        a = np.zeros_like(a, dtype=np.float32)
    img = Image.fromarray((a*255).clip(0,255).astype('uint8'), mode='L')
    img.save(str(path))

# --- Отчёты ---
def _save_report(exam_id: str, result: Dict[str, Any]) -> None:
    out_dir = INBOX / exam_id
    out_dir.mkdir(parents=True, exist_ok=True)
    (out_dir / "meta.json").write_text(json.dumps({"exam_id": exam_id}, ensure_ascii=False, indent=2), encoding="utf-8")
    (out_dir / "report.json").write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding="utf-8")

def _synthesize_text(result: Dict[str, Any]) -> str:
    Lq = result.get("left",{}).get("quality",{})
    Rq = result.get("right",{}).get("quality",{})
    thr = 0.60
    lz = 1 if float(Lq.get("sharp_lapvar",0.0)) >= thr else 0
    rz = 1 if float(Rq.get("sharp_lapvar",0.0)) >= thr else 0
    lines = [
        "Краткое резюме:",
        f"Левый: ярк={float(Lq.get('brightness',0)):.2f}, блик={float(Lq.get('glare',0)):.2f}, резк={lz}",
        f"Правый: ярк={float(Rq.get('brightness',0)):.2f}, блик={float(Rq.get('glare',0)):.2f}, резк={rz}",
    ]
    return "\n".join(lines)

def _save_report_txt(exam_id: str, result: Dict[str, Any], out_dir: Path) -> None:
    out_dir.mkdir(parents=True, exist_ok=True)
    txt = result.get("text_summary","")
    Lq = result.get("left",{}).get("quality",{})
    Rq = result.get("right",{}).get("quality",{})
    extra = [
        "",
        f"[L] brightness={float(Lq.get('brightness',0)):.4f}, glare={float(Lq.get('glare',0)):.4f}, sharp_lapvar={float(Lq.get('sharp_lapvar',0)):.4f}",
        f"[R] brightness={float(Rq.get('brightness',0)):.4f}, glare={float(Rq.get('glare',0)):.4f}, sharp_lapvar={float(Rq.get('sharp_lapvar',0)):.4f}",
    ]
    txt = (txt or "").rstrip() + "\n" + "\n".join(extra) + "\n"
    (out_dir / "report.txt").write_text(txt, encoding="utf-8")

def _save_report_pdf(exam_id: str, result: Dict[str, Any], out_dir: Path, locale: str = "en") -> None:
    out_dir.mkdir(parents=True, exist_ok=True)
    pdf_path = out_dir / "report.pdf"
    c = canvas.Canvas(str(pdf_path), pagesize=A4)
    w, h = A4
    margin = 36
    y = h - margin

    c.setFont("Helvetica", 16)
    title = f"Iris Report — {exam_id}"
    c.drawString(margin, y, title); y -= 24

    c.setFont("Helvetica", 10)
    summary = result.get("text_summary", "")
    for line in _wrap_lines_for_pdf(summary, w - 2*margin, "Helvetica", 10, locale):
        c.drawString(margin, y, line); y -= 14

    # Вставим heatmap, если есть
    for name in ("heatmap_left.png","heatmap_right.png"):
        p = out_dir / name
        if p.exists():
            y -= 8
            iw, ih = Image.open(p).size
            scale = min((w - 2*margin)/iw, 220/ih)
            dw, dh = iw*scale, ih*scale
            c.drawImage(str(p), margin, max(margin, y - dh), width=dw, height=dh, preserveAspectRatio=True, anchor='sw')
            y -= dh + 16

    c.showPage()
    c.save()

# --- Основной эндпоинт ---
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
    out_dir = INBOX / exam_id
    out_dir.mkdir(parents=True, exist_ok=True)

    Limg = Image.open(left.file).convert("RGB")
    Rimg = Image.open(right.file).convert("RGB")

    L = _score_map_and_features(Limg)
    R = _score_map_and_features(Rimg)

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
            "top_zones": _top_flags(L["features"], 5),
            "score_map": "saved",
        },
        "right": {
            "quality": R["quality"],
            "quality_flags": _flags_quality(R["quality"]),
            "top_zones": _top_flags(R["features"], 5),
            "score_map": "saved",
        },
    }

    result["text_summary"] = _synthesize_text(result)
    _save_report(exam_id, result)
    _save_report_txt(exam_id, result, out_dir)
    _save_report_pdf(exam_id, result, out_dir, locale=locale)
    result["report_pdf"] = f"/files/{exam_id}/report.pdf"
    result["report_txt"] = f"/files/{exam_id}/report.txt"
    return JSONResponse(result)
