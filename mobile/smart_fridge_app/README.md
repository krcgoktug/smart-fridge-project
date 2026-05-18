# Smart Fridge — Flutter App

The **visualization layer** of the Zero Waste Smart Fridge. It is a
**read-only** dashboard: it reads Firebase Realtime Database and displays the
ESP32-CAM stream. It does **no** writing, **no** QR decoding and **no** image
processing — the ESP32 boards and the image analysis service do that.

## Screens

| Screen | Shows |
|--------|-------|
| Dashboard | ESP32 online/offline, live sensors, banana analysis, alerts |
| Products | QR-detected products with category and expiry status |
| Camera | Live ESP32-CAM MJPEG stream + camera online status |
| Alerts | Alerts read from Firebase (published by the analysis service) |
| Settings | ESP32-CAM IP, Firebase status, camera note |

## Project layout

```
lib/
  main.dart                  App entry + bottom navigation
  app_config.dart            Device id / database root
  firebase_options.dart      PLACEHOLDER config (replace via flutterfire)
  models/                    SensorData, CameraStatus, Product,
                             BananaAnalysis, Alert
  services/
    firebase_service.dart    Read-only Realtime Database streams
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

## Running the app (Windows)

All commands are run from this folder in **PowerShell**:

```powershell
cd C:\Users\HUAWEI\smart-fridge-project\mobile\smart_fridge_app
flutter pub get
```

Verify your toolchain once with `flutter doctor`. Check connected targets any
time with `flutter devices`. Run the unit tests with `flutter test`.

### 1. Local Chrome run

```powershell
flutter run -d chrome
```

Serves the app at `http://localhost:<port>`. Because localhost is **HTTP**
(not HTTPS) there is no mixed-content block, so the live ESP32-CAM stream
**works here** as long as this PC is on the same Wi-Fi as the camera. Press
`r` to hot-reload, `q` to quit.

### 2. Android phone run

1. On the phone: enable **Developer options → USB debugging**.
2. Connect the phone by USB and accept the debugging prompt.
3. Find and run it:

```powershell
flutter devices
flutter run -d <device-id-from-the-list>
```

If the phone is the only target, `flutter run` is enough. This installs a
debug build and live-reloads while connected.

### 3. APK build

```powershell
flutter build apk --release
```

Output: `build\app\outputs\flutter-apk\app-release.apk`. Install it on a
phone with either:

```powershell
flutter install -d <device-id>
# or
adb install build\app\outputs\flutter-apk\app-release.apk
```

The installed app runs without a USB cable — copy the APK to the phone and
open it, or use the commands above.

### 4. Hardware mode (live ESP32-CAM)

"Hardware mode" is not a separate command — it is any of the runs above with
the device on the **same Wi-Fi as the ESP32-CAM**:

1. Power the ESP32-CAM and read its IP from the Arduino Serial Monitor
   (e.g. `192.168.1.50`).
2. Make sure the phone / PC running the app is on that **same Wi-Fi network**.
3. Run the app — use the **Android app** (step 2 or 3) or the **local Chrome
   run** (step 1). A web build hosted over HTTPS will *not* show the camera.
4. In the app: **Settings → ESP32-CAM address** → enter `http://<cam-ip>`
   (e.g. `http://192.168.1.50`) and save.
5. Open the **Camera** screen — the live MJPEG stream appears, and the
   image analysis service should also be running so products, banana
   analysis and alerts update.

> A web build served over **HTTPS** (any hosted page) cannot show the live
> camera: browsers block the ESP32-CAM's HTTP stream as mixed content. It can
> still show sensors, products, banana analysis and alerts from Firebase. See
> [docs/camera-limitations.md](../../docs/camera-limitations.md).

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
