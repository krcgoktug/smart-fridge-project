"""Lay the 5 demo QR PNGs on a single A4 sheet for printing/photocopying.

Output: qr_a4.png (preview) + qr_a4.pdf (printable).
A4 at 300 DPI = 2480 x 3508 px (portrait).
"""
import os
from PIL import Image, ImageDraw, ImageFont

OUT = os.path.dirname(os.path.abspath(__file__))

# ---- A4 canvas (300 DPI) ----
A4_W, A4_H = 2480, 3508
DPI = 300

# ---- Items: filename, display name, expiry-date string ----
ITEMS = [
    ("qr_salam_001.png",        "Salam",         "SKT: 2026-05-30  (EXPIRED)"),
    ("qr_milk_001.png",         "Sut",           "SKT: 2026-06-14  (Fresh)"),
    ("qr_yogurt_tava_001.png",  "Tava Yogurdu",  "SKT: 2026-06-10  (Fresh)"),
    ("qr_lettuce_001.png",      "Marul",         "SKT: 2026-06-04  (Expiring Soon)"),
    ("qr_banana_001.png",       "Muz",           "SKT: 2026-06-09  (Fresh)"),
]

# ---- Grid: 2 cols x 3 rows; last cell empty ----
COLS, ROWS = 2, 3
MARGIN = 120
CELL_W = (A4_W - 2 * MARGIN) // COLS
CELL_H = (A4_H - 2 * MARGIN) // ROWS
QR_SIZE = min(CELL_W, CELL_H) - 200   # leave room for label

# ---- Font (DejaVuSans bundled with Pillow is fine, falls back to default) ----
def load_font(size: int):
    for candidate in (
        "C:/Windows/Fonts/segoeuib.ttf",   # Segoe UI Bold
        "C:/Windows/Fonts/arialbd.ttf",    # Arial Bold
        "C:/Windows/Fonts/arial.ttf",
    ):
        try:
            return ImageFont.truetype(candidate, size)
        except OSError:
            continue
    return ImageFont.load_default()

FONT_TITLE = load_font(56)
FONT_SUB   = load_font(40)
FONT_PAGE  = load_font(64)

# ---- Compose ----
sheet = Image.new("RGB", (A4_W, A4_H), "white")
draw = ImageDraw.Draw(sheet)

# Page header
header = "Smart Fridge - Demo QR Stickers (A4)"
bbox = draw.textbbox((0, 0), header, font=FONT_PAGE)
draw.text(((A4_W - (bbox[2] - bbox[0])) // 2, 40), header, fill="black", font=FONT_PAGE)

for i, (filename, name, expiry) in enumerate(ITEMS):
    row, col = divmod(i, COLS)
    cell_x = MARGIN + col * CELL_W
    cell_y = MARGIN + row * CELL_H + 80   # nudge down past header

    # Load and resize QR
    qr_path = os.path.join(OUT, filename)
    qr = Image.open(qr_path).convert("RGB")
    qr = qr.resize((QR_SIZE, QR_SIZE), Image.NEAREST)
    qr_x = cell_x + (CELL_W - QR_SIZE) // 2
    qr_y = cell_y
    sheet.paste(qr, (qr_x, qr_y))

    # Labels under QR
    tw = draw.textlength(name, font=FONT_TITLE)
    draw.text((cell_x + (CELL_W - tw) // 2, qr_y + QR_SIZE + 20),
              name, fill="black", font=FONT_TITLE)

    sw = draw.textlength(expiry, font=FONT_SUB)
    draw.text((cell_x + (CELL_W - sw) // 2, qr_y + QR_SIZE + 95),
              expiry, fill="#444444", font=FONT_SUB)

    # Light border around each cell so cutting/folding is easier
    draw.rectangle(
        [cell_x + 20, cell_y - 30,
         cell_x + CELL_W - 20, cell_y + QR_SIZE + 170],
        outline="#cccccc", width=2,
    )

# ---- Save ----
png_path = os.path.join(OUT, "qr_a4.png")
pdf_path = os.path.join(OUT, "qr_a4.pdf")
sheet.save(png_path, dpi=(DPI, DPI))
sheet.save(pdf_path, "PDF", resolution=DPI)

print(f"Saved: {png_path}")
print(f"Saved: {pdf_path}")
