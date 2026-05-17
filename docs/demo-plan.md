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

## 2. Sensor node live data (2 min)

1. Open the **Dashboard** screen.
2. Point out live temperature, humidity, gas value and total weight.
3. Briefly breathe near the MQ135 or open an over-ripe item — watch the gas
   value rise and the global risk score react.
4. Add an item to the box — show the total weight change on the dashboard.

## 3. QR product registration (2 min)

1. Open **Add Product / QR Scan**.
2. Scan the banana QR sticker.
3. Show the parsed JSON fields, confirm, and save.
4. Switch to **Product List** — the banana now appears with category, expiry
   date, remaining time and a colored status badge.

## 4. Camera + banana browning (2 min)

1. Open **Camera View** — show the live ESP32-CAM stream of the box interior.
2. Place the browned banana in front of the camera.
3. Trigger an analysis (app button or backend run).
4. Open the banana's **Product Detail** — show `browningRatio` and
   `visualStatus` updating to "Browning Detected".
5. Note the per-product risk score going up.

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
- If a sensor board is offline: the app still works against Firebase — manually
  seed `/sensors` with sample values from `docs/firebase-schema.json`.
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
