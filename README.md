# Zero Waste Smart Fridge

<div align="center">

## 👥 Yapanlar / Developers

# 🌱 Sıla Özgel  ·  Göktuğ Karaca  ·  Ezgi Erdoğan 🌱

</div>

---

An IoT-based smart food monitoring system that helps reduce household food waste.
The system tracks products stored inside a transparent plastic box, estimates a
relative **spoilage risk score** for each item, and warns the user before food
goes bad.

> University microcontroller project — built around ESP32, Firebase Realtime
> Database and a Flutter mobile app.

---

## What it does

- Reads environmental sensors (temperature, humidity, gas, weight) inside the box.
- Identifies products via **QR code stickers** scanned by the mobile app.
- Captures product images with an ESP32-CAM for **banana browning detection**.
- Combines all signals into a **risk score (0-100)** and a status:
  - `Fresh` (0-39)
  - `Consume Soon` (40-69)
  - `Spoilage Risk` (70-100)
- Shows everything on a clean Flutter dashboard and raises alerts.

## Box dimensions

Transparent plastic box: **47 cm x 72.5 cm x 36.2 cm**.

## Supported products

banana, apple, tomato, cucumber, milk carton, yogurt cup, cheese package,
egg box, packaged food. Every product carries a QR code sticker.

---

## System architecture

```
+---------------------+        +----------------------+
|  ESP32 DevKit V1    |        |  ESP32-CAM AI Thinker|
|  - MQ135 gas        |        |  - OV2640 camera     |
|  - DHT11 temp/hum   |        |  - CameraWebServer   |
|  - HX711 + 4 cells  |        |  - /stream, /capture |
|  - risk score calc  |        +----------+-----------+
+----------+----------+                   |
           |  JSON over Wi-Fi             |  image URLs
           v                              v
   +----------------------------------------------+
   |        Firebase Realtime Database            |
   |  /devices/fridge_01/{sensors,camera,         |
   |                      products,alerts}        |
   +-----------------------+----------------------+
                           |
                  +--------v---------+
                  |  Flutter app     |
                  |  + optional      |
                  |  Python image    |
                  |  analysis svc    |
                  +------------------+
```

Full details: [docs/architecture.md](docs/architecture.md).

---

## Repository structure

```
smart-fridge-project/
  README.md
  docs/                     Architecture, wiring, schema, demo, report
  firmware/
    esp32-devkit-sensors/   Arduino sketch for sensors + Firebase upload
    esp32-cam-camera/       Arduino sketch for the camera web server
    arduino-uno-calibration/ HX711 load cell calibration helper
  mobile/
    smart_fridge_app/       Flutter mobile application
  backend/
    optional-image-analysis-service/   Python banana browning analysis
  qr-samples/               Sample product QR JSON + generation guide
```

---

## Quick start

### 1. Firebase

1. Create a Firebase project at <https://console.firebase.google.com>.
2. Enable **Realtime Database** (not Firestore).
3. Import the schema layout from [docs/firebase-schema.json](docs/firebase-schema.json).
4. For development, set the rules to test mode; for the demo, restrict them.

### 2. Firmware (ESP32)

- See [firmware/esp32-devkit-sensors/README.md](firmware/esp32-devkit-sensors/README.md)
  for the sensors board.
- See [firmware/esp32-cam-camera/README.md](firmware/esp32-cam-camera/README.md)
  for the camera board.
- Wiring table: [docs/wiring.md](docs/wiring.md).

### 3. Mobile app (Flutter)

```bash
cd mobile/smart_fridge_app
flutter pub get
flutterfire configure
flutter run
```

### 4. Optional image analysis backend

```bash
cd backend/optional-image-analysis-service
python -m venv .venv
.venv/Scripts/activate
pip install -r requirements.txt
python app.py
```

---

## Risk score model

```
riskScore = expiryRisk + temperatureRisk + humidityRisk
          + gasRisk + visualRisk + weightRisk     (capped at 100)
```

Different product categories use different components — see
[docs/architecture.md](docs/architecture.md#risk-score-logic).

---

## Security

- **No real secrets are committed.** Wi-Fi/Firebase credentials use template
  files (`*.example`) and are listed in `.gitignore`.
- Copy `firmware/esp32-devkit-sensors/secrets.example.h` to `secrets.h` and fill
  in your own values.
- Copy `mobile/smart_fridge_app/lib/firebase_options.dart.example` (or run
  `flutterfire configure`) to provide your own Firebase config.

---

## License

Educational / university project. Free to use for learning purposes.
