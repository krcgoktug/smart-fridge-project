# Firebase Realtime Database Schema

The system uses **Firebase Realtime Database only** (not Firestore). The
database is the message bus between the four layers — every layer either
writes or reads, never both on the same node.

All timestamps are **Unix seconds**.

---

## 1. Tree layout

```
devices/
  fridge_01/
    sensors            <- written by ESP32 DevKit
    camera             <- written by the image analysis service
    products/
      <productId>      <- written by the image analysis service (QR)
    bananaAnalysis     <- written by the image analysis service (CV)
    alerts/
      <alertId>        <- written by the image analysis service
```

| Node | Writer | Reader |
|------|--------|--------|
| `sensors` | ESP32 DevKit | App, service (for alerts) |
| `camera` | Image analysis service | App |
| `products` | Image analysis service | App, service (for alerts) |
| `bananaAnalysis` | Image analysis service | App |
| `alerts` | Image analysis service | App |

`fridge_01` is the device id; it must match the firmware, the service `.env`
and the app `AppConfig.deviceId`.

---

## 2. Node formats

### `sensors`

ESP32 DevKit heartbeat, written every 10 s. The app shows "ESP32 Offline"
when `updatedAt` is older than 60 s.

```json
{
  "weight": 482,
  "temperature": 5.8,
  "humidity": 47,
  "gas": 1350,
  "updatedAt": 1710000000,
  "alive": true
}
```

`temperature` (°C) and `humidity` (%) come from the DHT11; `gas` is the raw
MQ135 reading; `weight` (g) is the HX711 load cells.

### `camera`

ESP32-CAM online status. The camera never writes to Firebase — the image
analysis service reports whether it could reach the camera.

```json
{
  "online": true,
  "ip": "http://192.168.1.50",
  "lastFrameAt": 1710000000,
  "frameWidth": 640,
  "frameHeight": 480
}
```

### `products/<productId>`

One node per product, keyed by the `productId` from its QR sticker.

```json
{
  "productId": "banana_001",
  "productName": "Banana",
  "category": "Fruit",
  "expiryDate": "2026-05-25",
  "detectedAt": 1710000000,
  "source": "qr"
}
```

### `bananaAnalysis`

Latest banana browning result. See [banana-analysis.md](banana-analysis.md).

```json
{
  "brownPercent": 37,
  "visualStatus": "Browning Detected",
  "status": "Consume Soon",
  "analyzedAt": 1710000000
}
```

### `alerts/<alertId>`

One node per active alert. The service replaces the whole `alerts` node each
cycle, so a cleared condition removes its alert automatically. `severity` is
`info`, `warning` or `danger`.

```json
{
  "esp32_offline": {
    "type": "sensor",
    "message": "ESP32 sensor board is offline -- no live sensor data.",
    "severity": "warning",
    "createdAt": 1710000000
  }
}
```

---

## 3. Setup

1. Create a project at <https://console.firebase.google.com>.
2. Enable **Realtime Database**.
3. The ESP32 and the service create all nodes automatically once configured —
   no manual setup of the tree is needed.
4. To preview the app without hardware, import
   [demo-seed.json](demo-seed.json) at the database root.
