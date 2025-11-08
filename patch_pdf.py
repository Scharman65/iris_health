from pathlib import Path
import re

p = Path("iris_ai_server.py")
s = p.read_text(encoding="utf-8")

# Импорты
if "from reportlab.pdfbase import pdfmetrics" not in s:
    s = s.replace(
        "from reportlab.lib.utils import ImageReader",
        "from reportlab.lib.utils import ImageReader\n"
        "from reportlab.pdfbase import pdfmetrics\n"
        "from reportlab.pdfbase.ttfonts import TTFont\n"
        "from reportlab.lib.colors import blue, black"
    )

if "from fastapi.staticfiles import StaticFiles" not in s:
    s = s.replace(
        "from fastapi import UploadFile, File, Form, HTTPException",
        "from fastapi import UploadFile, File, Form, HTTPException, Request\n"
        "from fastapi.staticfiles import StaticFiles"
    )

# Монтирование /files
if ".mount(\"/files\"" not in s and "app = FastAPI()" in s:
    s = s.replace(
        "app = FastAPI()",
        "app = FastAPI()\napp.mount(\"/files\", StaticFiles(directory=str(INBOX)), name=\"files\")"
    )

# Шрифты и выбор по locale
if "def _ensure_fonts(" not in s:
    s = s.replace(
        "INBOX = Path(\"ai_inbox\")",
        "INBOX = Path(\"ai_inbox\")\n"
        "FONTS = {\n"
        "  'ru': ('NotoSans', 'fonts/NotoSans-Regular.ttf'),\n"
        "  'default': ('DejaVuSans', 'fonts/DejaVuSans.ttf')\n"
        "}\n"
        "def _ensure_fonts():\n"
        "    for fam, path in [FONTS['ru'], FONTS['default']]:\n"
        "        try:\n"
        "            if fam not in pdfmetrics.getRegisteredFontNames():\n"
        "                pdfmetrics.registerFont(TTFont(fam, path))\n"
        "        except Exception:\n"
        "            pass\n"
        "def _pick_font(locale: str|None) -> str:\n"
        "    loc = (locale or '').lower()\n"
        "    if loc.startswith('ru') and 'NotoSans' in pdfmetrics.getRegisteredFontNames():\n"
        "        return 'NotoSans'\n"
        "    return 'DejaVuSans' if 'DejaVuSans' in pdfmetrics.getRegisteredFontNames() else 'Helvetica'\n"
    )

# Полная замена _save_report_pdf
def replace_pdf_func(src: str) -> str:
    pattern = re.compile(r"def _save_report_pdf\\([\\s\\S]*?\\)\\:[\\s\\S]*?\\n\\s*return[\\s\\S]*?\\n", re.M)
    new_body = (
        "def _save_report_pdf(exam_id: str, result: dict, root: Path):\n"
        "    _ensure_fonts()\n"
        "    from reportlab.pdfgen import canvas\n"
        "    from reportlab.lib.pagesizes import A4\n"
        "    from reportlab.lib.utils import ImageReader\n"
        "    W, H = A4\n"
        "    pdf_path = root / 'report.pdf'\n"
        "    c = canvas.Canvas(str(pdf_path), pagesize=A4)\n"
        "    font = _pick_font(result.get('locale'))\n"
        "    title = 'Iris Auto-Report'\n"
        "    try:\n"
        "        title = BRAND_NAME\n"
        "    except Exception:\n"
        "        pass\n"
        "    c.setFont(font, 16)\n"
        "    c.drawString(36, H-54, title)\n"
        "    try:\n"
        "        c.setFont(font, 11)\n"
        "        c.drawString(36, H-72, BRAND_SUBTITLE)\n"
        "    except Exception:\n"
        "        pass\n"
        "    c.setFont(font, 9)\n"
        "    leading = 14\n"
        "    y = H - 96\n"
        "    for line in (result.get('text_summary','')).split('\\n'):\n"
        "        c.drawString(36, y, line)\n"
        "        y -= leading\n"
        "        if y < 72:\n"
        "            c.showPage(); c.setFont(font, 9); y = H - 72\n"
        "    c.setFont(font, 10)\n"
        "    y -= 10\n"
        "    if y < 100:\n"
        "        c.showPage(); c.setFont(font, 10); y = H - 72\n"
        "    c.drawString(36, y, 'Ссылки на результаты:')\n"
        "    y -= 14\n"
        "    def link_line(label, url, y):\n"
        "        if not url:\n"
        "            return y\n"
        "        txt = f'• {label}: {url}'\n"
        "        c.setFillColor(blue); c.drawString(48, y, txt); c.setFillColor(black)\n"
        "        from reportlab.pdfbase import pdfmetrics as _pm\n"
        "        w = _pm.stringWidth(txt, font, 10)\n"
        "        c.linkURL(url, (48, y-2, 48+w, y+10), relative=0)\n"
        "        return y - 14\n"
        "    y = link_line('PDF', result.get('report_pdf_url'), y)\n"
        "    y = link_line('TXT', result.get('report_txt_url'), y)\n"
        "    c.showPage(); c.setFont(font, 14)\n"
        "    c.drawString(36, H-54, 'Фотографии и зоны значимости')\n"
        "    left_png  = root / 'left.jpg'\n"
        "    right_png = root / 'right.jpg'\n"
        "    def draw_img(p, x, y, w=240, h=240):\n"
        "        try:\n"
        "            c.drawImage(ImageReader(str(p)), x, y, width=w, height=h, preserveAspectRatio=True, mask='auto')\n"
        "        except Exception:\n"
        "            c.rect(x, y, w, h)\n"
        "    draw_img(left_png, 36,  H-320)\n"
        "    draw_img(right_png, 300, H-320)\n"
        "    c.save()\n"
        "    return str(pdf_path)\n"
    )
    if pattern.search(src):
        return pattern.sub(new_body, src, count=1)
    return src + "\n\n" + new_body + "\n"

s = replace_pdf_func(s)

# URL'ы в JSON
if "report_pdf_url" not in s:
    s = s.replace(
        "return JSONResponse(result)",
        "base = str(request.url).split('/analyze')[0]\n"
        "    result['report_pdf_path'] = f'ai_inbox/{exam_id}/report.pdf'\n"
        "    result['report_txt_path'] = f'ai_inbox/{exam_id}/report.txt'\n"
        "    result['report_pdf_url']  = f\"{base}/files/{exam_id}/report.pdf\"\n"
        "    result['report_txt_url']  = f\"{base}/files/{exam_id}/report.txt\"\n"
        "    return JSONResponse(result)",
        1
    )

p.write_text(s, encoding="utf-8")
print("[OK] Патч применён: шрифты/leading/стр.2/ссылки")
