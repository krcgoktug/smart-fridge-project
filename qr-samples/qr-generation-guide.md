# QR Code Generation Guide

Every product carries our own printed QR sticker. The QR stores a small JSON
payload. The **Python backend** reads it from the camera frame, decodes it
(OpenCV + pyzbar) and registers the product in Firebase.

---

## 1. QR payload format

Encode **one product object** per QR code:

```json
{ "product": "Milk", "expiry": "2026-05-25" }
```

| Field | Type | Notes |
|-------|------|-------|
| `product` | string | Product name shown in the app |
| `expiry` | string | Expiry date, `YYYY-MM-DD` |

Sample payloads: [sample-products.json](sample-products.json).

The backend stores the product under `devices/fridge_01/products/<slug>` as:

```json
{ "productName": "Milk", "expiryDate": "2026-05-25",
  "detectedAt": 1710000000, "source": "qr" }
```

---

## 2. Generating the QR codes

### Option A — Online generator

1. Open any QR generator that accepts raw **text**.
2. Paste one minified product JSON object, e.g.
   `{"product":"Milk","expiry":"2026-05-25"}`
3. Download the PNG and print it as a sticker.

### Option B — Python (batch)

```bash
pip install "qrcode[pil]"
```

```python
import json, qrcode

with open("sample-products.json", encoding="utf-8") as f:
    products = json.load(f)["products"]

for p in products:
    payload = json.dumps(p, separators=(",", ":"))   # minified
    qrcode.make(payload).save(f"qr_{p['product'].lower().replace(' ', '_')}.png")
    print("wrote", p["product"])
```

---

## 3. Printing tips

- Print at least **3 x 3 cm**; bigger scans more reliably.
- Use a matte sticker to avoid glare under the box light.
- Face the QR code toward the ESP32-CAM.
- Keep a master sheet of all QR codes as a demo backup.

---

## 4. How it is processed

1. The ESP32-CAM streams frames; the backend pulls a snapshot each cycle.
2. The backend decodes any QR code in the frame with **OpenCV + pyzbar**.
3. The JSON payload is parsed and validated (`product` must be non-empty).
4. The product is written to Firebase; the Flutter app shows it with an
   expiry status (Fresh / Expiring Soon / Expired).

The ESP32-CAM itself never decodes QR codes — it only provides the image.
