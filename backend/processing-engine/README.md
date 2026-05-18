# Backend Processing Engine

The **intelligent processing layer** of the Smart Fridge. It runs as a
continuous loop and does all the computer vision — the ESP32-CAM only serves
images, the ESP32 DevKit only reads sensors.

Each cycle the engine:

1. Pulls a snapshot frame from the ESP32-CAM (`<CAMERA_BASE_URL>/capture`).
2. **Decodes QR codes** with OpenCV + pyzbar and registers products.
3. **Analyzes banana browning** with real pixel-based HSV thresholding
   (no machine learning, no fake AI).
4. Writes the results to Firebase Realtime Database.

## Firebase output

```
devices/<id>/products/<slug>   { productName, expiryDate, detectedAt, source }
devices/<id>/bananaAnalysis    { brownPercent, status, analyzedAt }
```

QR payload format (our own printed QR codes):

```json
{ "product": "Milk", "expiry": "2026-05-25" }
```

## Banana analysis

The frame is converted to HSV. Healthy **yellow** banana flesh, **brown**
overripe regions and **dark** spots are isolated with colour thresholds:

```
brownPercent = (brown + dark pixels) / banana region pixels * 100
```

| brownPercent | status |
|--------------|--------|
| `0 - 15 %`   | Fresh  |
| `15 - 35 %`  | Warning|
| `35 %+`      | Rotten |

## Setup

```bash
cd backend/processing-engine
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

The machine running the engine must be on the **same Wi-Fi** as the ESP32-CAM.

## Run

```bash
python app.py            # continuous processing loop (Ctrl+C to stop)
python app.py --once     # a single processing cycle (handy for testing)
```

## Notes

- No secrets are stored in code — everything comes from `.env` (git-ignored).
- The engine keeps running if a cycle fails (camera offline, etc.).
