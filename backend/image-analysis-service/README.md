# Image Analysis Service

The **processing layer** of the Smart Fridge. It runs as a continuous loop
and does all the computer vision — the ESP32-CAM only serves images and the
ESP32 DevKit only reads sensors.

Each cycle the service:

1. Pulls a snapshot frame from the ESP32-CAM (`<CAMERA_BASE_URL>/capture`).
2. **Decodes QR codes** with OpenCV + pyzbar and registers products.
3. **Analyzes banana browning** with pixel-based HSV thresholding
   (no machine learning, no fake AI).
4. Writes the **camera online status**.
5. Recomputes the **alert list** from sensors, products and banana data.

## Firebase output

```
devices/<id>/camera            { online, ip, lastFrameAt, frameWidth, frameHeight }
devices/<id>/products/<id>     { productId, productName, category, expiryDate, detectedAt, source }
devices/<id>/bananaAnalysis    { brownPercent, visualStatus, status, analyzedAt }
devices/<id>/alerts            { <alertId>: { type, message, severity, createdAt } }
```

QR payload format (our own printed QR stickers):

```json
{ "productId": "banana_001", "name": "Banana",
  "expiryDate": "2026-05-25", "category": "Fruit" }
```

See [docs/qr-system.md](../../docs/qr-system.md) and
[docs/banana-analysis.md](../../docs/banana-analysis.md) for the full method.

## Banana analysis

The frame is converted to HSV. Healthy **yellow** banana flesh, **brown**
overripe regions and **dark** spots are isolated with colour thresholds:

```
brownPercent = (brown + dark pixels) / banana region pixels * 100
```

| brownPercent | visualStatus | status |
|--------------|-------------------|----------------|
| `0 – 15 %`   | Fresh             | Good           |
| `15 – 35 %`  | Slight Browning   | Monitor        |
| `35 – 60 %`  | Browning Detected | Consume Soon   |
| `60 %+`      | Spoilage Risk     | Do Not Consume |

## Setup

```bash
cd backend/image-analysis-service
python -m venv .venv
.venv/Scripts/activate            # Windows  (Linux/macOS: source .venv/bin/activate)
pip install -r requirements.txt
cp .env.example .env              # then edit .env
```

> **pyzbar** needs the native `zbar` library. On Windows the wheel bundles it.
> On Debian/Ubuntu: `sudo apt-get install libzbar0`. On macOS: `brew install zbar`.

Edit `.env`:

- `CAMERA_BASE_URL` — the ESP32-CAM IP (e.g. `http://192.168.1.50`).
- `FIREBASE_HOST` / `FIREBASE_AUTH` — your Realtime Database URL + token.

The machine running the service must be on the **same Wi-Fi** as the ESP32-CAM.

## Run

```bash
python app.py            # continuous processing loop (Ctrl+C to stop)
python app.py --once     # a single processing cycle (handy for testing)
```

## Notes

- No secrets are stored in code — everything comes from `.env` (git-ignored).
- The loop keeps running if a cycle fails (camera offline, etc.); the camera
  node is still marked offline so the app reflects it.
- Alerts are recomputed and fully replaced each cycle, so a cleared condition
  removes its alert automatically.
