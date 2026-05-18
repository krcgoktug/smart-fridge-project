# Smart Fridge — Flutter App

The **visualization layer** of the Zero Waste Smart Fridge. It is a
**read-only** dashboard: it reads Firebase Realtime Database and displays the
ESP32-CAM stream. It does **no** writing, **no** QR decoding and **no** image
processing — the ESP32 boards and the Python backend do that.

## Screens

| Screen | Shows |
|--------|-------|
| Dashboard | ESP32 online/offline, live sensors, banana analysis, alerts |
| Products | QR-detected products with expiry status |
| Camera | Live ESP32-CAM MJPEG stream |
| Alerts | Alerts derived on-device from the live data |
| Settings | ESP32-CAM IP, Firebase status, hardware-mode note |

## Project layout

```
lib/
  main.dart                  App entry + bottom navigation
  app_config.dart            Device id / database root
  firebase_options.dart      PLACEHOLDER config (replace via flutterfire)
  models/                    SensorData, Product, BananaAnalysis, Alert
  services/
    firebase_service.dart    Read-only Realtime Database streams
    alert_service.dart       Derives alerts from the data
    settings_service.dart    Persists the ESP32-CAM address
  utils/status_colors.dart   Green / amber / red palette
  widgets/                   SensorCard, ProductCard, StatusBadge
  screens/                   The five screens above
```

## Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) 3.27 or newer.
- A device/emulator. For the **live camera** the device must be on the same
  Wi-Fi as the ESP32-CAM.

## Setup

```bash
cd mobile/smart_fridge_app
flutter pub get
```

### Firebase

`lib/firebase_options.dart` ships with **placeholder** values, so the app
compiles and opens but shows empty / "ESP32 Offline" states. Connect a real
project:

```bash
dart pub global activate flutterfire_cli
flutterfire configure
```

## Run

```bash
flutter run                 # device / emulator / -d chrome
```

### Android APK

```bash
flutter build apk --release
# output: build/app/outputs/flutter-apk/app-release.apk
```

The repo also builds the APK in CI — see
[`.github/workflows/build-apk.yml`](../../.github/workflows/build-apk.yml);
download it from the **Actions** tab.

### Web

```bash
flutter build web
```

> The web build is **UI only**. On the HTTPS GitHub Pages site browsers block
> the ESP32-CAM's HTTP stream (mixed content). Use the Android app or a local
> run for the real camera stream.

## Camera address

The ESP32-CAM IP is **not hard-coded**. Set it in the app under
**Settings → ESP32-CAM address** (e.g. `http://192.168.1.50`). The Camera
screen then shows `http://<ip>/stream`.

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| Everything empty / "ESP32 Offline" | Firebase not configured — run `flutterfire configure` |
| Camera screen blank | Set the ESP32-CAM IP in Settings; same Wi-Fi |
| Camera works on phone, not on web | Expected — HTTPS blocks the HTTP stream |
| Build fails: no `android/` folder | Run `flutter create --platforms=android,web .` |
