# University Report Explanation

Report-style explanation of the project. Each section maps to a typical
report chapter and can be adapted.

---

## 1. Abstract

The Zero Waste Smart Fridge is a real-time Internet-of-Things system that
helps reduce household food waste. It combines environmental sensing, a
camera, classic computer vision, a cloud database and a mobile application.
The architecture is split into four independent layers so that each component
has a single, clearly defined responsibility.

## 2. Problem statement

Households waste food because items are forgotten or their expiry dates are
not tracked. The system addresses this with continuous automatic monitoring
and an easy-to-read dashboard that warns the user early.

## 3. System architecture

The system has four layers:

1. **Sensing layer — ESP32 DevKit V1.** Reads HX711 load cells (weight), a
   DHT11 sensor (temperature and humidity) and an MQ135 sensor (gas). Every 10 seconds it
   sends a heartbeat to the cloud database with an NTP timestamp, so the
   application can reliably detect when the board goes offline (no update for
   60 seconds). The load cells provide quantity / weight verification and a
   spoilage-risk contribution; they are not used to identify products.

2. **Vision-input layer — ESP32-CAM.** An always-on camera that exposes an
   MJPEG stream and a snapshot endpoint over HTTP. It performs no processing;
   it only provides images.

3. **Processing layer — image analysis service (Python).** The processing
   layer. It runs a continuous loop: it pulls a frame from the camera, decodes
   any QR code with OpenCV and pyzbar, analyses banana browning with HSV
   colour thresholding, reports the camera online status, and recomputes the
   alert list. Results are written to the cloud database.

4. **Visualization layer — Flutter application.** A read-only dashboard that
   reads the cloud database and displays the live camera stream. It does no
   processing of its own.

The layers communicate only through Firebase Realtime Database, which acts as
a message bus. This separation makes the system robust: any layer can fail
without breaking the others.

## 4. QR-based product registration

Each product carries a printed QR code containing a small JSON payload with a
unique `productId`, a `name`, an `expiryDate` and a `category`. The image
analysis service decodes this from the camera image and registers the product
automatically — there is no manual product entry. The application then shows
each product with an expiry-based status: Fresh, Expiring Soon, or Expired.
See `docs/qr-system.md`.

## 5. Banana browning analysis

Banana spoilage is estimated with **real pixel-based computer vision**, not
machine learning. A camera frame is converted to the HSV colour space.
Healthy yellow flesh, brown overripe regions and dark spots are isolated with
colour thresholds. The spoilage estimate is the ratio of brown and dark
pixels to the whole banana region:

```
brownPercent = (brown + dark pixels) / banana region pixels * 100
```

The percentage maps to a four-tier status — Fresh (0-15 %), Slight Browning
(15-35 %), Browning Detected (35-60 %) or Spoilage Risk (60 %+). This approach
is fast, needs no training data, is fully explainable, and is appropriate for
a constrained embedded project. See `docs/banana-analysis.md`.

## 6. Cloud database

Firebase Realtime Database stores a small JSON tree under
`devices/fridge_01`: `sensors`, `camera`, `products`, `bananaAnalysis` and
`alerts`. Realtime Database was chosen because the data set is small and
frequently updated, and because it pushes changes to the application in real
time. See `docs/firebase-schema.md`.

## 7. Offline behavior

Because the layers are independent, a missing component degrades the system
gracefully rather than breaking it. If the ESP32 sensor board stops sending
heartbeats, the application detects the stale timestamp and displays
"ESP32 Offline" while the camera and product features keep working.

## 8. Implementation and testing

The repository contains the ESP32 firmware, the Python image analysis
service, the Flutter application and full documentation. The QR decoding was
verified with printed sample codes; the banana analysis was checked against
images with known browning; the application was tested against seeded
database data. No secrets are committed — credentials use template files and
`.gitignore`.

## 9. Limitations

- The banana analysis is colour-threshold based and is sensitive to lighting;
  the enclosed box mitigates this.
- The MQ135 is uncalibrated and gives a qualitative gas trend only.
- The ESP32-CAM is a plain HTTP device, so a web build served over HTTPS
  cannot display the live stream (browser mixed-content policy); the Android
  app or a local run on the same Wi-Fi is used instead. See
  `docs/camera-limitations.md`.

## 10. Future work

- Combine the visual browning percentage and the environmental sensor
  readings into a single weighted spoilage-risk index.
- Per-product calibration of the gas baseline.
- More product types in the vision pipeline.
- Push notifications for alerts.
- Power optimisation with deep sleep on the sensor node.

## 11. Conclusion

The project demonstrates a complete, technically honest IoT and computer
vision pipeline — sensing, an independent camera, real CV processing, a cloud
database and a mobile dashboard — built from affordable ESP32 hardware.
