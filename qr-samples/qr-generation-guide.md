# Generating product QR stickers

Each product is encoded as a JSON QR payload:

```json
{ "productId": "milk_001",
  "name":      "Milk",
  "category":  "Dairy",
  "addedDate": "2026-06-02",
  "expiryDate":"2026-06-14" }
```

Use any QR generator (e.g. `qrcode` Python package) to render the JSON
string as a QR. Print at 5–6 cm with a generous quiet zone so the
ESP32-CAM can decode it reliably.
