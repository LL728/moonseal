from pathlib import Path

from docx import Document
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.shared import Inches, Pt, RGBColor
from reportlab.lib import colors
from reportlab.lib.pagesizes import letter
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import mm
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.platypus import Paragraph, SimpleDocTemplate, Spacer, Table, TableStyle


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "docs" / "competition" / "proposal.md"
DOCX_OUT = ROOT / "docs" / "competition" / "MoonSeal项目申报书.docx"
PDF_OUT = ROOT / "docs" / "competition" / "MoonSeal项目申报书.pdf"


def parse_markdown():
    sections = []
    current = None
    for raw in SOURCE.read_text(encoding="utf-8").splitlines():
        line = raw.rstrip()
        if line.startswith("# "):
            current = {"level": 1, "title": line[2:], "body": []}
            sections.append(current)
        elif line.startswith("## "):
            current = {"level": 2, "title": line[3:], "body": []}
            sections.append(current)
        elif current is not None:
            current["body"].append(line)
    return sections


def configure_doc(doc):
    section = doc.sections[0]
    section.top_margin = Inches(1)
    section.bottom_margin = Inches(1)
    section.left_margin = Inches(1)
    section.right_margin = Inches(1)

    normal = doc.styles["Normal"]
    normal.font.name = "Microsoft YaHei"
    normal.font.size = Pt(11)
    normal.paragraph_format.space_after = Pt(8)
    normal.paragraph_format.line_spacing = 1.25

    h1 = doc.styles["Heading 1"]
    h1.font.name = "Microsoft YaHei"
    h1.font.size = Pt(16)
    h1.font.color.rgb = RGBColor(46, 116, 181)
    h1.paragraph_format.space_before = Pt(16)
    h1.paragraph_format.space_after = Pt(8)


def build_docx(sections):
    doc = Document()
    configure_doc(doc)

    title = doc.add_paragraph()
    title.alignment = WD_ALIGN_PARAGRAPH.CENTER
    run = title.add_run("MoonSeal 项目申报书")
    run.bold = True
    run.font.name = "Microsoft YaHei"
    run.font.size = Pt(20)
    run.font.color.rgb = RGBColor(31, 77, 121)

    subtitle = doc.add_paragraph()
    subtitle.alignment = WD_ALIGN_PARAGRAPH.CENTER
    subtitle.add_run("MoonBit 测试充分性与发布质量门禁工具").font.size = Pt(11)

    meta = doc.add_table(rows=4, cols=2)
    meta.style = "Table Grid"
    rows = [
        ("项目名称", "MoonSeal"),
        ("项目方向", "软件分析框架 / 工程质量工具"),
        ("开源协议", "Apache-2.0"),
        ("仓库地址", "https://gitlink.org.cn/LL1266/moonseal"),
    ]
    for row, (key, value) in zip(meta.rows, rows):
        row.cells[0].text = key
        row.cells[1].text = value

    for item in sections:
        if item["level"] == 1:
            continue
        doc.add_heading(item["title"], level=1)
        in_code = False
        code_lines = []
        for line in item["body"]:
            if line.startswith("```"):
                if in_code:
                    p = doc.add_paragraph("\n".join(code_lines))
                    for run in p.runs:
                        run.font.name = "Consolas"
                        run.font.size = Pt(9)
                    code_lines = []
                in_code = not in_code
            elif in_code:
                code_lines.append(line)
            elif line.startswith("- "):
                doc.add_paragraph(line[2:], style="List Bullet")
            elif line.startswith(("1. ", "2. ", "3. ", "4. ", "5. ", "6. ")):
                doc.add_paragraph(line[3:], style="List Number")
            elif line.strip():
                doc.add_paragraph(line)

    doc.save(DOCX_OUT)


def register_font():
    for font_path in [
        Path("C:/Windows/Fonts/msyh.ttc"),
        Path("C:/Windows/Fonts/simsun.ttc"),
        Path("C:/Windows/Fonts/simhei.ttf"),
    ]:
        if font_path.exists():
            pdfmetrics.registerFont(TTFont("CNFont", str(font_path)))
            return "CNFont"
    return "Helvetica"


def build_pdf(sections):
    font = register_font()
    styles = getSampleStyleSheet()
    title_style = ParagraphStyle(
        "TitleStyle",
        parent=styles["Title"],
        fontName=font,
        fontSize=20,
        leading=26,
        alignment=1,
        textColor=colors.HexColor("#1f4d79"),
        spaceAfter=8,
    )
    body_style = ParagraphStyle(
        "BodyStyle",
        parent=styles["BodyText"],
        fontName=font,
        fontSize=10.5,
        leading=14,
        spaceAfter=6,
    )
    heading_style = ParagraphStyle(
        "HeadingStyle",
        parent=styles["Heading1"],
        fontName=font,
        fontSize=13,
        leading=18,
        textColor=colors.HexColor("#2e74b5"),
        spaceBefore=10,
        spaceAfter=6,
    )
    code_style = ParagraphStyle(
        "CodeStyle",
        parent=body_style,
        fontName="Courier",
        fontSize=8,
        leading=11,
        leftIndent=8,
    )

    story = [
        Paragraph("MoonSeal 项目申报书", title_style),
        Paragraph("MoonBit 测试充分性与发布质量门禁工具", body_style),
        Spacer(1, 6),
    ]
    table = Table(
        [
            ["项目名称", "MoonSeal"],
            ["项目方向", "软件分析框架 / 工程质量工具"],
            ["开源协议", "Apache-2.0"],
            ["仓库地址", "https://gitlink.org.cn/LL1266/moonseal"],
        ],
        colWidths=[35 * mm, 120 * mm],
    )
    table.setStyle(
        TableStyle(
            [
                ("FONTNAME", (0, 0), (-1, -1), font),
                ("FONTSIZE", (0, 0), (-1, -1), 9),
                ("BACKGROUND", (0, 0), (0, -1), colors.HexColor("#eaf1f7")),
                ("GRID", (0, 0), (-1, -1), 0.3, colors.HexColor("#9aaec3")),
                ("LEFTPADDING", (0, 0), (-1, -1), 6),
                ("RIGHTPADDING", (0, 0), (-1, -1), 6),
                ("TOPPADDING", (0, 0), (-1, -1), 5),
                ("BOTTOMPADDING", (0, 0), (-1, -1), 5),
            ]
        )
    )
    story.extend([table, Spacer(1, 8)])

    for item in sections:
        if item["level"] == 1:
            continue
        story.append(Paragraph(item["title"], heading_style))
        in_code = False
        code_lines = []
        for line in item["body"]:
            if line.startswith("```"):
                if in_code:
                    story.append(Paragraph("<br/>".join(code_lines), code_style))
                    code_lines = []
                in_code = not in_code
            elif in_code:
                code_lines.append(line.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;"))
            elif line.startswith("- "):
                story.append(Paragraph("• " + line[2:], body_style))
            elif line.startswith(("1. ", "2. ", "3. ", "4. ", "5. ", "6. ")):
                story.append(Paragraph(line, body_style))
            elif line.strip():
                story.append(Paragraph(line, body_style))

    doc = SimpleDocTemplate(
        str(PDF_OUT),
        pagesize=letter,
        rightMargin=25.4 * mm,
        leftMargin=25.4 * mm,
        topMargin=25.4 * mm,
        bottomMargin=25.4 * mm,
    )
    doc.build(story)


def main():
    sections = parse_markdown()
    build_docx(sections)
    build_pdf(sections)
    print(DOCX_OUT)
    print(PDF_OUT)


if __name__ == "__main__":
    main()
