# Architecture

Zero Waste Smart Fridge — a real-time IoT + computer-vision pipeline.

The design has four independent layers. Each does one job; nothing fakes a
capability it does not have.

| Layer | Hardware / software | Responsibility |
|-------|---------------------|----------------|
| Sensing | ESP32 DevKit V1 | Read sensors, push a heartbeat |
| Vision input | ESP32-CAM AI-Thinker | Serve an MJPEG stream + snapshots |
| Processing | Python backend | QR decoding + banana analysis (computer vision) |
| Visualization | Flutter app | Read Firebase, display everything |
| Cloud | Firebase Realtime Database | Message bus between the layers |

---

## 1. System diagram

```
        ┌──────────────────────┐         ┌──────────────────────┐
        │   ESP32 DevKit V1    │         │  ESP32-CAM AI-Thinker │
        │   (sensor node)      │         │  (camera node)        │
        │                      │         │                      │
        │  HX711  -> weight    │         │  OV2640 camera        │
        │  DHT11  -> temp      │         │  HTTP server:         │
        │  MQ135  -> gas       │         │   /  /stream /capture │
        └──────────┬───────────┘         └───────────┬──────────┘
                   │                                 │
        sensors heartbeat                   MJPEG / JPEG frames
        every 10 s (HTTPS)                  (HTTP, local network)
                   │                                 │
                   v                                 v
        ┌──────────────────────┐         ┌──────────────────────┐
        │  Firebase Realtime   │ <────── │   Python backend     │
        │  Database            │  writes │  (processing engine) │
        │                      │ products│                      │
        │  /sensors            │ banana  │  - pull /capture     │
        │  /products           │ Analysis│  - QR (OpenCV+pyzbar)│
        │  /bananaAnalysis     │         │  - banana CV (HSV)   │
        └──────────┬───────────┘         └──────────────────────┘
                   │
            reads (real-time)
                   │
                   v
        ┌──────────────────────┐
        │   Flutter app        │  Dashboard / Products / Camera /
        │   (visualization)    │  Alerts / Settings
        │   READ-ONLY          │  + live MJPEG stream from the camera
        └──────────────────────┘
```

## 2. Data-flow diagram

```
 ESP32 DevKit ──(every 10s)──> Firebase /sensors ──> App dashboard
                                                     App: "ESP32 Offline"
                                                     if updatedAt > 60s old

 ESP32-CAM ──(MJPEG)──> Python backend loop:
                          ├─ decode QR  ──> Firebase /products ──> App
                          └─ HSV banana ──> Firebase /bananaAnalysis ──> App

 ESP32-CAM ──(MJPEG /stream)──────────────────────────> App Camera screen
                                                        (Android / local run)
```

---

## 3. ESP32 DevKit V1 — Sensor node

- Reads HX711 (weight), DHT11 (temperature) and MQ135 (gas).
- Every **10 seconds** pushes a heartbeat to `devices/fridge_01/sensors`:

  ```json
  { "weight": 482, "temperature": 5.8, "gas": 1350,
    "updatedAt": 1710000000, "alive": true }
  ```

- `updatedAt` is a real Unix time (NTP). If no update arrives for **> 60 s**
  the Flutter app shows **"ESP32 Offline"**.
- It does **no** camera or QR work. The rest of the system runs without it.

Firmware: [`firmware/esp32-devkit-sensors`](../firmware/esp32-devkit-sensors).

## 4. ESP32-CAM AI-Thinker — Camera node

- Always-on camera HTTP server, three endpoints:
  - `GET /` — HTML page with the stream,
  - `GET /stream` — continuous multipart MJPEG stream,
  - `GET /capture` — a single JPEG frame.
- **No** QR decoding, **no** AI, **no** Firebase — it only serves frames.

Firmware: [`firmware/esp32-cam-camera`](../firmware/esp32-cam-camera).

## 5. Python backend — Processing engine

The backend is the intelligent layer. It runs a continuous loop and per cycle:

1. Pulls a snapshot from the ESP32-CAM `/capture` endpoint.
2. **QR detection** — decodes QR codes with **OpenCV + pyzbar**, parses the
   JSON payload, and registers the product in Firebase.
3. **Banana analysis** — real pixel-based HSV thresholding (no ML), writes the
   browning result to Firebase.

Code: [`backend/processing-engine`](../backend/processing-engine).

### QR system

Each product carries our own printed QR code with this payload:

```json
{ "product": "Milk", "expiry": "2026-05-25" }
```

The backend writes to `devices/fridge_01/products/<slug>`:

```json
{ "productName": "Milk", "expiryDate": "2026-05-25",
  "detectedAt": 1710000000, "source": "qr" }
```

### Banana analysis

The frame is converted to HSV. Healthy **yellow** banana flesh, **brown**
overripe regions and **dark** spots are isolated with colour thresholds:

```
brownPercent = (brown pixels + dark pixels) / banana region pixels * 100
```

| brownPercent | status |
|--------------|--------|
| `0 - 15 %`   | Fresh  |
| `15 - 35 %`  | Warning|
| `35 %+`      | Rotten |

Result written to `devices/fridge_01/bananaAnalysis`:

```json
{ "brownPercent": 18.4, "status": "Warning", "analyzedAt": 1710000000 }
```

---

## 6. Cloud — Firebase Realtime Database

RTDB is the message bus. Full layout: [firebase-schema.json](firebase-schema.json).

```
/devices/fridge_01/sensors          <- ESP32 DevKit
/devices/fridge_01/products         <- Python backend (QR)
/devices/fridge_01/bananaAnalysis   <- Python backend (banana CV)
```

| Path | Writer | Reader |
|------|--------|--------|
| `sensors` | ESP32 DevKit | App |
| `products` | Python backend | App |
| `bananaAnalysis` | Python backend | App |

---

## 7. Flutter app — Visualization layer

The app is **read-only**. It never writes to Firebase and does no image
processing. Screens:

- **Dashboard** — ESP32 online/offline, live sensors, banana analysis, alerts.
- **Products** — QR-detected products with expiry status.
- **Camera** — live ESP32-CAM MJPEG stream.
- **Alerts** — derived on-device from the data (expiring products, offline
  board, rotten banana).
- **Settings** — ESP32-CAM IP, Firebase status.

App: [`mobile/smart_fridge_app`](../mobile/smart_fridge_app).

### Offline behavior

- **ESP32 DevKit offline** → `sensors.updatedAt` goes stale → after 60 s the
  app shows "ESP32 Offline"; products, camera and banana data still display.
- **ESP32-CAM offline** → the camera screen shows a reach error.
- **Backend not running** → `products` / `bananaAnalysis` simply stop updating.

### GitHub Pages camera limitation

The deployed web app is served over **HTTPS**, but the ESP32-CAM is a plain
**HTTP** device on the local network. Browsers block mixed content, so the
**live camera stream does not work on the GitHub Pages URL**. The Pages site
is a **UI demo only**.

**Hardware Mode** (real camera + real data) requires the **Android app** or a
**local `flutter run`** on the same Wi-Fi network. The repository ships an
Android APK build workflow for this — see the README.
