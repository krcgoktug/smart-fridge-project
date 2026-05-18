# Demo Plan

A short script for presenting the Zero Waste Smart Fridge. ~8 minutes.

## Before the demo

- [ ] ESP32 DevKit powered and uploading (Serial Monitor shows uploads).
- [ ] ESP32-CAM powered; note its IP from the Serial Monitor.
- [ ] Phone running the app, on the **same Wi-Fi** as the ESP32-CAM.
- [ ] Camera IP entered and saved in the app's Camera screen.
- [ ] A few products with printed QR stickers.

## 1. Introduction (1 min)

Two ESP32 devices: the **DevKit** reads sensors, the **CAM** is the camera.
Firebase connects them to the app. Show the box and the two boards.

## 2. Sensors + offline (2 min)

1. Open the **Dashboard** — show live temperature, humidity, gas and weight,
   and the **ESP32 Online** card.
2. Explain that this data is in Firebase, so every team member sees it live.
3. Power off the DevKit — after ~60 s the card turns to **ESP32 Sensor Board
   Offline** and an alert appears. Power it back on.

## 3. Camera (1-2 min)

1. Open the **Camera** screen — the live ESP32-CAM stream is shown.
2. Tap **Test** — it shows **Camera Online**.
3. Mention honestly: the stream is local-network only — the phone must be on
   the same Wi-Fi as the camera.

## 4. QR product registration (2 min)

1. Hold a product QR sticker in front of the ESP32-CAM.
2. Tap **Scan QR** — the app captures a frame, decodes the QR code, and writes
   the product to Firebase.
3. Open the **Products** screen — the product appears with its category,
   expiry date, remaining days and a status color.

## 5. Alerts (1 min)

Open the **Alerts** screen — show expiry warnings and any ESP32 / camera
offline warnings.

## 6. Wrap-up (1 min)

Recap: real sensors, a real camera stream, real QR registration, real Firebase
— a simple, honest IoT project.

## Fallback

- No camera on the network? The sensors, products and alerts still work
  through Firebase. Explain the camera is local-network only.
- Keep a screen recording of a working run as a backup.
