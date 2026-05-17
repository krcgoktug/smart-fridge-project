# QR Code Generation Guide

Every product in the Smart Fridge carries a QR sticker. The QR code stores a
small JSON object that fully identifies the product. The mobile app scans it,
parses the JSON, and saves the product to Firebase.

---

## 1. What goes in a QR code

Encode **one product object** — exactly the shape used in
[sample-products.json](sample-products.json):

```json
{
  "productId": "milk_001",
  "name": "Milk",
  "category": "Dairy",
  "brand": "Example Brand",
  "expiryDate": "2026-05-25",
  "addedDate": "2026-05-17",
  "expectedWeight": 1000,
  "weightMin": 900,
  "weightMax": 1100,
  "storageType": "Cold"
}
```

> Encode the object only — **not** the whole file and **not** the `products`
> array wrapper.

### Field reference

| Field | Type | Notes |
|-------|------|-------|
| `productId` | string | Unique id, used as the Firebase key |
| `name` | string | Display name |
| `category` | string | `Fruit`, `Vegetable`, `Dairy`, `Egg`, `Packaged Food` |
| `brand` | string | Free text |
| `expiryDate` | string | `YYYY-MM-DD` |
| `addedDate` | string | `YYYY-MM-DD` |
| `expectedWeight` | number | grams |
| `weightMin` | number | grams, lower acceptable bound |
| `weightMax` | number | grams, upper acceptable bound |
| `storageType` | string | `Cold`, `Cool`, `Ambient` |

The `category` value decides which risk components apply — keep it to one of
the five values above so the app classifies it correctly.

---

## 2. How to generate the QR codes

### Option A — Online generator (quickest)

1. Open a QR generator that supports raw text (e.g. a "Text" QR mode).
2. Paste **one minified product JSON object**.
3. Download the PNG and print it as a sticker.

> Minify the JSON (no extra spaces/newlines) so the QR stays low-density and
> scans reliably. Example minified string:
>
> `{"productId":"milk_001","name":"Milk","category":"Dairy","brand":"Example Brand","expiryDate":"2026-05-25","addedDate":"2026-05-17","expectedWeight":1000,"weightMin":900,"weightMax":1100,"storageType":"Cold"}`

### Option B — Python (batch, recommended for many products)

```bash
pip install qrcode[pil]
```

```python
import json, qrcode

with open("sample-products.json", encoding="utf-8") as f:
    products = json.load(f)["products"]

for p in products:
    payload = json.dumps(p, separators=(",", ":"))   # minified
    img = qrcode.make(payload)
    img.save(f"qr_{p['productId']}.png")
    print("wrote", f"qr_{p['productId']}.png")
```

This writes one PNG per product, ready to print.

---

## 3. Printing tips

- Print at **least 3 x 3 cm**; bigger is easier to scan.
- Use a matte sticker so the box light does not cause glare.
- Stick the QR on a flat part of the package, facing outward.
- Keep one master sheet of all QR codes for the demo as a backup.

---

## 4. Scan behavior in the app

When the **Add Product / QR Scan** screen reads a QR code, the app:

1. Decodes the text and parses it as JSON.
2. Validates the required fields and the `category` value.
3. Shows a confirmation card with the parsed data.
4. On confirm, writes it to `/devices/fridge_01/products/<productId>` and
   computes `remainingHours` from `expiryDate`.

If the JSON is malformed or a field is missing, the app shows an error and
does **not** save the product.
