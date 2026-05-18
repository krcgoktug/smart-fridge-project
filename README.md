# Zero Waste Smart Fridge

A simple, real **IoT + mobile** university project. Two ESP32 devices watch a
storage box, Firebase carries the data, and a clean Flutter app shows it.

No backend. No AI. No fake hardware. Just sensors, a camera, QR codes,
Firebase and a mobile app.

---

## What it does

- An **ESP32 DevKit** reads temperature, humidity, gas and weight and uploads
  them live to Firebase.
- An **ESP32-CAM** runs a camera web server (live stream + snapshot).
- The **Flutter app** shows the sensors, the live camera stream, and lets you
  **scan product QR codes** from the camera to register products.
- Products get an **expiry status** (Fresh / Expiring Soon / Expired) and the
  app raises **alerts**.

## Two devices

| Device | Job |
|--------|-----|
| **ESP32 DevKit** | MQ135 gas, DHT11 temp+humidity, HX711 weight → Firebase |
| **ESP32-CAM** | CameraWebServer: `/`, `/stream`, `/capture` |

The two are independent. Each ESP32-CAM gets its **own local IP** — you enter
it in the app (it is never hard-coded).

## Architecture

```
ESP32 DevKit ──Wi-Fi──> Firebase Realtime DB ──> Flutter app
ESP32-CAM    ──local network MJPEG/capture──────> Flutter app
```

Full details + diagram: **[docs/architecture.md](docs/architecture.md)**.

### Honest network note

- **Sensor data is cloud-based** — through Firebase, so every team member sees
  it live from anywhere, even though the ESP32 is plugged into one PC.
- **The ESP32-CAM stream is local-network only** — only a phone/PC on the
  **same Wi-Fi** as the camera can view `http://<camera-ip>/stream`.

---

## Repository structure

```
smart-fridge-project/
  README.md
  docs/                     architecture, wiring, firebase-schema, setup
  firmware/
    esp32-devkit/           sensor controller (DHT11 + MQ135 + HX711)
    esp32-cam/              camera (CameraWebServer)
  mobile/
    smart_fridge_app/       Flutter app (5 screens)
  qr-samples/               sample product QR payloads + guide
```

---

## Setup (short version)

Full step-by-step: **[docs/setup-guide.md](docs/setup-guide.md)**.

1. **Firebase** — create a project, enable **Realtime Database**.
2. **ESP32 DevKit** — `firmware/esp32-devkit/`: copy `secrets.example.h` →
   `secrets.h`, fill in Wi-Fi + Firebase, upload.
3. **ESP32-CAM** — `firmware/esp32-cam/`: copy `cam_secrets.example.h` →
   `cam_secrets.h`, fill in Wi-Fi, upload. Note the IP it prints.
4. **App** — `mobile/smart_fridge_app/`:
   ```bash
   flutter pub get
   flutterfire configure      # generates lib/firebase_options.dart
   flutter run
   ```
   Open the **Camera** tab, enter the ESP32-CAM IP, and scan product QR codes.

---

## QR codes

Each product has a printed QR sticker holding a small JSON payload:

```json
{ "productId": "milk_001", "name": "Milk", "category": "Dairy",
  "expiryDate": "2026-05-25", "addedDate": "2026-05-18" }
```

Samples + a generation guide: [qr-samples/](qr-samples/).

---

## Security

No real secrets are committed. Wi-Fi / Firebase credentials use `*.example`
templates (`secrets.h`, `cam_secrets.h` are git-ignored). `firebase_options.dart`
ships with placeholders — replace it with `flutterfire configure`.

## License

Educational / university project. Free to use for learning.
