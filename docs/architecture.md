# Architecture

This document describes the full architecture of the **Zero Waste Smart Fridge**
system: hardware, cloud, data flow, and the risk-scoring algorithm.

---

## 1. Overview

The Smart Fridge monitors products stored in a transparent plastic box
(47 x 72.5 x 36.2 cm). It combines:

- **Environmental sensing** (ESP32 DevKit V1)
- **Visual capture** (ESP32-CAM AI Thinker)
- **Product identity** (QR codes scanned by the phone)
- **Cloud storage** (Firebase Realtime Database)
- **User interface** (Flutter mobile app)
- **Optional CV backend** (Python banana browning analysis)

The goal is to estimate a *relative* spoilage risk and warn the user early —
not to predict exact spoilage time.

---

## 2. Hardware components

### 2.1 ESP32 DevKit V1 — Sensor node (optional & independent)

| Responsibility | Detail |
|----------------|--------|
| Gas sensing | MQ135 analog output -> ESP32 ADC |
| Temp / humidity | DHT11 digital sensor |
| Weight | HX711 24-bit ADC with 4 load cells (optional) |
| Risk computation | Sensor-based partial risk score |
| Cloud upload | Pushes JSON (with an NTP timestamp) to Firebase |

The sensor node owns `/devices/fridge_01/sensors`. It is **optional**: it does
**not** trigger the camera and does **not** drive product registration. If it
is offline the rest of the system keeps working — the app sees a stale
`updatedAt` (older than 60 s) and shows *"ESP32 not connected"*. The HX711
itself is optional; without it the weight is reported as `0 g`.

### 2.2 ESP32-CAM AI Thinker — Camera node (independent)

| Responsibility | Detail |
|----------------|--------|
| Camera | OV2640, no SD card used |
| Web server | Standard `CameraWebServer` example |
| Endpoints | `/` (stream UI), `/capture` (single JPEG) |
| Cloud | Optionally writes its `streamUrl` / `captureUrl` to Firebase |

The camera node is **completely independent of the load cells** — it never
waits for a weight event. Its only jobs are (a) provide images so the app can
**read product QR codes**, and (b) provide images for **banana browning
analysis**.

**The camera node does NOT run QR decoding, AI inference, or image
processing.** It only serves images. All decoding/analysis happens in the
mobile app or the optional Python backend.

Known-working reference deployment:

- Stream UI: `http://172.19.15.112`
- Capture: `http://172.19.15.112/capture`

---

## 3. Cloud architecture

We use **Firebase Realtime Database** (RTDB), not Firestore. RTDB fits this
project because the data is a small, frequently-updated JSON tree and ESP32
libraries for RTDB are mature and lightweight.

### Database tree

```
/devices/fridge_01/sensors          <- written by the ESP32 DevKit
/devices/fridge_01/camera           <- written by the ESP32-CAM (or app)
/devices/fridge_01/products         <- written by app/backend (QR scan)
/devices/fridge_01/bananaAnalysis   <- written by app/backend (banana analysis)
/devices/fridge_01/alerts           <- written by app / backend
```

The full schema with example values lives in
[firebase-schema.json](firebase-schema.json).

### Who writes what

| Path | Writer | Reader |
|------|--------|--------|
| `sensors` | ESP32 DevKit | App, backend |
| `camera` | ESP32-CAM / app | App, backend |
| `products` | App / backend (QR scan) | App |
| `bananaAnalysis` | App / backend (banana analysis) | App |
| `alerts` | App, backend | App |

---

## 4. Product registration (QR, user-triggered)

Product registration is **user-triggered** — it is **not** driven by the load
cells. The load cells are just an optional sensor; placing something on them
does **not** register a product.

### Workflow

```
1. User taps "Scan QR from Camera" in the app.
2. The app captures a still image:
     - Hardware mode: GET the ESP32-CAM /capture URL.
     - Demo mode:      use a bundled sample QR image.
3. The app decodes the QR code from that image (on-device, pure Dart).
4. The QR JSON is parsed into product metadata.
5. The user confirms, and the product is saved under
   /devices/fridge_01/products/{productId}.
6. The app shows the product with its expiry status and warnings.
```

The QR payload is our own prepared product JSON:

```json
{
  "productId": "milk_001",
  "name": "Milk",
  "category": "Dairy",
  "expiryDate": "2026-05-25",
  "addedDate": "2026-05-18",
  "brand": "Example Brand",
  "expectedWeight": 1000
}
```

The **ESP32-CAM only serves the image**; QR decoding happens in the app (or
the Python backend), never on the camera. A phone-camera live scan is also
available as a backup.

### Expiry status

From `expiryDate` the app derives an expiry-based status shown on every
product:

| Remaining time | Status |
|----------------|--------|
| more than 3 days | `Fresh` |
| 3 days or less (and not expired) | `Expiring Soon` |
| past the expiry date | `Expired` |

When a product is `Expiring Soon` or `Expired` the app raises a warning.

---

## 4a. Device offline behavior

Every part of the system is independent, so a missing device does not break
the others:

- **ESP32 DevKit offline** — `/sensors/updatedAt` (a real NTP timestamp) goes
  stale. After 60 s the app marks the board offline and shows
  *"ESP32 not connected / sensor data unavailable"*. QR scanning, the camera
  and banana analysis all keep working.
- **ESP32-CAM offline / unreachable** — QR scan and banana analysis report a
  capture error; the user can retry or use Demo mode / the phone-camera scan.
- The app itself always runs: in **Demo mode** it uses bundled sample data and
  needs no hardware at all.

---

## 5. QR code product system

Every product has a QR sticker containing a JSON payload:

```json
{
  "productId": "milk_001",
  "name": "Milk",
  "category": "Dairy",
  "brand": "Example Brand",
  "expiryDate": "2026-05-25",
  "addedDate": "2026-05-17",
  "expectedWeight": 1000,
  "weightMin": 900,
  "weightMax": 1100,
  "storageType": "Cold"
}
```

QR is the **primary** identification method. Weight is **secondary** —
used only for verification and quantity tracking, never for identity.

See [../qr-samples/qr-generation-guide.md](../qr-samples/qr-generation-guide.md).

---

## 6. Banana browning analysis

Pixel-based image processing only — **no AI / ML**. It runs in the app (or the
Python backend) and is triggered by the user pressing **"Analyze Banana"**.

Steps:

1. Capture a still image (ESP32-CAM `/capture`, or a bundled sample image in
   Demo mode).
2. For every pixel, classify it with simple RGB / HSV thresholds:
   - **banana pixel** — yellow, brown or dark (not background),
   - **brown spot** — a brownish overripe pixel,
   - **dark spot** — a very dark / black pixel.
3. Compute three percentages relative to the banana pixels:

   ```
   brownSpotPercentage     = brownPixels / bananaPixels * 100
   darkSpotPercentage      = darkPixels  / bananaPixels * 100
   totalBrowningPercentage = brownSpotPercentage + darkSpotPercentage
   ```

4. Map `totalBrowningPercentage` to `visualStatus`:

| totalBrowningPercentage | visualStatus |
|-------------------------|--------------|
| `0 - 10 %` | Fresh |
| `10 - 25 %` | Slight Browning |
| `25 - 50 %` | Browning Detected |
| `>= 50 %` | Consume Soon |

5. Save the result under `/devices/fridge_01/bananaAnalysis/{productId}`:

```json
{
  "productId": "banana_001",
  "brownSpotPercentage": 18.4,
  "darkSpotPercentage": 6.2,
  "totalBrowningPercentage": 24.6,
  "visualStatus": "Slight Browning"
}
```

The app shows the latest banana image, the percentages, the visual status and
a warning — *"Banana browning detected. Consume soon."* — when browning is
significant. The same logic is also available in the Python backend
([../backend/optional-image-analysis-service](../backend/optional-image-analysis-service)).

---

## 7. Risk score logic

The system estimates **relative** spoilage risk:

```
riskScore = expiryRisk
          + temperatureRisk
          + humidityRisk
          + gasRisk
          + visualRisk
          + weightRisk
```

Result is clamped to `0..100`.

### Status bands

| Score | Status |
|-------|--------|
| 0 - 39 | Fresh |
| 40 - 69 | Consume Soon |
| 70 - 100 | Spoilage Risk |

### Component ranges and rules

| Component | Max | Driven by |
|-----------|-----|-----------|
| expiryRisk | 40 | hours remaining to expiry |
| temperatureRisk | 20 | deviation from ideal cold range (2-6 C) |
| humidityRisk | 15 | deviation from ideal humidity (50-80 %) |
| gasRisk | 25 | MQ135 raw analog reading |
| visualRisk | 25 | browningRatio (fruit only) |
| weightRisk | 15 | deviation from expected weight range |

**expiryRisk** (hours remaining):

| Hours | Risk |
|-------|------|
| `<= 0` | 40 |
| `<= 12` | 34 |
| `<= 24` | 26 |
| `<= 48` | 16 |
| `<= 72` | 9 |
| `<= 120` | 4 |
| `> 120` | 0 |

**temperatureRisk**: `0` inside 2-6 C; `+4` per C outside, capped at 20.

**humidityRisk**: `0` inside 50-80 %; `+1` per % outside, capped at 15.

**gasRisk** (MQ135 raw 12-bit ADC value):

| Reading | Risk |
|---------|------|
| `< 1000` | 0 |
| `< 1500` | 9 |
| `< 2000` | 16 |
| `< 2500` | 21 |
| `>= 2500` | 25 |

**visualRisk**:

| browningRatio | Risk |
|---------------|------|
| `< 0.10` | 0 |
| `< 0.25` | 9 |
| `< 0.45` | 16 |
| `< 0.65` | 21 |
| `>= 0.65` | 25 |

**weightRisk**: `0` if current weight is inside `[weightMin, weightMax]`;
otherwise scaled by how far outside, capped at 15. A large unexpected drop or
rise can indicate leakage, spillage, or tampering.

### Category-specific composition

Not every component applies to every category:

| Category | Components used |
|----------|-----------------|
| Fruit / Vegetable | expiry + temperature + humidity + gas + visual |
| Dairy | expiry + temperature + weight |
| Egg | expiry + temperature + weight |
| Packaged Food | expiry + temperature + weight |

The **global risk score** shown on the dashboard is the maximum per-product
risk score (the worst item drives the headline status), while the dashboard
also shows raw sensor values.

The canonical implementation is
[`mobile/smart_fridge_app/lib/services/risk_service.dart`](../mobile/smart_fridge_app/lib/services/risk_service.dart).
The ESP32 firmware computes a simplified *sensor-only* score as a fallback.

---

## 8. Security model

- No real credentials in the repository.
- Firmware: `secrets.h` (git-ignored) created from `secrets.example.h`.
- Mobile: `firebase_options.dart` generated by `flutterfire configure`
  (git-ignored); a `.example` template is provided.
- Backend: configuration via environment variables / `.env` (git-ignored),
  with `.env.example` committed.
- For the demo, tighten Firebase rules so only `/devices/fridge_01` is
  readable/writable.
