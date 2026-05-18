# QR Code Generation Guide

Every product carries our **own printed QR sticker**. The QR stores a small
JSON payload. The **image analysis service** reads it from the camera frame,
decodes it (OpenCV + pyzbar) and registers the product in Firebase.

There is **no manual product entry** — a product appears in the app only
because its QR sticker was seen by the camera.

---

## 1. QR payload format

Encode **one product object** per QR code:

```json
{
  "productId": "banana_001",
  "name": "Banana",
  "expiryDate": "2026-05-25",
  "category": "Fruit"
}
```

| Field | Type | Notes |
|-------|------|-------|
| `productId` | string | Stable unique id; also the Firebase node key |
| `name` | string | Product name shown in the app |
| `expiryDate` | string | Expiry date, `YYYY-MM-DD` |
| `category` | string | e.g. Fruit, Vegetable, Dairy, Packaged |

Sample payloads: [sample-products.json](sample-products.json).

The service stores the product under `devices/fridge_01/products/<productId>`:

```json
{ "productId": "banana_001", "productName": "Banana", "category": "Fruit",
  "expiryDate": "2026-05-25", "detectedAt": 1710000000, "source": "qr" }
```

---

## 2. Generating the QR codes

### Option A — Online generator

1. Open any QR generator that accepts raw **text**.
2. Paste one minified product JSON object, e.g.
   `{"productId":"banana_001","name":"Banana","expiryDate":"2026-05-25","category":"Fruit"}`
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
    if p.get("_comment"):
        continue
    payload = json.dumps(p, separators=(",", ":"))   # minified
    qrcode.make(payload).save(f"qr_{p['productId']}.png")
    print("wrote", p["productId"])
```

---

## 3. Printing tips

- Print at least **3 × 3 cm**; bigger scans more reliably.
- Use a matte sticker to avoid glare under the box light.
- Face the QR code toward the ESP32-CAM.
- Keep a master sheet of all QR codes as a demo backup.

---

## 4. How it is processed

1. The ESP32-CAM streams frames; the service pulls a snapshot each cycle.
2. The service decodes any QR code in the frame with **OpenCV + pyzbar**.
3. The JSON payload is parsed and validated (`productId` and `name` must be
   non-empty).
4. The product is written to Firebase; the Flutter app shows it with an
   expiry status (Fresh / Expiring Soon / Expired).

The ESP32-CAM itself never decodes QR codes — it only provides the image.
Full pipeline: [docs/qr-system.md](../docs/qr-system.md).
