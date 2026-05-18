# ESP32 DevKit V1 — Sensor Controller Firmware

The sensor controller of the Smart Fridge. It reads three sensors and pushes
a **heartbeat** to Firebase Realtime Database every 10 seconds.

It does **not** touch the camera and does **not** do any QR / image work.

## Firebase output

Path: `devices/fridge_01/sensors`

```json
{
  "weight": 482,
  "temperature": 5.8,
  "gas": 1350,
  "updatedAt": 1710000000,
  "alive": true
}
```

`updatedAt` is a real Unix timestamp (NTP). The Flutter app shows
**"ESP32 Offline"** when it is older than 60 seconds.

## 1. Required tools

- [Arduino IDE](https://www.arduino.cc/en/software) 2.x.
- ESP32 board support — Boards Manager URL:
  `https://espressif.github.io/arduino-esp32/package_esp32_index.json`
  then install **esp32 by Espressif Systems**. Board: **ESP32 Dev Module**.

## 2. Required libraries (Library Manager)

| Library | Author |
|---------|--------|
| DHT sensor library | Adafruit |
| Adafruit Unified Sensor | Adafruit |
| HX711 | Bogdan Necula |
| ArduinoJson | Benoit Blanchon (v6 or v7) |

## 3. Configure secrets

```
cp secrets.example.h secrets.h
```

Fill in Wi-Fi SSID/password, the Firebase database URL and auth token.
`secrets.h` is git-ignored — never commit it.

## 4. Wiring

See [../../docs/wiring.md](../../docs/wiring.md).

| Function | GPIO |
|----------|------|
| DHT11 DATA | 4 |
| MQ135 AOUT | 34 (ADC, input-only) |
| HX711 DT | 16 |
| HX711 SCK | 17 |

## 5. Upload

1. Open `esp32-devkit-sensors.ino`, select **ESP32 Dev Module** and the port.
2. **Upload**, then open the **Serial Monitor** at **115200 baud**.

Expected output:

```
=== Zero Waste Smart Fridge -- ESP32 Sensor Controller ===
[HX711] connected and tared.
[WiFi] Connected. IP: 192.168.1.42
[Read] W=482g  T=5.8C  Gas=1350
[Heartbeat] sent -> devices/fridge_01/sensors
```

## 6. Notes

- The **HX711 is optional**: without load cells the weight reads `0 g` and
  everything else still works.
- The MQ135 needs ~1-2 minutes to warm up.
- If the board is powered off, the app shows "ESP32 Offline" after 60 s.

## 7. Troubleshooting

| Symptom | Fix |
|---------|-----|
| `DHT11 read failed` | Check 3V3, data on GPIO 4, add a 10k pull-up |
| Weight is wrong | Calibrate `HX711_CALIBRATION_FACTOR` |
| `Heartbeat failed, HTTP 401` | Wrong `FIREBASE_AUTH` or database rules |
| App shows "ESP32 Offline" | Board offline, Wi-Fi down, or NTP not synced |
