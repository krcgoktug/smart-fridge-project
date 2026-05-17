# Optional Image Analysis Service

A small Python service that performs **banana browning detection** with
lightweight image processing — **no machine learning**.

It is **optional**: the Flutter app can do the same analysis on the phone.
This service exists so the work can run on a laptop and write results back to
Firebase, which is convenient for the demo.

## What it does

1. Fetches the latest JPEG from the ESP32-CAM `/capture` URL.
2. Detects brown/dark pixels using HSV + RGB thresholds.
3. Computes `browningRatio` and maps it to a `visualStatus`:

   | browningRatio | visualStatus |
   |---------------|--------------|
   | `< 0.10` | Fresh |
   | `0.10 - 0.25` | Slight Browning |
   | `0.25 - 0.50` | Browning Detected |
   | `>= 0.50` | Consume Soon |

4. Optionally PATCHes `browningRatio` + `visualStatus` into
   `/devices/<DEVICE_ID>/products/<productId>` in Firebase.

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

### One-shot CLI (fetch from the camera)

```bash
python app.py --product banana_001
```

### Analyze a local image (offline / demo fallback)

```bash
python app.py --file sample_banana.jpg --no-write
```

### HTTP server mode

```bash
python app.py --serve
```

Then call it:

```bash
# health check
curl http://localhost:5000/health

# analyze the current camera frame for a product
curl -X POST http://localhost:5000/analyze \
     -H "Content-Type: application/json" \
     -d "{\"productId\":\"banana_001\"}"
```

Add `?write=false` to the `/analyze` URL to skip the Firebase write-back.

## Endpoints

| Method | Path | Purpose |
|--------|------|---------|
| GET | `/health` | Liveness check + configured capture URL |
| POST | `/analyze` | Analyze the current camera image for a product |

## Notes

- The laptop running this service must be on the **same Wi-Fi network** as the
  ESP32-CAM (the capture URL is a LAN HTTP address).
- Thresholds in `analyze_browning()` can be tuned for your lighting; the
  enclosed box keeps lighting fairly constant, which helps.
- This service never stores secrets in code — all config comes from `.env`.
