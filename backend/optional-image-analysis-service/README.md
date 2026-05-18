# Optional Image Analysis Service

A small Python service that mirrors the app's two camera-driven features with
lightweight image processing — **no machine learning**.

It is **optional**: the Flutter app does all of this on the phone. This
service exists so the work can run on a laptop and write results back to
Firebase, which is convenient for the demo. There is no load-cell dependency.

## What it does

**Banana browning analysis** — pixel-based, RGB thresholds:

1. Fetch the latest JPEG from the ESP32-CAM `/capture` URL.
2. Classify each pixel as banana flesh, a brown spot, or a dark spot.
3. Compute the percentages and map the total to a `visualStatus`:

   | totalBrowningPercentage | visualStatus |
   |-------------------------|--------------|
   | `0 - 10 %` | Fresh |
   | `10 - 25 %` | Slight Browning |
   | `25 - 50 %` | Browning Detected |
   | `>= 50 %` | Consume Soon |

4. Save `{brownSpotPercentage, darkSpotPercentage, totalBrowningPercentage,
   visualStatus}` under `/devices/<id>/bananaAnalysis/<productId>`.

**QR product registration** — fetch the camera image, decode the QR code with
OpenCV (`cv2.QRCodeDetector`), and save the product under
`/devices/<id>/products/<productId>`.

## Setup

```bash
cd backend/optional-image-analysis-service
python -m venv .venv
.venv/Scripts/activate          # Windows  (use: source .venv/bin/activate  on Linux/macOS)
pip install -r requirements.txt
cp .env.example .env            # then edit .env with your values
```

`.env` is git-ignored. Leave `FIREBASE_HOST` blank to run as a pure local
analyzer with no write-back.

## Usage

### Banana analysis — one-shot CLI

```bash
python app.py --product banana_001            # fetch from the camera
python app.py --file sample_banana.png --no-write   # analyze a local image
```

### QR product registration

```bash
python app.py --register     # capture once, decode the QR, save the product
```

### HTTP server mode

```bash
python app.py --serve
```

```bash
curl http://localhost:5000/health

# banana analysis for a product
curl -X POST http://localhost:5000/analyze \
     -H "Content-Type: application/json" \
     -d "{\"productId\":\"banana_001\"}"

# capture + QR decode + register a product
curl -X POST http://localhost:5000/register
```

Add `?write=false` to `/analyze` to skip the Firebase write-back.

## Endpoints

| Method | Path | Purpose |
|--------|------|---------|
| GET | `/health` | Liveness check + configured capture URL |
| POST | `/analyze` | Banana browning analysis of the current camera image |
| POST | `/register` | Capture, decode the QR code and register the product |

## Notes

- The laptop running this service must be on the **same Wi-Fi network** as the
  ESP32-CAM (the capture URL is a LAN HTTP address).
- Thresholds in `analyze_browning()` can be tuned for your lighting; the
  enclosed box keeps lighting fairly constant, which helps.
- This service never stores secrets in code — all config comes from `.env`.
