# Architecture

The Smart Fridge consists of four cooperating parts:

1. **ESP32 DevKit sensor node** — reads DHT11 (temperature, humidity),
   MQ135 (gas), HX711 + four load cells (weight), and a Risk Score
   that combines them.
2. **ESP32-CAM** — small HTTP server serving JPEG snapshots and an
   MJPEG live stream.
3. **Firebase Realtime Database** — single source of truth shared
   between firmware and app.
4. **Flutter mobile app** — Dashboard, Camera, Products, Alerts.

## Risk score logic

```
riskScore = expiryRisk + temperatureRisk + humidityRisk
          + gasRisk + visualRisk + weightRisk
```

Final value is clamped to `0..100` and mapped to a status band.

## Firebase tree

```
/devices/fridge_01
  sensors/...
  camera/...
  products/...
  alerts/...
```

Full schema in [firebase-schema.json](firebase-schema.json).
