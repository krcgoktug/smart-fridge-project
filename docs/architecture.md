# Architecture

Zero Waste Smart Fridge — a real-time IoT + computer-vision pipeline.

The design has four independent layers. Each does one job; nothing fakes a
capability it does not have.

| Layer | Hardware / software | Responsibility |
|-------|---------------------|----------------|
| Sensing | ESP32 DevKit V1 | Read sensors, push a heartbeat |
| Vision input | ESP32-CAM AI-Thinker | Serve an MJPEG stream + snapshots |
| Processing | Image analysis service (Python) | QR decoding + banana analysis + alerts |
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
        │  DHT11  -> temp+hum  │         │  HTTP server:         │
        │  MQ135  -> gas       │         │   /  /stream /capture │
        └──────────┬───────────┘         └───────────┬──────────┘
                   │                                 │
        sensors heartbeat                   MJPEG / JPEG frames
        every 10 s                          (HTTP, local network)
                   │                                 │
                   v                                 v
        ┌──────────────────────┐         ┌──────────────────────┐
        │  Firebase Realtime   │ <────── │ Image analysis svc   │
        │  Database            │  writes │  (Python, OpenCV)    │
        │                      │ camera  │                      │
        │  /sensors            │ products│  - pull /capture     │
        │  /camera             │ banana  │  - QR (OpenCV+pyzbar)│
        │  /products           │ alerts  │  - banana CV (HSV)   │
        │  /bananaAnalysis     │         │  - build alerts      │
        │  /alerts             │         │                      │
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

 ESP32-CAM ──(/capture)──> Image analysis service loop:
                            ├─ decode QR    ──> Firebase /products
                            ├─ HSV banana   ──> Firebase /bananaAnalysis
                            ├─ camera status──> Firebase /camera
                            └─ build alerts ──> Firebase /alerts
                                                       │
                                                       v
                                                  Flutter app

 ESP32-CAM ──(/stream MJPEG)──────────────────────────> App Camera screen
                                                        (Android / local run)
```

---

## 3. ESP32 DevKit V1 — Sensor node

- Reads HX711 (weight), DHT11 (temperature) and MQ135 (gas).
- Every **10 seconds** pushes a heartbeat to `devices/fridge_01/sensors`:

  ```json
  { "weight": 482, "temperature": 5.8, "humidity": 47, "gas": 1350,
    "updatedAt": 1710000000, "alive": true }
  ```

- `updatedAt` is a real Unix time (NTP). If no update arrives for **> 60 s**
  the Flutter app shows **"ESP32 Offline"**.
- The load cells are used for **quantity / weight verification and
  spoilage-risk contribution only** — they are *not* the product
  identification method (that is QR; see [qr-system.md](qr-system.md)).
- It does **no** camera or QR work. The rest of the system runs without it.

Firmware: [`firmware/esp32-devkit`](../firmware/esp32-devkit).

## 4. ESP32-CAM AI-Thinker — Camera node

- Always-on camera HTTP server, three endpoints:
  - `GET /` — HTML page with the stream,
  - `GET /stream` — continuous multipart MJPEG stream,
  - `GET /capture` — a single JPEG frame.
- **No** QR decoding, **no** AI, **no** Firebase — it only serves frames.

Firmware: [`firmware/esp32-cam`](../firmware/esp32-cam).

## 5. Image analysis service — Processing layer

The Python service is the processing layer. It runs a continuous loop and per
cycle:

1. Pulls a snapshot from the ESP32-CAM `/capture` endpoint.
2. **QR detection** — decodes QR codes with **OpenCV + pyzbar**, parses the
   JSON payload, and registers the product in Firebase.
3. **Banana analysis** — pixel-based HSV thresholding (no ML), writes the
   browning result to Firebase.
4. **Camera status** — publishes whether the camera was reachable.
5. **Alerts** — recomputes the alert list from sensor, product and banana
   data and writes it to Firebase.

Code: [`backend/image-analysis-service`](../backend/image-analysis-service).

### QR system

Each product carries our own printed QR sticker:

```json
{ "productId": "banana_001", "name": "Banana",
  "expiryDate": "2026-05-25", "category": "Fruit" }
```

The service writes to `devices/fridge_01/products/<productId>`. Full pipeline:
[qr-system.md](qr-system.md).

### Banana analysis

The frame is converted to HSV; healthy yellow flesh, brown overripe regions
and dark spots are isolated with colour thresholds:

```
brownPercent = (brown pixels + dark pixels) / banana region pixels * 100
```

| brownPercent | visualStatus | status |
|--------------|-------------------|----------------|
| `0 – 15 %`   | Fresh             | Good           |
| `15 – 35 %`  | Slight Browning   | Monitor        |
| `35 – 60 %`  | Browning Detected | Consume Soon   |
| `60 %+`      | Spoilage Risk     | Do Not Consume |

Full method: [banana-analysis.md](banana-analysis.md).

---

## 6. Cloud — Firebase Realtime Database

RTDB is the message bus. Full layout: [firebase-schema.md](firebase-schema.md).

```
/devices/fridge_01/sensors          <- ESP32 DevKit
/devices/fridge_01/camera           <- image analysis service
/devices/fridge_01/products         <- image analysis service (QR)
/devices/fridge_01/bananaAnalysis   <- image analysis service (banana CV)
/devices/fridge_01/alerts           <- image analysis service
```

---

## 7. Flutter app — Visualization layer

The app is **read-only**. It never writes to Firebase and does no image
processing. Screens:

- **Dashboard** — ESP32 online/offline, live sensors, banana analysis, alerts.
- **Products** — QR-detected products with expiry status.
- **Camera** — live ESP32-CAM MJPEG stream + camera online status.
- **Alerts** — the `alerts` node from Firebase.
- **Settings** — ESP32-CAM IP, Firebase status.

App: [`mobile/smart_fridge_app`](../mobile/smart_fridge_app).

### Offline behavior

- **ESP32 DevKit offline** → `sensors.updatedAt` goes stale → after 60 s the
  app shows "ESP32 Offline"; products, camera and banana data still display.
- **ESP32-CAM offline** → the service marks `camera.online = false` and the
  camera screen shows a reach error.
- **Service not running** → `products` / `bananaAnalysis` / `alerts` simply
  stop updating.

Because the layers are independent, a missing component degrades the system
gracefully rather than breaking it.

### Camera limitation

The ESP32-CAM is a plain **HTTP** device on the local network. A web build
served over HTTPS cannot display its stream (browser mixed-content policy).
The real stream needs the **Android app** or a **local run** on the same
Wi-Fi. This is documented honestly in [camera-limitations.md](camera-limitations.md)
and surfaced inside the app — there are no faked camera previews.
