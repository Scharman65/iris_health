import os
import uuid
from fastapi import FastAPI, UploadFile, File
from fastapi.responses import FileResponse, JSONResponse

from iris_ai_server.utils.logger import log
from iris_ai_server.utils.image_tools import load_image
from iris_ai_server.analysis.evaluator import evaluate_iris

# Новый PDF-движок v2
from iris_ai_server.pdf.engine_v2 import generate_pdf_v2


app = FastAPI(
    title="IRIDA 2025 AI Server",
    version="0.6.1"
)


# -------------------------------------------------------
# HEALTH
# -------------------------------------------------------
@app.get("/health")
async def health():
    return {"status": "ok"}


# -------------------------------------------------------
# ВСПОМОГАТЕЛЬНАЯ ФУНКЦИЯ: СОХРАНИТЬ ВРЕМЕННОЕ ФОТО
# -------------------------------------------------------
def save_temp(img, filename: str):
    temp_dir = "iris_ai_server/pdf/tmp"
    os.makedirs(temp_dir, exist_ok=True)

    path = os.path.join(temp_dir, filename)
    img.save(path, format="JPEG", optimize=True, quality=95)
    return path


# -------------------------------------------------------
# ANALYZE ENDPOINT
# -------------------------------------------------------
@app.post("/analyze")
async def analyze(
    file_left: UploadFile = File(...),
    file_right: UploadFile = File(...)
):
    log("Получены файлы радужек")

    # ---------- ЗАГРУЗКА БАЙТОВ ----------
    left_bytes = await file_left.read()
    right_bytes = await file_right.read()

    # ---------- В ИЗОБРАЖЕНИЯ ----------
    img_left = load_image(left_bytes)
    img_right = load_image(right_bytes)

    # ---------- ВРЕМЕННОЕ СОХРАНЕНИЕ ДЛЯ PDF ----------
    left_tmp_path = save_temp(img_left, f"left_{uuid.uuid4().hex}.jpg")
    right_tmp_path = save_temp(img_right, f"right_{uuid.uuid4().hex}.jpg")

    # ---------- АНАЛИЗ ----------
    left_model = evaluate_iris(img_left)
    right_model = evaluate_iris(img_right)

    left_dict = left_model.model_dump()
    right_dict = right_model.model_dump()

    # ---------- ТЕКСТОВОЕ ОБОБЩЕНИЕ ----------
    text_summary = (
        f"Левый глаз: {left_dict['diagnosis']}. "
        f"Правый глаз: {right_dict['diagnosis']}."
    )

    # ---------- PDF ----------
    try:
        pdf_filename = generate_pdf_v2(
            left_dict,
            right_dict,
            text_summary,
            left_img_path=left_tmp_path,
            right_img_path=right_tmp_path
        )

        pdf_url = f"/report/{pdf_filename}" if pdf_filename else None

    except Exception as e:
        log(f"[IRIDA] Ошибка PDF: {e}")
        pdf_url = None

    # ---------- ОТВЕТ ----------
    return {
        "left": left_dict,
        "right": right_dict,
        "text_summary": text_summary,
        "pdf_url": pdf_url
    }


# -------------------------------------------------------
# REPORT FILES
# -------------------------------------------------------
@app.get("/report/{filename}")
async def get_report(filename: str):
    path = os.path.join("iris_ai_server", "storage", "reports", filename)

    if not os.path.exists(path):
        return JSONResponse(
            status_code=404,
            content={"detail": "Report not found"}
        )

    return FileResponse(
        path,
        media_type="application/pdf",
        filename=filename
    )

