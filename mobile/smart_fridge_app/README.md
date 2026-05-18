# Smart Fridge — Flutter App

The mobile app for the Zero Waste Smart Fridge. It reads sensor data and
products from Firebase, shows the live ESP32-CAM stream, and registers
products by scanning their QR codes.

## Screens

| Screen | Shows |
|--------|-------|
| Dashboard | temperature, humidity, gas, weight, ESP32 status, products, alerts, camera preview |
| Camera | camera IP input, test connection, live stream, capture, QR scan |
| Products | product cards — category, expiry, remaining days, status color |
| Alerts | expiry warnings, ESP32 offline, camera offline |
| Settings | Firebase info, camera IP, hardware-mode notes |

## Project layout

```
lib/
  main.dart                 App entry + bottom navigation
  app_config.dart           Device id / database root
  firebase_options.dart     PLACEHOLDER config (replace via flutterfire)
  models/                   SensorData, Product, CameraConfig, Alert
  services/
    firebase_service.dart   Realtime Database reads + writes
    camera_service.dart     Test connection, capture frame, decode QR
    settings_service.dart   Local cache of the camera IP
    alert_service.dart      Derives alerts from the data
  utils/status_colors.dart  Green / amber / red palette
  widgets/                  SensorCard, ProductCard, StatusBadge
  screens/                  The five screens above
```

## Run

```bash
flutter pub get
dart pub global activate flutterfire_cli
flutterfire configure        # creates lib/firebase_options.dart
flutter run                  # device / emulator
```

`firebase_options.dart` ships with placeholder values, so the app compiles and
opens but shows empty / offline states until `flutterfire configure` connects
a real project.

### Android APK

```bash
flutter build apk --release
# build/app/outputs/flutter-apk/app-release.apk
```

The Android manifest already allows cleartext HTTP (the ESP32-CAM serves plain
HTTP on the LAN).

## Camera

The ESP32-CAM IP is **not hard-coded**. Enter it on the **Camera** screen; the
app builds the stream/capture URLs and stores the IP in Firebase so the whole
team's apps share it. The phone must be on the **same Wi-Fi** as the camera to
view the live stream.

## Notes

- The app only does real network calls — it never fakes a camera stream.
- Sensor data is read live from Firebase; alerts are derived on the device.
