# Zero Waste Smart Fridge

> A real **IoT + computer-vision + mobile** university project. An Arduino Uno
> watches a storage box, an ESP32-CAM provides live video + QR scanning,
> and a Flutter app shows everything live.

### 🎬 [**Live demo (UI only)**](https://krcgoktug.github.io/smart-fridge-project/)

The live link runs the actual Flutter web build. Without the local sensors
connected it shows the UI in "offline" state — useful for previewing the
interface, layout, and screens.

---

## What it does

- **Arduino Uno** reads:
  - **DHT11** — temperature + humidity
  - **MQ135** — gas / VOC concentration
  - **HX711 + 4× load cells** — weight (calibrated, with software drift
    compensation + tare command)
- **ESP32-CAM** runs a tiny HTTP server with:
  - **Port 80** `/capture` — JPEG snapshot
  - **Port 81** `/stream` — MJPEG live video
- **Python bridge** (`bridge/arduino_serial_bridge.py`) reads the Arduino's
  USB serial JSON lines and exposes them at `http://localhost:8787/sensors`
  with permissive CORS so the browser app can poll them.
- **Flutter app** (web + Android) shows:
  - Live sensors, status, alerts
  - ESP32-CAM live stream
  - **Multi-QR scanning** (3×3 tiled decode, registers every distinct sticker
    once per session)
  - **Banana ripeness analysis** from the camera feed (pixel-level RGB
    classification, banded into Fresh / Spotting / Spoiling / Spoiled)
  - **Re-tare load cells** button (round-trips through bridge → Arduino)
  - **Recalibrate gas baseline** endpoint
  - Product expiry tracking with Fresh / Expiring Soon / Expired bands

---

## Data flow

```
                       ┌─────────────────────────────┐
Arduino Uno  ──USB──>  │ bridge/arduino_serial_bridge│  ──HTTP──>  Flutter web app
(sensors)              │  (Python, localhost:8787)   │             (Dashboard / Alerts / Products)
                       └─────────────────────────────┘
                                                          ▲
ESP32-CAM    ──LAN Wi-Fi (port 80 + 81)──────────────────┘
(camera)
```

- **Sensors** ride the USB cable into the Python bridge, then HTTP into the
  browser.
- **Camera** is on the same Wi-Fi as the PC/phone running the app; the
  browser talks to it directly over the local network.
- Firebase Realtime Database integration is wired up in code but ships with
  placeholder credentials; the app works fully offline-first by default
  (in-memory product store).

Full diagrams: **[docs/architecture.md](docs/architecture.md)**.

---

## Repository structure

```
smart-fridge-project/
  README.md
  docs/                          architecture, wiring, setup, demo
  bridge/
    arduino_serial_bridge.py     USB-serial → HTTP at localhost:8787
  firmware/
    arduino-uno/                 main sensor sketch (DHT11 + MQ135 + HX711 + LED)
    arduino-uno-calibration/     one-shot HX711 calibration helper
    esp32-cam/                   camera firmware (AI Thinker board)
  mobile/
    smart_fridge_app/            Flutter app (Dashboard / Camera / Products / Alerts / Settings)
  qr-samples-demo/               generator + printable A4 PDFs for demo QR stickers
```

---

## Try it on your PC (full hardware setup)

### 1. Wire the Arduino Uno

| Sensor | Pin |
| --- | --- |
| DHT11 data | **D3** |
| MQ135 AOUT | **A0** |
| HX711 DT | **D4** |
| HX711 SCK | **D5** |
| Status LED | **D9** |

### 2. Flash the firmware

In Arduino IDE (Library Manager): install **DHT sensor library** (Adafruit) +
**HX711 Arduino Library** (Bogdan Necula), then upload
`firmware/arduino-uno/arduino-uno.ino` to the Uno (COM5, 9600 baud).

Optional — first-time HX711 calibration: flash
`firmware/arduino-uno-calibration/arduino-uno-calibration.ino`, send `t` to
tare, place a known mass, type its grams + Enter, paste the printed
`calibration_factor` into the main sketch and re-flash.

For the camera, flash `firmware/esp32-cam/esp32-cam.ino` to an AI Thinker
ESP32-CAM. The camera prints its assigned IP on the Serial Monitor when it
joins Wi-Fi.

### 3. Start the bridge

```bash
pip install pyserial
python bridge/arduino_serial_bridge.py --port COM5
```

It auto-detects an Arduino-looking COM port if `--port` is omitted. Exposes
GET `/sensors`, POST `/tare`, POST `/recalibrate_gas`.

### 4. Run the Flutter app

```bash
cd mobile/smart_fridge_app
flutter pub get
flutter run -d chrome             # web
# or
flutter run                       # Android (phone on same Wi-Fi)
```

On the app:

- **Settings** → set the bridge URL (`http://localhost:8787` if local; use
  the laptop's LAN IP from a phone)
- **Camera** → enter the ESP32-CAM IP (just the IP, no port), tap **Save**

You'll see sensors stream live, the camera feed, QR auto-scan, banana
analysis, and alerts. Press **Tare scale** on the Dashboard to zero the
load cells from the UI.

---

## QR codes for the demo

Each product is encoded as a JSON QR payload:

```json
{ "productId": "milk_001",
  "name":      "Milk",
  "category":  "Dairy",
  "expiryDate":"2026-06-14",
  "addedDate": "2026-06-02" }
```

The Camera screen scans **multiple QRs in one frame** (3×3 overlapping tile
decoder) and registers each sticker exactly once per session.

Generate your own + print an A4 sheet:

```bash
pip install qrcode pillow
python qr-samples-demo/generate.py
```

Output: individual PNGs and `a4_qrs_5p5cm.pdf` — print at **100% scale**
(Actual size). Five demo products with mixed expiry dates so the Alerts
screen shows both **Expired** and **Expiring Soon** states out of the box.

---

## What's honestly real vs. demo-scope

| Area | Status |
| --- | --- |
| Temperature / humidity / weight | ✅ Real sensors, live, calibrated |
| MQ135 gas | ✅ Real sensor; cheap modules show baseline drift |
| ESP32-CAM live stream | ✅ Real MJPEG + JPEG capture |
| QR scanning (multi-code) | ✅ zxing2 + tiled re-decoding |
| Banana ripeness | ⚠️ Honest pixel-level RGB classifier, **not** ML / histogram / texture |
| Firebase RTDB integration | ⚠️ Wired in code; ships with placeholders → in-memory only by default |
| Push notifications / auth | ❌ Not implemented |

The project is intentionally honest about what's done. See
[docs/report-explanation.md](docs/report-explanation.md) for the report
language we use.

---

## Demo deployment

The `docs/` folder is the Flutter web build configured for GitHub Pages
(`<base href="/smart-fridge-project/">` + `.nojekyll`). Visiting
[the live link](https://krcgoktug.github.io/smart-fridge-project/) loads
the real interface — every screen, every widget, exactly as it runs
locally. Without the bridge it shows "offline" for sensors, which is the
correct degraded behaviour.

To redeploy after changes:

```bash
cd mobile/smart_fridge_app
flutter build web --release --pwa-strategy=none --base-href "/smart-fridge-project/"
cp -r build/web/* ../../docs/
touch ../../docs/.nojekyll
git add docs && git commit -m "Refresh demo build" && git push
```

GitHub Pages → Settings → Pages → Source: **main / docs**.

---

## Security

No real secrets are committed. Wi-Fi / camera credentials use
`*.example` files (the real `cam_secrets.h`, `secrets.h` are `.gitignore`d).
`firebase_options.dart` ships with placeholders — replace it locally via
`flutterfire configure`.

## License

Educational / university project. Free to use for learning.
