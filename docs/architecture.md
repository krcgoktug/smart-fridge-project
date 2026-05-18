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

### 2.1 ESP32 DevKit V1 — Sensor node

| Responsibility | Detail |
|----------------|--------|
| Gas sensing | MQ135 analog output -> ESP32 ADC |
| Temp / humidity | DHT11 digital sensor |
| Weight | HX711 24-bit ADC with 4 load cells (Wheatstone bridge) |
| Risk computation | Sensor-based partial risk score |
| Weight-change detection | Detects products added/removed |
| Cloud upload | Pushes JSON to Firebase Realtime Database |

The sensor node owns `/devices/fridge_01/sensors`.

### 2.2 ESP32-CAM AI Thinker — Camera node

| Responsibility | Detail |
|----------------|--------|
| Camera | OV2640, no SD card used |
| Web server | Standard `CameraWebServer` example |
| Endpoints | `/` (stream UI), `/capture` (single JPEG) |
| Cloud | Optionally writes its `streamUrl` / `captureUrl` to Firebase |

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
/devices/fridge_01/sensors     <- written by ESP32 DevKit
/devices/fridge_01/camera      <- written by ESP32-CAM (or app)
/devices/fridge_01/detection   <- written by ESP32 DevKit (weight trigger)
/devices/fridge_01/products    <- written by app/backend (auto registration)
/devices/fridge_01/alerts      <- written by app / backend
```

The full schema with example values lives in
[firebase-schema.json](firebase-schema.json).

### Who writes what

| Path | Writer | Reader |
|------|--------|--------|
| `sensors` | ESP32 DevKit | App, backend |
| `camera` | ESP32-CAM / app | App, backend |
| `detection` | ESP32 DevKit (sets), app/backend (resets) | App, backend |
| `products` | App / backend (auto registration) | App |
| `alerts` | App, backend | App |

---

## 4. Automatic product registration

Product registration is **automatic** and triggered by the load cells — the
user does **not** have to press an "Add Product" button. (A manual QR scan
remains available only as a backup.)

### Workflow

```
1. User places a product on the load-cell platform.
2. ESP32 DevKit detects a stable weight INCREASE (see below).
3. ESP32 DevKit writes /detection:
       { newProductDetected: true, eventType: "added",
         weightDelta, stableWeight, updatedAt }
4. The app (or backend) is listening on /detection.
5. When newProductDetected == true it calls the ESP32-CAM /capture URL.
6. The captured image is analyzed for a QR code (on the app / backend).
7. The QR-code JSON is parsed into product metadata.
8. The product is saved under /devices/fridge_01/products/{productId}.
9. The app shows the new product automatically (it already streams /products).
10. The app/backend resets /detection/newProductDetected back to false.
```

The **ESP32-CAM only serves the image** via `/capture`. It never decodes QR
codes — decoding happens on the app or the Python backend.

### Weight-change detection

The ESP32 DevKit samples the HX711 weight roughly once per second and runs a
small stability state machine:

| Parameter | Value | Meaning |
|-----------|-------|---------|
| `WEIGHT_EVENT_THRESHOLD` | 50 g | minimum change treated as an event |
| `WEIGHT_NOISE_BAND` | 20 g | smaller fluctuations are ignored |
| `WEIGHT_STABLE_MS` | 4000 ms | weight must hold steady this long |

- The weight must settle (stay within the noise band) for `WEIGHT_STABLE_MS`
  before a change is accepted — this rejects hands, vibration and noise.
- A stable **increase** of >= 50 g => product **added** =>
  `newProductDetected: true`, `eventType: "added"`.
- A stable **decrease** of >= 50 g => product **removed / consumed** =>
  `eventType: "removed"` (`newProductDetected` stays `false`; no camera
  capture is needed for a removal).
- After firing, the new stable level becomes the baseline, so the event does
  not repeat until the weight settles at yet another level.

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

## 6. Banana browning detection

Lightweight image processing only — **no heavy ML**.

Steps (mobile app or Python backend):

1. Fetch the latest JPEG from the ESP32-CAM `/capture` URL.
2. Convert to HSV; also keep RGB.
3. Count "brown/dark" pixels using HSV + RGB thresholds.
4. `browningRatio = brownPixels / totalAnalyzedPixels`.
5. Map ratio to `visualStatus`:

| browningRatio | visualStatus |
|---------------|--------------|
| `< 0.10` | Fresh |
| `0.10 - 0.25` | Slight Browning |
| `0.25 - 0.50` | Browning Detected |
| `>= 0.50` | Consume Soon |

6. Write `browningRatio` + `visualStatus` back to the product.

The default implementation is the Python backend
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
