# QR Code Generation Guide

Every product in the box has our own printed QR sticker. The app reads the QR
code from the ESP32-CAM image and registers the product in Firebase.

## QR payload

Encode **one product object** per QR code:

```json
{
  "productId": "milk_001",
  "name": "Milk",
  "category": "Dairy",
  "expiryDate": "2026-05-25",
  "addedDate": "2026-05-18"
}
```

| Field | Notes |
|-------|-------|
| `productId` | Unique id — also the Firebase key |
| `name` | Display name |
| `category` | Fruit / Vegetable / Dairy / Packaged / ... |
| `expiryDate` | `YYYY-MM-DD` |
| `addedDate` | `YYYY-MM-DD` |

Ready-made payloads: [sample-products.json](sample-products.json).

## How to generate the stickers

### Option A — online generator

1. Open any QR generator that accepts raw **text**.
2. Paste one minified product JSON object, e.g.
   `{"productId":"milk_001","name":"Milk","category":"Dairy","expiryDate":"2026-05-25","addedDate":"2026-05-18"}`
3. Download the PNG and print it.

### Option B — Python (batch)

```bash
pip install "qrcode[pil]"
```

```python
import json, qrcode

with open("sample-products.json", encoding="utf-8") as f:
    products = json.load(f)["products"]

for p in products:
    payload = json.dumps(p, separators=(",", ":"))
    qrcode.make(payload).save(f"qr_{p['productId']}.png")
    print("wrote", p["productId"])
```

## Printing tips

- Print at least **3 × 3 cm**; bigger scans more reliably.
- Use a matte sticker to avoid glare from the box light.
- Stick it on a flat surface facing the ESP32-CAM.

## How it is read

1. On the app's **Camera** screen, tap **Scan QR**.
2. The app fetches a frame from `http://<camera-ip>/capture`.
3. It decodes the QR code on-device and writes the product to Firebase.
4. The product appears on the **Products** screen with its expiry status.
