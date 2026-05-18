# QR-Based Product Identification

Products are identified by **our own predefined QR stickers**, not by weight
and not by manual entry. A product appears in the app only because the camera
saw its QR code.

Generation guide and sample payloads: [`qr-samples/`](../qr-samples).

---

## 1. Why QR codes

The load cells (HX711) are used for **quantity / weight verification and
spoilage-risk contribution only** — they are *not* the product identification
method. Weight cannot tell milk from yogurt. A printed QR sticker carries the
exact identity and expiry date of each product, which is reliable and cheap.

---

## 2. QR payload

Each sticker encodes one minified JSON object:

```json
{
  "productId": "banana_001",
  "name": "Banana",
  "expiryDate": "2026-05-25",
  "category": "Fruit"
}
```

| Field | Notes |
|-------|-------|
| `productId` | Stable unique id; becomes the Firebase node key |
| `name` | Display name |
| `expiryDate` | `YYYY-MM-DD` |
| `category` | Fruit / Vegetable / Dairy / Packaged / … |

Typical products: banana, milk, yogurt, apple, cucumber, tomato, egg box,
cheese, packaged food.

---

## 3. Pipeline

```
ESP32-CAM ──/capture──> Image analysis service ──> Firebase ──> Flutter app
            (JPEG frame)   decode QR (OpenCV+pyzbar)   products      live list
```

1. The ESP32-CAM continuously monitors the box and serves frames.
2. The image analysis service pulls a snapshot each cycle.
3. It decodes any QR code in the frame with **OpenCV + pyzbar**.
4. The payload is validated (`productId` and `name` must be non-empty).
5. The product is written to `devices/fridge_01/products/<productId>`:

   ```json
   { "productId": "banana_001", "productName": "Banana", "category": "Fruit",
     "expiryDate": "2026-05-25", "detectedAt": 1710000000, "source": "qr" }
   ```

6. The Flutter app updates automatically and shows the product with an
   expiry status: **Fresh**, **Expiring Soon** or **Expired**.

There is **no manual product entry** anywhere in the app, and the ESP32-CAM
itself never decodes QR codes — it only provides the image.

---

## 4. Re-detection and updates

Writing uses the `productId` as the key, so re-scanning the same sticker
**updates** the existing node (and refreshes `detectedAt`) instead of creating
a duplicate. Updating an expiry date is just a matter of re-printing the
sticker with a new `expiryDate`.

---

## 5. Honest limitations

- A QR code must be **facing the camera** and reasonably lit to decode.
- Removing a product does not auto-delete its node — expiry status still makes
  stale items obvious, and a node can be cleared from the database directly.
- The system trusts the sticker: the `expiryDate` is only as correct as what
  was printed on it.
