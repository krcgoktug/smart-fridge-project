# Demo Plan

A step-by-step script for presenting the Zero Waste Smart Fridge in class.
Target duration: **8-10 minutes**.

---

## 0. Before the demo (setup checklist)

- [ ] Both ESP32 boards powered and connected to the same Wi-Fi as the phone.
- [ ] Firebase Realtime Database reachable; rules allow read/write for the demo.
- [ ] Mobile app installed on the phone, `flutterfire configure` already run.
- [ ] At least 3 products with printed QR stickers ready (e.g. banana, milk,
      egg box).
- [ ] One **slightly browned banana** prepared for the visual detection part.
- [ ] ESP32-CAM stream URL confirmed working in a browser.
- [ ] Optional Python backend running (for live browning analysis).

---

## 1. Introduction (1 min)

Explain the problem: households throw away food because they forget about it.
The Smart Fridge watches the products and warns the user early.

Show the physical box (47 x 72.5 x 36.2 cm) with the two ESP32 boards.

## 2. Sensor node + offline behavior (2 min)

1. Open the **Dashboard** screen.
2. Point out the **ESP32 Sensor Status** card and live temperature, humidity,
   gas value and weight.
3. Briefly breathe near the MQ135 or open an over-ripe item — watch the gas
   value rise and the global risk score react.
4. (Optional) Power off the ESP32 DevKit — after ~60 s the card flips to
   *"ESP32 not connected"*. Stress that QR scanning and the camera still work.

## 3. QR product registration (2 min)

1. Open the **Camera** screen.
2. Tap **"Scan QR from Camera"** — the app captures an image from the
   ESP32-CAM and decodes the product QR code.
3. Show the parsed product (name, category, expiry date), confirm, and save.
4. Switch to **Products** — the product appears with its expiry date,
   remaining days/hours and an expiry status (`Fresh` / `Expiring Soon` /
   `Expired`).

> Demo without hardware: in **Demo mode** the same button uses a bundled
> sample QR image, so the whole decode-and-register flow still runs.

## 4. Banana browning analysis (2 min)

1. On the **Camera** screen tap **"Analyze Banana"** (or open the
   **Banana Analysis** screen).
2. The app captures an image and runs pixel-based browning analysis.
3. Show the result: `brownSpotPercentage`, `darkSpotPercentage`,
   `totalBrowningPercentage` and the `visualStatus`.
4. Point out the warning — *"Banana browning detected. Consume soon."* — when
   browning is significant.

> Demo without hardware: Demo mode analyzes a bundled sample banana image.

## 5. Risk score + alerts (1-2 min)

1. Back on the **Dashboard**, show the global status moving from `Fresh` to
   `Consume Soon` / `Spoilage Risk`.
2. Open the **Alerts** screen — show the generated expiry / spoilage alerts.
3. Explain the risk formula briefly (expiry + temperature + humidity + gas +
   visual + weight), and that it is a *relative* estimate.

## 6. Wrap-up (1 min)

- Summarize: sensors + camera + QR + cloud + app working together.
- Mention possible extensions: more cameras, push notifications, ML model.

---

## Fallback plan (if hardware/Wi-Fi fails)

- Use a **second phone or browser** as a hotspot so all devices share a network.
- If a sensor board is offline: the app still works against Firebase — import
  `docs/demo-seed.json` at the database root (Realtime Database -> three-dot
  menu -> Import JSON) to populate sensors, camera, products and alerts.
- If the camera is offline: use a pre-captured banana image with the Python
  backend in file mode.
- Keep screen recordings of a successful run as a last-resort backup.

---

## Roles (for a team demo)

| Role | Task |
|------|------|
| Presenter | Talks through the script |
| App driver | Operates the phone |
| Hardware helper | Handles products, box, sensors |
