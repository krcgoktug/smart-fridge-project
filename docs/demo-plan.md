# Demo Plan

A script for presenting the Zero Waste Smart Fridge. Target: **8-10 minutes**.

---

## 0. Before the demo

- [ ] ESP32 DevKit + ESP32-CAM powered, on the same Wi-Fi as the laptop/phone.
- [ ] Firebase Realtime Database reachable.
- [ ] Image analysis service running (`python app.py`) on the laptop.
- [ ] App running as the **Android app** on a phone (or `flutter run` locally),
      with the ESP32-CAM IP set in **Settings**.
- [ ] A few products with printed QR stickers.
- [ ] One slightly-browned banana.

> The phone / laptop running the app must be on the **same Wi-Fi** as the
> ESP32-CAM for the live stream — see [camera-limitations.md](camera-limitations.md).

---

## 1. Introduction (1 min)

Explain the problem (forgotten food is wasted) and the four-layer
architecture: ESP32 sensors, ESP32-CAM, the Python image analysis service,
and the Flutter app. Show the box with the two ESP32 boards.

## 2. Sensors + offline behavior (2 min)

1. Open the **Dashboard** — show the **ESP32 Online** card and the live
   weight / temperature / gas values updating every 10 s.
2. Power off the ESP32 DevKit — after ~60 s the card flips to **ESP32
   Offline** and an alert appears. Stress that the camera and service keep
   working. Power it back on.

## 3. QR product registration (2 min)

1. Hold a product QR sticker in front of the ESP32-CAM.
2. The **image analysis service** decodes it (OpenCV + pyzbar) and writes the
   product to Firebase — point at the service console log.
3. Open the **Products** screen — the product appears on its own with its
   category, expiry date and status (Fresh / Expiring Soon / Expired). No
   manual entry was used.

## 4. Banana browning analysis (2 min)

1. Place the browned banana in front of the ESP32-CAM.
2. The service runs the HSV pixel analysis each cycle and writes
   `brownPercent`, `visualStatus` and `status` to Firebase.
3. On the **Dashboard**, show the banana card: the browning percentage and
   the status — Fresh / Slight Browning / Browning Detected / Spoilage Risk.

## 5. Live camera + alerts (1-2 min)

1. Open the **Camera** screen — show the live MJPEG stream from the ESP32-CAM
   and the camera online status.
2. Open the **Alerts** screen — show the alerts the service published to
   Firebase (expiring products, offline board, banana spoilage).

## 6. Wrap-up (1 min)

- Recap: real sensors, a real camera, real computer vision (QR + HSV), a real
  cloud database, and a clean read-only app — no fake AI.

---

## Notes / fallback

- The live camera needs the **Android app or a local run** on the same Wi-Fi;
  a hosted HTTPS web build cannot show the HTTP camera stream
  ([camera-limitations.md](camera-limitations.md)).
- No hardware? Import [demo-seed.json](demo-seed.json) at the Realtime
  Database root to populate the app for a UI walkthrough.
- Keep a screen recording of a successful run as a last-resort backup.
