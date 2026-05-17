# Smart Fridge — Flutter App

The mobile application for the Zero Waste Smart Fridge. It reads live data
from Firebase Realtime Database, scans product QR codes, computes per-product
and global risk scores, and shows alerts.

## Screens

| # | Screen | Purpose |
|---|--------|---------|
| 1 | Dashboard | Sensors, global risk, camera preview, latest alerts |
| 2 | Product List | All products with status + risk color |
| 3 | Add Product / QR Scan | Scan a QR code (or manual entry) |
| 4 | Product Detail | QR metadata, weight, visual status, risk breakdown |
| 5 | Camera View | Live ESP32-CAM image + endpoint URLs |
| 6 | Alerts | Notification list (swipe to dismiss) |
| 7 | Settings | Firebase/hardware/risk-model info |

## Project layout

```
lib/
  main.dart                 App entry + bottom-navigation shell
  app_config.dart           Device id, categories, constants
  firebase_options.dart     PLACEHOLDER config (replace via flutterfire)
  models/                   Product, SensorData, Alert
  services/
    firebase_service.dart   Realtime Database streams + writes
    risk_service.dart       Risk score algorithm (canonical implementation)
  utils/status_colors.dart  Green / yellow / red palette
  widgets/                  SensorCard, ProductCard, StatusBadge, ...
  screens/                  The seven screens above
```

## Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) 3.3 or newer.
- A device or emulator (QR scanning needs a **real device** with a camera;
  use the manual-entry fallback on emulators).

## Setup

The `android/` and `web/` platform folders are committed, so the app is
runnable straight after cloning:

```bash
cd mobile/smart_fridge_app
flutter pub get
```

> iOS is not committed. To add it: `flutter create --platforms=ios .`

### Firebase configuration

The committed `lib/firebase_options.dart` contains **placeholder** values, so
the app compiles and opens but shows a "Firebase not configured" notice.
Connect it to your own Firebase project:

```bash
# install the FlutterFire CLI once
dart pub global activate flutterfire_cli

# generate real lib/firebase_options.dart and native config
flutterfire configure
```

Make sure **Realtime Database** is enabled in the Firebase console and that the
database layout matches [../../docs/firebase-schema.json](../../docs/firebase-schema.json).

## Run

```bash
flutter run
```

### Optional: Flutter Web demo

```bash
flutter run -d chrome
# or build a static bundle:
flutter build web
```

The `build/web` output can be deployed to Firebase Hosting or Vercel. Note
that the live ESP32-CAM image is a LAN HTTP URL, so the camera preview only
works on a device on the same Wi-Fi network.

## How the app uses Firebase

| Path | App behavior |
|------|--------------|
| `sensors` | Read live; feeds the dashboard and risk recompute |
| `camera` | Read `captureUrl` for the camera preview |
| `products` | Read all; QR scan / manual entry writes new products |
| `alerts` | Read all; writes an alert when a product is added |

The app recomputes every product's risk score on the fly from the latest
sensor values using `risk_service.dart`, so the displayed score always
reflects current conditions.

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| "Firebase not configured" everywhere | Run `flutterfire configure`, restart |
| Build fails: no ios folder | Run `flutter create --platforms=ios .` |
| QR scanner is black | Use a real device; grant camera permission |
| Camera preview fails | Phone must be on the same Wi-Fi as the ESP32-CAM |
