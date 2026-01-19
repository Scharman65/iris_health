import os
from datetime import datetime

from reportlab.pdfgen import canvas
from reportlab.lib.pagesizes import A4
from reportlab.lib import colors
from reportlab.lib.units import mm
from reportlab.platypus import Table, TableStyle, Paragraph
from reportlab.lib.styles import getSampleStyleSheet
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont

from iris_ai_server.utils.logger import log


# Папка для готовых PDF
REPORT_DIR = "iris_ai_server/storage/reports"
os.makedirs(REPORT_DIR, exist_ok=True)

# Путь к шрифту
FONT_PATH = os.path.join(
    os.path.dirname(os.path.abspath(__file__)),
    "fonts",
    "DejaVuSans.ttf"
)


# --------------------------------------------------------------
# Титульная страница
# --------------------------------------------------------------
def draw_title_page(c: canvas.Canvas):
    c.setFillColor("#0A75B8")
    c.rect(0, 0, A4[0], A4[1], fill=True, stroke=False)

    c.setFillColor(colors.white)
    c.setFont("DejaVu", 38)
    c.drawCentredString(A4[0] / 2, A4[1] - 180, "IRIDOLOGY")

    c.setFont("DejaVu", 20)
    c.drawCentredString(A4[0] / 2, A4[1] - 230, "Medical Diagnostic Report")

    c.setFont("DejaVu", 12)
    c.drawCentredString(A4[0] / 2, 100, datetime.now().strftime("%d.%m.%Y"))

    c.showPage()


# Безопасная строка
def safe(v):
    return "" if v is None else str(v)


# --------------------------------------------------------------
# Генератор PDF v2
# --------------------------------------------------------------
def generate_pdf_v2(left: dict, right: dict, summary: str,
                    left_img_path=None, right_img_path=None) -> str:
    try:
        filename = f"report_{datetime.now().strftime('%Y%m%d_%H%M%S_%f')}.pdf"
        path = os.path.join(REPORT_DIR, filename)

        # Canvas
        c = canvas.Canvas(path, pagesize=A4)

        # ---------- РЕГИСТРАЦИЯ ШРИФТА ДЛЯ КИРИЛЛИЦЫ ----------
        if os.path.exists(FONT_PATH):
            pdfmetrics.registerFont(TTFont("DejaVu", FONT_PATH))
        else:
            log("[IRIDA] WARNING: Unicode font missing — fallback to Helvetica")

        c.setFont("DejaVu", 12)

        # Титульная страница
        draw_title_page(c)

        # ---------- Стили Paragraph (важно для кириллицы!) ----------
        styles = getSampleStyleSheet()
        normal = styles["Normal"]
        normal.fontName = "DejaVu"
        normal.leading = 14

        # ---------- Краткое резюме ----------
        c.setFont("DejaVu", 18)
        c.drawString(20 * mm, 270 * mm, "Краткое резюме")

        text = Paragraph(safe(summary), normal)
        text.wrapOn(c, 170 * mm, 48 * mm)
        text.drawOn(c, 20 * mm, 230 * mm)

        # ---------- Фото радужек ----------
        y_img = 160 * mm

        if left_img_path and os.path.exists(left_img_path):
            c.drawImage(left_img_path, 20 * mm, y_img, width=70 * mm, height=70 * mm)

        if right_img_path and os.path.exists(right_img_path):
            c.drawImage(right_img_path, 110 * mm, y_img, width=70 * mm, height=70 * mm)

        # ---------- Таблицы параметров ----------
        def make_table(title, data_dict, y_pos):
            c.setFont("DejaVu", 16)
            c.drawString(20 * mm, y_pos, title)

            rows = [["Параметр", "Значение"]]
            for k, v in data_dict.items():
                rows.append([safe(k), safe(v)])

            table = Table(rows, colWidths=[70 * mm, 90 * mm])
            table.setStyle(TableStyle([
                ("BACKGROUND", (0, 0), (-1, 0), colors.lightblue),
                ("TEXTCOLOR", (0, 0), (-1, 0), colors.white),
                ("ALIGN", (0, 0), (-1, -1), "LEFT"),
                ("FONTNAME", (0, 0), (-1, -1), "DejaVu"),
                ("FONTSIZE", (0, 0), (-1, -1), 10),
                ("GRID", (0, 0), (-1, -1), 0.25, colors.gray),
                ("BACKGROUND", (0, 1), (-1, -1), colors.whitesmoke),
            ]))

            table.wrapOn(c, 20 * mm, y_pos - 20 * mm)
            table.drawOn(c, 20 * mm, y_pos - 20 * mm)

        make_table("Левый глаз", left, 140 * mm)
        make_table("Правый глаз", right, 70 * mm)

        # ---------- Footer ----------
        c.setFont("DejaVu", 9)
        c.setFillColor(colors.gray)
        c.drawCentredString(A4[0] / 2, 10 * mm, "IRIDA Medical AI — Iris Diagnostics")

        c.save()

        log(f"[IRIDA] PDF v2 создан: {path}")
        return filename

    except Exception as e:
        log(f"[IRIDA] PDF v2 ERROR: {e}")
        return None

