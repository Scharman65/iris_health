from __future__ import annotations

from fastapi import FastAPI, UploadFile, File, Form
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from fastapi.staticfiles import StaticFiles
from pathlib import Path
from typing import Any, Dict, List
from PIL import Image
import numpy as np
import json
from io import BytesIO

# --- reportlab для PDF (Helvetica-только) ---
from reportlab.lib.pagesizes import A4
from reportlab.pdfgen import canvas
from reportlab.pdfbase import pdfmetrics

import time
import os
BASE_DIR = Path(__file__).parent.resolve()
INBOX = BASE_DIR / "ai_inbox"

def _audit_save(exam_dir: "Path", payload: dict, kind: str) -> "Path":
    exam_dir = Path(exam_dir)
    exam_dir.mkdir(parents=True, exist_ok=True)

    ts_ms = int(time.time() * 1000)
    pid = os.getpid()

    out = exam_dir / f"{ts_ms}_{pid}_{kind}_audit.json"
    tmp = exam_dir / f".{out.name}.tmp"

    import json
    data = json.dumps(payload, ensure_ascii=False, indent=2, sort_keys=True)

    tmp.write_text(data, encoding="utf-8")
    tmp.replace(out)
    return out


INBOX.mkdir(parents=True, exist_ok=True)

MAX_UPLOAD_MB = 12
app = FastAPI()
app.add_middleware(CORSMiddleware, allow_origins=['*'], allow_methods=['*'], allow_headers=['*'])
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

    if g.size == 0:
        return {"brightness": 0.0, "glare": 0.0, "sharp_lapvar": 0.0}

    bright = float(g.mean() / 255.0)
    glare = float((g > 245).mean())

    h, w = g.shape[:2]
    if w >= 2:
        gx = float(np.abs(np.diff(g.astype(np.float32), axis=1)).mean())
    else:
        gx = 0.0

    if h >= 2:
        gy = float(np.abs(np.diff(g.astype(np.float32), axis=0)).mean())
    else:
        gy = 0.0

    sharp_lapvar = float(gx + gy)
    if not np.isfinite(sharp_lapvar):
        sharp_lapvar = 0.0

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
def _quality_scalar(q: Dict[str, float]) -> float:
    b = float(q.get("brightness", 0.0))
    g = float(q.get("glare", 0.0))
    sh = float(q.get("sharp_lapvar", 0.0))

    b_score = max(0.0, min(1.0, (b - 0.10) / 0.35))
    g_score = max(0.0, min(1.0, 1.0 - (g / 0.12)))
    sh_score = max(0.0, min(1.0, sh / 1.20))

    return float(max(0.0, min(1.0, 0.35*b_score + 0.25*g_score + 0.40*sh_score)))

def _zones_from_quality(q: Dict[str, float]) -> List[Dict[str, Any]]:
    zones: List[Dict[str, Any]] = []
    if float(q.get("brightness", 0.0)) < 0.12:
        zones.append({"name": "illumination", "score": 0.2, "note": "Недостаточная освещённость"})
    if float(q.get("glare", 0.0)) > 0.12:
        zones.append({"name": "glare", "score": 0.2, "note": "Сильные блики"})
    if float(q.get("sharp_lapvar", 0.0)) < 0.60:
        zones.append({"name": "sharpness", "score": 0.2, "note": "Низкая резкость"})
    if not zones:
        zones.append({"name": "quality_gate", "score": 0.95, "note": "Качество допустимо для анализа"})
    return zones

def _save_eye_file(exam_id: str, side: str, data: bytes) -> Path:
    out_dir = INBOX / exam_id
    out_dir.mkdir(parents=True, exist_ok=True)
    name = "left.jpg" if side == "left" else "right.jpg"
    fp = out_dir / name
    fp.write_bytes(data)
    return fp

def _load_text_file(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8")
    except Exception:
        return ""

PROMPTS_DIR = BASE_DIR / "ai" / "prompts"
CONTRACTS_DIR = BASE_DIR / "ai" / "contracts"
SYSTEM_PROMPT_PATH = PROMPTS_DIR / "system_irida.txt"
USER_TEMPLATE_PATH = PROMPTS_DIR / "user_template.txt"
CONTRACT_PATH = CONTRACTS_DIR / "irida_response.json"

SYSTEM_PROMPT = _load_text_file(SYSTEM_PROMPT_PATH)
USER_TEMPLATE = _load_text_file(USER_TEMPLATE_PATH)
IRIDA_CONTRACT = _load_text_file(CONTRACT_PATH)

@app.post("/analyze-eye")
async def analyze_eye(
    eye: str = Form(...),
    exam_id: str = Form(...),
    age: int = Form(...),
    gender: str = Form(...),
    locale: str = Form(default="en"),
    task: str = Form(default=""),
    file: UploadFile = File(...),
):
    t0 = time.time()
    side = (eye or "").strip().lower()
    if side not in ("left", "right"):
        return JSONResponse(
            {"status": "error", "field": "eye", "filename": None, "content_type": None, "size_bytes": 0, "quality": 0.0, "zones": [], "took_ms": 0},
            status_code=400,
        )

    data = await file.read()
    size_bytes = len(data)

    try:
        img = Image.open(BytesIO(data)).convert("RGB")
    except Exception:
        try:
            img = Image.open(file.file).convert("RGB")
        except Exception as e:
            return JSONResponse(
                {"status": "error", "field": "file", "filename": getattr(file, "filename", None), "content_type": getattr(file, "content_type", None), "size_bytes": size_bytes, "quality": 0.0, "zones": [], "took_ms": int((time.time()-t0)*1000)},
                status_code=400,
            )

    q = _basic_quality(img)
    q_scalar = _quality_scalar(q)

    # --- IRIDA quality gate: reject low-quality images early ---
    try:
        q_threshold = float(os.environ.get("IRIDA_Q_THRESHOLD", "0.60"))
    except Exception:
        q_threshold = 0.60

    if float(q_scalar) < q_threshold:
        took_ms = int((time.time() - t0) * 1000)
        # save file anyway for audit/debug
        fp = _save_eye_file(exam_id, side, data)
        out_dir = INBOX / exam_id
        out_dir.mkdir(parents=True, exist_ok=True)
        try:
            _audit_save(
                out_dir,
                {
                    "event": "analyze_eye",
                    "status": "rejected",
                    "reason": "low_quality",
                    "exam_id": exam_id,
                    "side": side,
                    "age": age,
                    "gender": gender,
                    "locale": locale,
                    "task_received": task,
                    "file_saved": str(fp.name),
                    "size_bytes": size_bytes,
                    "quality_scalar": float(q_scalar),
                    "quality_threshold": float(q_threshold),
                    "took_ms": int((time.time() - t0) * 1000),
                },
                "rejected",
            )
        except Exception:
            pass
        return JSONResponse(
            {
                "status": "rejected",
                "field": "file",
                "filename": getattr(file, "filename", fp.name),
                "content_type": getattr(file, "content_type", "image/jpeg"),
                "size_bytes": size_bytes,
                "quality": float(q_scalar),
                "zones": [
                    {
                        "name": "quality_gate",
                        "score": 0.0,
                        "note": "Качество недостаточно для анализа"
                    }
                ],
                "took_ms": took_ms,
                "reason": "low_quality",
                "recommendation": "retake_photo_better_light_focus_no_glare"
            }
        )

    zones = _zones_from_quality(q)

    fp = _save_eye_file(exam_id, side, data)

    meta = {
        "exam_id": exam_id,
        "age": age,
        "gender": gender,
        "locale": locale,
        "task_received": task,
        "side": side,
        "file_saved": str(fp.name),
        "quality_raw": q,
        "quality_scalar": q_scalar,
        "zones": zones,
        "prompts_present": {
            "system": bool(SYSTEM_PROMPT.strip()),
            "user_template": bool(USER_TEMPLATE.strip()),
            "contract": bool(IRIDA_CONTRACT.strip()),
        },
    }
    out_dir = INBOX / exam_id
    out_dir.mkdir(parents=True, exist_ok=True)
    (out_dir / f"{side}_meta.json").write_text(json.dumps(meta, ensure_ascii=False, indent=2), encoding="utf-8")

    try:
        _audit_save(
            out_dir,
            {
                "event": "analyze_eye",
                "status": "ok",
                "exam_id": exam_id,
                "side": side,
                "age": age,
                "gender": gender,
                "locale": locale,
                "task_received": task,
                "file_saved": str(fp.name),
                "meta_saved": f"{side}_meta.json",
                "size_bytes": size_bytes,
                "quality_scalar": float(q_scalar),
                "zones_count": int(len(zones) if isinstance(zones, list) else 0),
                "took_ms": int((time.time() - t0) * 1000),
            },
            "ok",
        )
    except Exception:
        pass

    took_ms = int((time.time() - t0) * 1000)

    return JSONResponse(
        {
            "status": "ok",
            "field": "file",
            "filename": getattr(file, "filename", fp.name),
            "content_type": getattr(file, "content_type", "image/jpeg"),
            "size_bytes": size_bytes,
            "quality": float(q_scalar),
            "zones": zones,
            "took_ms": took_ms,
        }
    )


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app,
        host="0.0.0.0",
        port=8010,
        reload=False,
        workers=1
    )

