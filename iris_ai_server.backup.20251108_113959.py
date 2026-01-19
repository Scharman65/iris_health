from fastapi import FastAPI, UploadFile, File, Form
from fastapi.responses import JSONResponse
from fastapi.staticfiles import StaticFiles
from pathlib import Path
from typing import Any, Dict, List
from PIL import Image
import numpy as np
import json

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

def _shape_rtl(text: str, locale: str) -> str:
    lc = (locale or "en").split("-",1)[0].lower()
    if not isinstance(text, str):
        text = str(text)
    if lc in ("ar","fa","ur","he"):
        return text[::-1]
    return text

def _wrap_lines_for_pdf(text: str, max_width: float, font_name: str, font_size: int, locale: str) -> List[str]:
    words = text.split(" ")
    lines, cur = [], ""
    for w in words:
        test = (cur + " " + w).strip()
        if pdfmetrics.stringWidth(test, "Helvetica", font_size) <= max_width:
            cur = test
        else:
            if cur:
                lines.append(cur)
            cur = w
    if cur:
        lines.append(cur)
    return [_shape_rtl(l, locale) for l in lines]

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
        ok=False; flags.append({"code":"too_dark","msg":"Недостаточная освещённость"})
    if q.get("glare", 0) > 0.12:
        ok=False; flags.append({"code":"glare","msg":"Сильные блики"})
    if q.get("sharp_lapvar", 0) < 1.0:
        ok=False; flags.append({"code":"blurry","msg":"Низкая резкость"})
    return {"ok": ok, "flags": flags}

def _top_flags(feats, k: int):
    return []

def _synthesize_text(result: Dict[str, Any]) -> str:
    L = result["left"]["quality"]; R = result["right"]["quality"]
    lz = 1 if L.get("sharp_lapvar",0) >= 1.0 else 0
    rz = 1 if R.get("sharp_lapvar",0) >= 1.0 else 0
    return (
        "Краткое резюме:\n"
        f"Левый: ярк={L.get('brightness',0):.2f}, блик={L.get('glare',0):.2f}, резк={lz}\n"
        f"Правый: ярк={R.get('brightness',0):.2f}, блик={R.get('glare',0):.2f}, резк={rz}"
    )

def _save_report(exam_id: str, data: Dict[str, Any]) -> None:
    out_dir = INBOX / exam_id
    out_dir.mkdir(parents=True, exist_ok=True)
    (out_dir / "report.json").write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")
    (out_dir / "meta.json").write_text(json.dumps({"exam_id": exam_id}, ensure_ascii=False), encoding="utf-8")

def _save_report_txt(exam_id: str, data: Dict[str, Any], out_dir: Path) -> str:
    txt = data.get("text_summary","")
    p = out_dir / "report.txt"
    p.write_text(txt, encoding="utf-8")
    return str(p)

def _save_heatmap_png(arr: np.ndarray, path: Path) -> None:
    a = np.asarray(arr, dtype=np.float32)
    if a.size == 0:
        return
    a = np.nan_to_num(a, nan=0.0, posinf=0.0, neginf=0.0)
    mn, mx = float(a.min()), float(a.max())
    if mx > mn:
        a = (a - mn) / (mx - mn)
    else:
        a = np.zeros_like(a, dtype=np.float32)
    img = Image.fromarray((a * 255).astype("uint8"), mode="L")
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    img.save(str(path))

def _save_report_pdf(exam_id: str, data: Dict[str, Any], out_dir: Path, locale: str = "en") -> str:
    pdf_path = out_dir / "report.pdf"
    c = canvas.Canvas(str(pdf_path), pagesize=A4)
    w, h = A4
    margin = 36
    y = h - margin
    c.setFont("Helvetica", 16)
    c.drawString(margin, y, f"Exam ID: {exam_id}")
    y -= 22
    c.setFont("Helvetica", 12)
    c.drawString(margin, y, f"Age/Gender: {data.get('age','?')}/{data.get('gender','?')}")
    y -= 24

    def para(text: str):
        nonlocal y
        for line in _wrap_lines_for_pdf(text, max_width=w-2*margin, font_name="Helvetica", font_size=11, locale=locale):
            if y < margin + 40:
                c.showPage(); y = h - margin; c.setFont("Helvetica", 11)
            c.drawString(margin, y, line)
            y -= 14

    para("Summary:")
    c.setFont("Helvetica", 11)
    para(data.get("text_summary",""))

    for side in ("left","right"):
        y -= 10
        c.setFont("Helvetica", 12); para(("Левый" if side=="left" else "Правый") + " глаз:")
        q = data[side]["quality"]
        c.setFont("Helvetica", 11)
        para(f"brightness={q.get('brightness',0):.3f}, glare={q.get('glare',0):.3f}, sharp_idx={q.get('sharp_lapvar',0):.3f}")

    c.showPage()
    c.save()
    return str(pdf_path)

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

    out_dir = INBOX / exam_id
    out_dir.mkdir(parents=True, exist_ok=True)

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

    _save_report(exam_id, result)
    _save_report_txt(exam_id, result, out_dir)
    result["text_summary"] = _synthesize_text(result)
    _save_report_pdf(exam_id, result, out_dir, locale=locale)
    result["report_pdf"] = f"/files/{exam_id}/report.pdf"
    result["report_txt"] = f"/files/{exam_id}/report.txt"

    return JSONResponse(result)
