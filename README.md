# Zero Waste Smart Fridge

A real-time **IoT + computer-vision** system that helps reduce household food
waste. Sensors watch the storage environment, an ESP32-CAM continuously
monitors a transparent box, a Python service reads product QR codes and
measures banana spoilage, and a Flutter app shows everything live.

> University-style IoT project — ESP32 hardware, a Python computer-vision
> service, Firebase Realtime Database, and a Flutter dashboard app. No fake
> AI, no faked camera previews.

---

## Architecture in one line

Four independent layers, each doing exactly one job:

```
ESP32 DevKit ─ sensors ─────────┐
                                ├─> Firebase Realtime DB ─> Flutter app (read-only)
Image analysis service ─ CV ────┘            ^
   (QR + banana + camera + alerts)           │
ESP32-CAM ─ MJPEG stream ────────────────────┘  (service pulls frames; app shows stream)
```

Full design + diagrams: **[docs/architecture.md](docs/architecture.md)**.

| Layer | What it does |
|-------|--------------|
| **ESP32 DevKit V1** | Reads HX711 weight, DHT11 temperature, MQ135 gas. Sends a heartbeat to Firebase every 10 s. |
| **ESP32-CAM** | Camera only — always-on MJPEG stream + snapshot endpoint. No QR, no AI, no Firebase. |
| **Image analysis service** | Python: pulls camera frames, decodes QR codes (OpenCV + pyzbar), runs pixel-based banana browning analysis (HSV), publishes camera status and alerts to Firebase. |
| **Flutter app** | Read-only dashboard: live sensors, QR products, banana analysis, camera stream, alerts. |

If the ESP32 sends nothing for **60 s**, the app shows **"ESP32 Offline"**.

---

## Running the app

The Flutter app is a **read-only viewer** of the Firebase data.

- **Android app / local run** — for the **live ESP32-CAM stream** the app must
  run where it can reach the camera on the **same Wi-Fi** (Android phone or a
  local `flutter run`).
- **Web build** — can show sensors, products, banana analysis and alerts, but
  **not** the live camera: a browser blocks the ESP32-CAM's HTTP stream from
  an HTTPS page (mixed content).

This is a real limitation of local HTTP IoT devices, explained honestly in
**[docs/camera-limitations.md](docs/camera-limitations.md)** — the project does
not fake camera previews or claim a hosted page can show the live stream.

Exact Windows commands for a local Chrome run, an Android phone run, an APK
build and hardware mode are in
**[mobile/smart_fridge_app/README.md](mobile/smart_fridge_app/README.md#running-the-app-windows)**.

---

## Repository structure

```
smart-fridge-project/
  README.md
  docs/                       Setup guide, architecture, schema, QR, banana, camera, wiring
  firmware/
    esp32-devkit/             ESP32 DevKit — sensor controller sketch
    esp32-cam/                ESP32-CAM — camera-only sketch
  backend/
    image-analysis-service/   Python QR + banana CV processing service
  mobile/
    smart_fridge_app/         Flutter dashboard app (read-only viewer)
  qr-samples/                 Sample product QR payloads + generation guide
```

---

## Setup

> **New to this? Follow the click-by-click walkthrough:
> [docs/setup-guide.md](docs/setup-guide.md)** — it covers creating the
> Firebase database, filling in the config files and flashing both ESP32
> boards, step by step. The summary below is the short version.

### 1. Firebase

1. Create a project at <https://console.firebase.google.com>.
2. Enable **Realtime Database** (not Firestore).
3. The structure is in [docs/firebase-schema.md](docs/firebase-schema.md) —
   the ESP32 and the service create the nodes automatically once configured.

### 2. Firmware

- ESP32 DevKit (sensors): [firmware/esp32-devkit/README.md](firmware/esp32-devkit/README.md)
- ESP32-CAM (camera): [firmware/esp32-cam/README.md](firmware/esp32-cam/README.md)
- Wiring: [docs/wiring.md](docs/wiring.md)

### 3. Image analysis service

```bash
cd backend/image-analysis-service
python -m venv .venv
.venv/Scripts/activate              # Windows
pip install -r requirements.txt
cp .env.example .env                # set CAMERA_BASE_URL + Firebase
python app.py                       # continuous QR + banana processing
```

Details: [backend/image-analysis-service/README.md](backend/image-analysis-service/README.md).

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

Each product carries our own printed QR sticker with a small JSON payload:

```json
{ "productId": "banana_001", "name": "Banana",
  "expiryDate": "2026-05-25", "category": "Fruit" }
```

The service decodes it from the camera frame and registers the product
automatically — there is **no manual product entry**. See
[docs/qr-system.md](docs/qr-system.md) and [qr-samples/](qr-samples/).

---

## Security

- **No real secrets are committed.** Credentials use `*.example` templates and
  `.gitignore` (`secrets.h`, `cam_secrets.h`, `.env`).
- `lib/firebase_options.dart` ships with placeholder values so the app
  compiles; replace it with `flutterfire configure`.

---

## License

Educational / university project. Free to use for learning purposes.
