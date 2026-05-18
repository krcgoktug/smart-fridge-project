# ESP32 DevKit V1 — Sensor Node Firmware

Reads the MQ135 gas sensor, DHT11 temperature/humidity sensor and an HX711 +
4 load cells, computes a sensor-side risk estimate, and uploads JSON to the
Firebase Realtime Database path `/devices/fridge_01/sensors`.

This board is an **independent, optional sensor node**:

- It does **not** trigger the camera and does **not** drive product
  registration — the load cells are simply one more sensor reading.
- If this board is offline the rest of the system keeps working. The app
  detects a stale `updatedAt` and shows *"ESP32 not connected"*.
- `updatedAt` is a real Unix timestamp (synced over NTP), so the app can
  reliably decide whether the sensor data is fresh.
- The HX711 is optional too: if no load cells are connected the weight is
  reported as `0 g` and `hasLoadCell` is `false`.

## 1. Required tools

- [Arduino IDE](https://www.arduino.cc/en/software) 2.x (or PlatformIO).
- ESP32 board support: in Arduino IDE add this Boards Manager URL —
  `https://espressif.github.io/arduino-esp32/package_esp32_index.json` —
  then install **esp32 by Espressif Systems**.

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

Edit `secrets.h` and set your Wi-Fi SSID/password, Firebase database URL and
auth token. `secrets.h` is git-ignored — never commit it.

## 4. Wiring

See [../../docs/wiring.md](../../docs/wiring.md). Summary:

| Function | GPIO |
|----------|------|
| DHT11 DATA | 4 |
| MQ135 AOUT | 34 (ADC, input-only) |
| HX711 DT | 16 |
| HX711 SCK | 17 |

## 5. Upload steps

1. Open `esp32-devkit-sensors.ino` in the Arduino IDE.
2. Select **Tools -> Board -> ESP32 Dev Module**.
3. Select the correct **Port**.
4. Click **Upload**.
5. Open **Serial Monitor** at **115200 baud**.

## 6. Calibration

- **Weight** (only if load cells are fitted): place a known weight on the box,
  read the raw value, and set `HX711_CALIBRATION_FACTOR` so the reported grams
  match. Flip its sign if the weight reads negative.
- **Gas**: the MQ135 needs ~1-2 minutes to warm up before readings stabilize.
- If load cells are fitted the box is **tared at startup**, so it must be
  empty when the board boots.

## 7. Expected serial output

```
=== Zero Waste Smart Fridge -- ESP32 Sensor Node ===
[HX711] connected and tared (empty box = 0 g).
[WiFi] Connected. IP: 192.168.1.42
[Read] T=5.8C  H=72%  Gas=1350  W=482g  Risk=24 (Fresh)
[Upload] sensors OK.
```

Without load cells the third line shows `W=0g` and `[HX711] not detected`.

## 8. Troubleshooting

| Symptom | Fix |
|---------|-----|
| `DHT11 read failed` | Check 3V3, data on GPIO 4, add 10k pull-up |
| Weight is negative | Flip the sign of `HX711_CALIBRATION_FACTOR` |
| App shows "ESP32 not connected" | Board offline, or NTP not synced — check Wi-Fi |
| `PATCH ... failed, HTTP 401` | Wrong `FIREBASE_AUTH` or rules block writes |
| Gas value stuck | Wait for warm-up; confirm AOUT on GPIO 34 |
