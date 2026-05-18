# Architecture

Zero Waste Smart Fridge — a simple, real IoT + mobile project. Two ESP32
devices, Firebase, and a Flutter app. No backend, no AI.

---

## 1. Overview

```
   ┌─────────────────────┐            ┌─────────────────────┐
   │   ESP32 DevKit      │            │   ESP32-CAM         │
   │   (sensors)         │            │   (camera)          │
   │                     │            │                     │
   │  MQ135  gas         │            │  OV2640 camera      │
   │  DHT11  temp + hum  │            │  CameraWebServer    │
   │  HX711  weight      │            │  / /stream /capture │
   └──────────┬──────────┘            └──────────┬──────────┘
              │                                  │
   sensor values over Wi-Fi             local-network MJPEG
   (cloud, every ~5 s)                  + /capture (HTTP)
              │                                  │
              v                                  │
   ┌─────────────────────────────┐               │
   │  Firebase Realtime Database │               │
   │  devices/fridge_01/         │               │
   │    sensors                  │               │
   │    camera                   │               │
   │    products                 │               │
   └──────────────┬──────────────┘               │
                  │                              │
            reads / writes                  live stream
                  │                              │
                  v                              v
   ┌──────────────────────────────────────────────────────┐
   │              Flutter app  (5 screens)                 │
   │   Dashboard · Camera · Products · Alerts · Settings    │
   └──────────────────────────────────────────────────────┘
```

## 2. ESP32 DevKit — sensor controller

- Sensors: **MQ135** (gas), **DHT11** (temperature + humidity),
  **HX711 + load cells** (weight).
- Every ~5 seconds it uploads to `devices/fridge_01/sensors`:

  ```json
  { "temperature": 6.4, "humidity": 73, "gasValue": 1350,
    "weight": 482, "updatedAt": 1710000000 }
  ```

- `updatedAt` is a real Unix time (NTP). If the app sees no update for
  **60 seconds** it shows **"ESP32 Sensor Board Offline"**.

## 3. ESP32-CAM — camera

- Runs **CameraWebServer** continuously and exposes:
  - `/` — HTML page with the live stream,
  - `/stream` — continuous MJPEG stream,
  - `/capture` — a single JPEG frame.
- Each ESP32-CAM gets its **own local IP** from the Wi-Fi router
  (e.g. `172.19.15.112`, `192.168.1.44`). The IP is **never hard-coded** —
  it is entered in the app's Camera screen.
- The camera does **no** QR decoding and does **not** use Firebase.

## 4. Product flow (QR registration)

```
1. The ESP32-CAM continuously watches the products in the box.
2. In the app's Camera screen the user taps "Scan QR".
3. The app fetches a frame from  http://<camera-ip>/capture .
4. The app decodes the QR code (zxing2, on-device).
5. The product JSON is written to devices/fridge_01/products/<productId>.
6. The product appears automatically in the Products screen.
7. An expiry warning is computed from expiryDate.
```

There is **no manual product entry** — products come only from QR codes.

QR sticker payload:

```json
{
  "productId": "milk_001",
  "name": "Milk",
  "category": "Dairy",
  "expiryDate": "2026-05-25",
  "addedDate": "2026-05-18"
}
```

Expiry status: **Fresh** (> 3 days), **Expiring Soon** (≤ 3 days),
**Expired** (past the date).

## 5. Firebase Realtime Database

```
devices/fridge_01/sensors    <- ESP32 DevKit writes
devices/fridge_01/camera     <- the app writes (shared camera IP)
devices/fridge_01/products   <- the app writes (QR scans)
```

Full layout: [firebase-schema.json](firebase-schema.json).

**Alerts** are not stored — the app derives them live from the sensors,
products and camera state (expiry warnings, ESP32 offline, camera offline).

## 6. Network — important and honest

- **Sensor data is cloud-based.** The ESP32 DevKit uploads to Firebase over
  Wi-Fi, so **every team member sees** temperature, humidity, gas, weight,
  products and alerts **live**, from anywhere — even though the ESP32 is
  plugged into only one PC by USB.
- **The ESP32-CAM stream is local-network only.** `http://<camera-ip>/stream`
  can be opened **only** by a device on the **same Wi-Fi** as the camera.
  The app says so honestly and never fakes a working stream.

## 7. Flutter app — five screens

| Screen | Shows |
|--------|-------|
| Dashboard | temperature, humidity, gas, weight, ESP32 status, latest products, alerts, small live camera preview |
| Camera | camera IP input, test connection, live stream, capture, QR scan |
| Products | product cards — category, expiry date, remaining days, status color |
| Alerts | expiry warnings, ESP32 offline, camera offline |
| Settings | Firebase info, camera IP, hardware-mode notes |
