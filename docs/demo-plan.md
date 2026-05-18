# Demo Plan

A script for presenting the Zero Waste Smart Fridge. Target: **8-10 minutes**.

---

## 0. Before the demo

- [ ] ESP32 DevKit + ESP32-CAM powered, on the same Wi-Fi as the laptop/phone.
- [ ] Firebase Realtime Database reachable.
- [ ] Python backend running (`python app.py`) on the laptop.
- [ ] Android app installed on the phone (or `flutter run` locally), with the
      ESP32-CAM IP set in **Settings**.
- [ ] A few products with printed QR stickers.
- [ ] One slightly-browned banana.

---

## 1. Introduction (1 min)

Explain the problem (forgotten food is wasted) and the four-layer
architecture: ESP32 sensors, ESP32-CAM, Python CV backend, Flutter app.
Show the box with the two ESP32 boards.

## 2. Sensors + offline behavior (2 min)

1. Open the **Dashboard** — show the **ESP32 Online** card and the live
   weight / temperature / gas values updating every 10 s.
2. Power off the ESP32 DevKit — after ~60 s the card flips to **ESP32
   Offline** and an alert appears. Stress that the camera and backend keep
   working. Power it back on.

## 3. QR product registration (2 min)

1. Hold a product QR code in front of the ESP32-CAM.
2. The **backend** decodes it (OpenCV + pyzbar) and writes the product to
   Firebase — point at the backend console log.
3. Open the **Products** screen — the product appears on its own with its
   expiry date and status (Fresh / Expiring Soon / Expired).

## 4. Banana browning analysis (2 min)

1. Place the browned banana in front of the ESP32-CAM.
2. The backend runs the HSV pixel analysis each cycle and writes
   `brownPercent` + `status` to Firebase.
3. On the **Dashboard**, show the banana card: the browning percentage and
   the status (Fresh / Warning / Rotten) with a warning message.

## 5. Live camera + alerts (1-2 min)

1. Open the **Camera** screen — show the live MJPEG stream from the ESP32-CAM.
2. Open the **Alerts** screen — show alerts derived from the data (expiring
   products, offline board, rotten banana).

## 6. Wrap-up (1 min)

- Recap: real sensors, a real camera, real computer vision (QR + HSV), a real
  cloud database, and a clean read-only app — no fake AI.
- Mention the GitHub Pages UI demo and the Android APK in CI.

---

## Notes / fallback

- The deployed GitHub Pages site is **UI only** — the live camera needs the
  Android app or a local run (HTTPS blocks the HTTP camera stream).
- No hardware? Import [demo-seed.json](demo-seed.json) at the Realtime
  Database root to populate the app for a UI walkthrough.
- Keep a screen recording of a successful run as a last-resort backup.
