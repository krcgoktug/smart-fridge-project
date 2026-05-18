# University Report Explanation

This document explains the project in report form. It can be pasted into a
university report and adapted. Each section maps to a typical report chapter.

---

## 1. Abstract

The Zero Waste Smart Fridge is an Internet-of-Things (IoT) system that reduces
household food waste by monitoring stored products and warning the user before
food spoils. It uses two ESP32 microcontrollers, environmental sensors, a
camera, QR-code product identification, a cloud database, and a mobile
application. Instead of predicting an exact spoilage time, the system computes
a *relative* risk score from several independent signals and presents an easy
green/yellow/red status to the user.

## 2. Problem statement

A large share of household food is wasted because items are forgotten at the
back of the fridge or their expiry dates are not tracked. A purely manual
approach fails because people do not remember every product. The project
addresses this with continuous, automatic monitoring.

## 3. Objectives

1. Measure the storage environment (temperature, humidity, gas, weight).
2. Identify each product reliably using QR codes.
3. Detect visible spoilage for fruit (banana browning) with lightweight image
   processing.
4. Combine all signals into a single, understandable risk score.
5. Present the information and alerts in a clean mobile app.

## 4. System design

### 4.1 Hardware

- **ESP32 DevKit V1** reads an MQ135 gas sensor, a DHT11 temperature/humidity
  sensor, and an HX711 amplifier connected to four load cells. It computes a
  sensor-side risk value and uploads JSON to the cloud.
- **ESP32-CAM AI Thinker** runs the standard `CameraWebServer` and exposes a
  stream and a capture endpoint. It is deliberately limited to image serving;
  no decoding or AI runs on it, because the module has little free memory once
  the camera driver is loaded.

### 4.2 Cloud

Firebase Realtime Database stores a small JSON tree under
`/devices/fridge_01`. Realtime Database was chosen over Firestore because the
data set is small, changes frequently, and the ESP32 client libraries for RTDB
are simple and well supported.

### 4.3 Software

A Flutter mobile application provides seven screens (dashboard, product list,
add product / QR scan, product detail, camera view, alerts, settings). An
optional Python service performs banana browning analysis on captured images.

## 5. Risk score methodology

The risk score is intentionally a **heuristic**, not a physical spoilage model.
It sums six bounded components:

```
riskScore = expiryRisk + temperatureRisk + humidityRisk
          + gasRisk + visualRisk + weightRisk      (clamped 0..100)
```

- **expiryRisk** grows as the printed expiry date approaches.
- **temperatureRisk / humidityRisk** grow when the environment leaves the ideal
  cold-storage range.
- **gasRisk** reflects the MQ135 reading; decomposing food releases gases.
- **visualRisk** reflects measured banana browning.
- **weightRisk** reflects unexpected weight deviation (leak, spill, tampering).

Different categories use different components, because, for example, a sealed
milk carton is not meaningfully assessed by a gas sensor or browning analysis.
The final score maps to three bands: Fresh (0-39), Consume Soon (40-69), and
Spoilage Risk (70-100).

This design is justified for a university project because it is transparent,
explainable, requires no training data, and runs on constrained hardware.

## 6. Banana browning analysis

Banana browning is measured with classic pixel-based image processing rather
than machine learning. A still image from the ESP32-CAM is examined pixel by
pixel using simple RGB / HSV thresholds, classifying each pixel as a brown
spot, a dark spot, or ordinary banana / background. The result is three
figures — `brownSpotPercentage`, `darkSpotPercentage` and their sum
`totalBrowningPercentage` — which map to a `visualStatus` of Fresh, Slight
Browning, Browning Detected or Consume Soon. This is fast, needs no dataset,
and runs on the phone or a small Python service. The analysis is triggered by
the user ("Analyze Banana"); it does not depend on the load cells. The
trade-off is sensitivity to lighting, mitigated by the enclosed box.

## 6a. Independent devices and offline behavior

The two ESP32 boards are intentionally independent. The camera never waits for
a load-cell event, and the sensor board is optional: its readings carry a real
NTP timestamp, so when it stops reporting the app marks it offline after 60
seconds and shows "ESP32 not connected" while QR scanning and banana analysis
continue to work. This makes the system robust for a live demonstration.

## 7. Implementation summary

The repository contains: firmware for both ESP32 boards, a Flutter application,
an optional Python backend, sample QR product definitions, and full
documentation. Secrets are never committed; template files and `.gitignore`
entries keep Wi-Fi and Firebase credentials out of version control.

## 8. Testing

- **Sensors**: compared DHT11 readings against a reference thermometer;
  verified MQ135 response by introducing decaying food; calibrated the HX711
  with known weights.
- **QR**: validated parsing with the sample products in `qr-samples/`.
- **Risk score**: checked boundary values for each component and band.
- **App**: verified each screen against seeded Firebase data.

## 9. Limitations

- The risk score is relative and heuristic, not a calibrated spoilage model.
- The MQ135 is uncalibrated and gives a qualitative gas trend only.
- Browning detection is lighting-sensitive.
- A single camera cannot see every product clearly.

## 10. Future work

- Push notifications for alerts.
- Multiple cameras or a moving camera.
- A trained vision model for more product types.
- Per-product calibration of the gas baseline.
- Power optimization with deep sleep on the sensor node.

## 11. Conclusion

The project demonstrates a complete, working IoT pipeline — sensing, cloud,
identification, basic computer vision, and a mobile UI — built around
affordable ESP32 hardware. It meets its objective of giving users an early,
understandable warning before food is wasted.
