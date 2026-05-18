# Zero Waste Smart Fridge

A real-time **IoT + computer-vision** system that helps reduce household food
waste. Sensors watch the storage environment, a camera feeds a vision
pipeline that reads product QR codes and measures banana spoilage, and a
Flutter app shows everything live.

> University / TÜBİTAK-style IoT project — ESP32 hardware, a Python computer
> vision backend, Firebase Realtime Database, and a Flutter dashboard app.

---

## Architecture in one line

Four independent layers, each doing exactly one job — no fake AI, no
placeholder features:

```
ESP32 DevKit ─ sensors ─┐
                        ├─> Firebase Realtime DB ─> Flutter app (read-only)
Python backend ─ CV ────┘            ^
   (QR + banana analysis)            │
ESP32-CAM ─ MJPEG stream ────────────┘  (backend pulls frames; app shows stream)
```

Full design + diagrams: **[docs/architecture.md](docs/architecture.md)**.

| Layer | What it does |
|-------|--------------|
| **ESP32 DevKit V1** | Reads HX711 weight, DHT11 temperature, MQ135 gas. Sends a heartbeat to Firebase every 10 s. |
| **ESP32-CAM** | Camera only — always-on MJPEG stream + snapshot endpoint. No QR, no AI. |
| **Python backend** | The processing engine: pulls camera frames, decodes QR codes (OpenCV + pyzbar), runs pixel-based banana browning analysis (HSV), writes results to Firebase. |
| **Flutter app** | Read-only dashboard: live sensors, QR products, banana analysis, camera stream, alerts. |

If the ESP32 sends nothing for **60 s**, the app shows **"ESP32 Offline"**.

---

## Live web demo (UI only)

The Flutter app is auto-deployed to **GitHub Pages** on every push to `main`:

**https://krcgoktug.github.io/smart-fridge-project/**

> **This is a UI demo only.** GitHub Pages is served over HTTPS, and browsers
> block the ESP32-CAM's local **HTTP** stream (mixed content). Live camera +
> live data need **Hardware Mode**.

### Hardware Mode — Android app or local run

For the real camera stream and live data, run the app where it can reach the
local network:

- **Android app** — the repo builds a release APK via
  [`.github/workflows/build-apk.yml`](.github/workflows/build-apk.yml).
  Download it from the **Actions** tab → "Build Android APK" → latest run →
  Artifacts → `smart-fridge-app-release-apk`.
- **Local run** — `flutter run` on a device/emulator on the same Wi-Fi.

---

## Repository structure

```
smart-fridge-project/
  README.md
  docs/                       Architecture (+ diagrams), wiring, schema, demo
  firmware/
    esp32-devkit-sensors/     ESP32 DevKit — sensor controller sketch
    esp32-cam-camera/         ESP32-CAM — camera-only sketch
  backend/
    processing-engine/        Python QR + banana CV processing engine
  mobile/
    smart_fridge_app/         Flutter dashboard app (read-only viewer)
  qr-samples/                 Sample product QR payloads + generation guide
  .github/workflows/          Web deploy + Android APK build
```

---

## Setup

### 1. Firebase

1. Create a project at <https://console.firebase.google.com>.
2. Enable **Realtime Database** (not Firestore).
3. The structure is in [docs/firebase-schema.json](docs/firebase-schema.json) —
   the ESP32 and backend create the nodes automatically once configured.

### 2. Firmware

- ESP32 DevKit (sensors): [firmware/esp32-devkit-sensors/README.md](firmware/esp32-devkit-sensors/README.md)
- ESP32-CAM (camera): [firmware/esp32-cam-camera/README.md](firmware/esp32-cam-camera/README.md)
- Wiring: [docs/wiring.md](docs/wiring.md)

### 3. Backend (processing engine)

```bash
cd backend/processing-engine
python -m venv .venv
.venv/Scripts/activate              # Windows
pip install -r requirements.txt
cp .env.example .env                # set CAMERA_BASE_URL + Firebase
python app.py                       # continuous QR + banana processing
```

Details: [backend/processing-engine/README.md](backend/processing-engine/README.md).

### 4. Flutter app

```bash
cd mobile/smart_fridge_app
flutter pub get
flutterfire configure               # generates lib/firebase_options.dart
flutter run                         # or: flutter build apk
```

Details: [mobile/smart_fridge_app/README.md](mobile/smart_fridge_app/README.md).

---

## QR codes

Each product carries our own printed QR code with a tiny JSON payload:

```json
{ "product": "Milk", "expiry": "2026-05-25" }
```

The backend decodes it from the camera frame and registers the product. See
[qr-samples/](qr-samples/).

---

## Security

- **No real secrets are committed.** Credentials use `*.example` templates and
  `.gitignore` (`secrets.h`, `cam_secrets.h`, `.env`).
- `lib/firebase_options.dart` ships with placeholder values so the app
  compiles; replace it with `flutterfire configure`.

---

## License

Educational / university project. Free to use for learning purposes.
