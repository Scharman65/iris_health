import os
from datetime import datetime
from fpdf import FPDF
from iris_ai_server.utils.logger import log

REPORT_DIR = "iris_ai_server/storage/reports"
os.makedirs(REPORT_DIR, exist_ok=True)

FONT_PATH = os.path.join(
    os.path.dirname(os.path.abspath(__file__)),
    "fonts",
    "DejaVuSans.ttf"
)


def safe(v):
    if v is None:
        return ""
    v = str(v)
    return v.replace("\r", "").replace("\n", "\n")


class PDF(FPDF):
    def __init__(self):
        super().__init__(orientation="P", unit="mm", format="A4")

        self.unicode_ok = False
        if os.path.exists(FONT_PATH):
            try:
                self.add_font("DejaVu", "", FONT_PATH, uni=True)
                self.set_font("DejaVu", size=12)
                self.unicode_ok = True
            except Exception as e:
                log(f"[IRIDA] Ошибка загрузки Unicode-шрифта: {e}")
                self.set_font("Helvetica", size=12)
        else:
            log("[IRIDA] Unicode-шрифт не найден → fallback Helvetica")
            self.set_font("Helvetica", size=12)

    def header(self):
        if self.unicode_ok:
            self.set_font("DejaVu", size=12)
        else:
            self.set_font("Helvetica", size=12)

        self.cell(0, 8, "IRIDA — Анализ радужки (AI)", align="C", ln=True)
        self.ln(2)


def generate_pdf(left: dict, right: dict, summary: str) -> str:
    try:
        pdf = PDF()
        pdf.add_page()

        margin = 10
        width = pdf.w - 2 * margin

        pdf.set_font_size(13)
        pdf.multi_cell(width, 7, safe("Краткое резюме:"))
        pdf.set_font_size(11)
        pdf.multi_cell(width, 6, safe(summary))
        pdf.ln(4)

        pdf.set_font_size(13)
        pdf.multi_cell(width, 7, safe("Левый глаз:"))
        pdf.set_font_size(11)
        for k, v in left.items():
            pdf.multi_cell(width, 6, f"{k}: {safe(v)}")
        pdf.ln(4)

        pdf.set_font_size(13)
        pdf.multi_cell(width, 7, safe("Правый глаз:"))
        pdf.set_font_size(11)
        for k, v in right.items():
            pdf.multi_cell(width, 6, f"{k}: {safe(v)}")

        filename = f"report_{datetime.now().strftime('%Y%m%d_%H%M%S_%f')}.pdf"
        path = os.path.join(REPORT_DIR, filename)
        pdf.output(path)

        log(f"[IRIDA] PDF создан устойчиво: {path}")
        return filename

    except Exception as e:
        log(f"[IRIDA] Фатальная ошибка PDF: {e}")
        return None

