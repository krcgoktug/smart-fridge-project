# Setup Guide

Step-by-step setup for the Zero Waste Smart Fridge.

---

## 1. Firebase

1. Go to <https://console.firebase.google.com> and create a project.
2. Open **Build → Realtime Database** and create a database.
3. For development, start in **test mode** (open rules). Tighten the rules
   before a public demo.
4. Note your **database URL**, e.g.
   `https://your-project-default-rtdb.firebaseio.com`.
5. (For the ESP32) get a database secret/token: **Project settings →
   Service accounts → Database secrets**, or use a test-mode rule.

The structure (`devices/fridge_01/sensors`, `camera`, `products`) is created
automatically once the ESP32 and app start writing. See
[firebase-schema.json](firebase-schema.json).

## 2. ESP32 DevKit — sensor controller

1. Install the **Arduino IDE** and the **esp32** board package.
2. Install libraries: DHT sensor library, Adafruit Unified Sensor, HX711,
   ArduinoJson.
3. `firmware/esp32-devkit/` → copy `secrets.example.h` to `secrets.h` and fill
   in Wi-Fi SSID/password, the Firebase URL and the auth token.
4. Wire the sensors — see [wiring.md](wiring.md).
5. Select **ESP32 Dev Module**, upload, open the Serial Monitor (115200).
   You should see `[Upload] OK -> devices/fridge_01/sensors`.

## 3. ESP32-CAM — camera

1. `firmware/esp32-cam/` → copy `cam_secrets.example.h` to `cam_secrets.h`
   and fill in Wi-Fi only.
2. Connect an FTDI/USB-TTL adapter (3.3 V), jumper **GPIO 0 → GND** to flash.
3. Select **AI Thinker ESP32-CAM**, upload, remove the jumper, press RESET.
4. Open the Serial Monitor (115200) — note the printed IP:

   ```
   Camera Ready!
   Local IP: 192.168.1.44
   Stream:   http://192.168.1.44/stream
   ```

5. Test it: open `http://<ip>/` in a browser on the same Wi-Fi.

## 4. Flutter app

1. Install the [Flutter SDK](https://docs.flutter.dev/get-started/install).
2. In `mobile/smart_fridge_app/`:

   ```bash
   flutter pub get
   dart pub global activate flutterfire_cli
   flutterfire configure          # generates lib/firebase_options.dart
   flutter run                    # device / emulator
   ```

3. In the app, open the **Camera** tab, enter the ESP32-CAM IP, tap **Save**,
   then **Test** — it should show "Camera Online".
4. Point the camera at a product QR sticker and tap **Scan QR**.

### Build an Android APK

```bash
flutter build apk --release
# build/app/outputs/flutter-apk/app-release.apk
```

## 5. Network notes

- The phone running the app and the ESP32-CAM must be on the **same Wi-Fi**
  for the live stream to work.
- Sensor data goes through Firebase, so it is visible from anywhere — the
  ESP32 DevKit only needs Wi-Fi, not the same network as the phone.

## Troubleshooting

| Problem | Fix |
|---------|-----|
| App shows "ESP32 Sensor Board Offline" | Check the DevKit's Wi-Fi / power; confirm uploads in the Serial Monitor |
| "Camera unavailable" | Phone and ESP32-CAM must be on the same Wi-Fi; check the IP |
| `Upload failed, HTTP 401` | Wrong Firebase auth token or database rules |
| App shows no data | Run `flutterfire configure` to connect a real project |
