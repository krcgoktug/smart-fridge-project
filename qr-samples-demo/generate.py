"""Generate demo QR codes for the Smart Fridge app, plus a printable A4
sheet with all of them laid out side by side.

Today: 2026-06-02. Each QR encodes the JSON payload the Flutter app
expects in lib/screens/camera_view_screen.dart::_parseProduct().
"""
import json
import os
from datetime import date, timedelta

import qrcode
from PIL import Image, ImageDraw, ImageFont

OUT = os.path.dirname(os.path.abspath(__file__))
TODAY = date(2026, 6, 2)

# Collected during make() so the A4 layout has the data it needs.
ITEMS: list[dict] = []


def make(product_id: str, name: str, category: str, days_to_expiry: int) -> None:
    expiry = TODAY + timedelta(days=days_to_expiry)
    payload = {
        "productId": product_id,
        "name": name,
        "category": category,
        "expiryDate": expiry.isoformat(),
        "addedDate": TODAY.isoformat(),
    }
    text = json.dumps(payload, ensure_ascii=False)

    qr = qrcode.QRCode(
        version=None,
        error_correction=qrcode.constants.ERROR_CORRECT_M,
        box_size=10,
        border=4,
    )
    qr.add_data(text)
    qr.make(fit=True)
    img = qr.make_image(fill_color="black", back_color="white")
    out = os.path.join(OUT, f"qr_{product_id}.png")
    img.save(out)

    label = (
        "EXPIRED" if days_to_expiry < 0
        else ("Expiring Soon" if days_to_expiry <= 3 else "Fresh")
    )
    print(f"  qr_{product_id}.png  exp={expiry}  ({days_to_expiry:+d}d -> {label})")

    ITEMS.append({
        "id": product_id,
        "name": name,
        "category": category,
        "expiry": expiry.isoformat(),
        "days": days_to_expiry,
        "label": label,
        "qr_img": img.convert("RGB"),
    })


def _load_font(size: int) -> ImageFont.FreeTypeFont:
    """Try a few common Windows fonts so labels render cleanly."""
    for candidate in (
        "C:/Windows/Fonts/arialbd.ttf",
        "C:/Windows/Fonts/arial.ttf",
        "C:/Windows/Fonts/segoeui.ttf",
    ):
        if os.path.exists(candidate):
            try:
                return ImageFont.truetype(candidate, size)
            except Exception:
                pass
    return ImageFont.load_default()


def build_a4_sheet() -> None:
    """Compose a single A4 portrait page with just the QR codes — no
    labels, no borders, plenty of white quiet zone around each one so
    the ESP32-CAM has the easiest possible time decoding them.

    A4 at 300 DPI = 2480 x 3508 px.
    5.5 cm at 300 DPI = 5.5 * 300 / 2.54 = 650 px.
    """
    W, H = 2480, 3508
    sheet = Image.new("RGB", (W, H), "white")

    qr_size = 650          # 5.5 cm at 300 DPI
    cols = 2
    rows = 3               # 5 QRs + 1 blank cell (last)

    # Even cell grid with generous white margin around every QR.
    cell_w = W // cols
    cell_h = H // rows

    for idx, item in enumerate(ITEMS):
        col = idx % cols
        row = idx // cols
        cx = col * cell_w
        cy = row * cell_h
        # Center the QR inside its cell so there's a large white border
        # on every side — much wider than the QR spec's minimum quiet
        # zone, giving the camera-based decoder all the help it needs.
        qr_img = item["qr_img"].resize((qr_size, qr_size), Image.NEAREST)
        qr_x = cx + (cell_w - qr_size) // 2
        qr_y = cy + (cell_h - qr_size) // 2
        sheet.paste(qr_img, (qr_x, qr_y))

    png_path = os.path.join(OUT, "a4_qrs_5p5cm.png")
    pdf_path = os.path.join(OUT, "a4_qrs_5p5cm.pdf")
    sheet.save(png_path, dpi=(300, 300))
    sheet.save(pdf_path, "PDF", resolution=300.0)
    print()
    print(f"A4 sheet written (clean, no labels):")
    print(f"  {png_path}")
    print(f"  {pdf_path}")


print(f"Today: {TODAY}")
print(f"Output dir: {OUT}")
print()
print("Generated QR files:")
make("salam_001",  "Salam",          "Meat",      -3)   # expired
make("milk_001",   "Sut",            "Dairy",     12)   # fresh
make("yogurt_tava_001", "Tava Yogurdu", "Dairy",   8)   # fresh
make("lettuce_001", "Marul",         "Vegetable",  2)   # expiring soon
make("banana_001", "Muz",            "Fruit",      7)   # fresh
build_a4_sheet()
print()
print("Done.")
