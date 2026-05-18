# ESP32 DevKit V1 — Sensor Node Firmware

Reads the MQ135 gas sensor, DHT11 temperature/humidity sensor and an HX711 +
4 load cells, computes a sensor-side risk estimate, and uploads JSON to the
Firebase Realtime Database path `/devices/fridge_01/sensors`.

It also drives **automatic product detection**: when the load-cell weight
changes by a stable amount, it writes an event to `/devices/fridge_01/detection`
so the app can register the product without any button press (see
[../../docs/architecture.md](../../docs/architecture.md#4-automatic-product-registration)).

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

- **Weight**: place a known weight on the box, read the raw value, and set
  `HX711_CALIBRATION_FACTOR` so the reported grams match. Flip its sign if the
  weight reads negative.
- **Gas**: the MQ135 needs ~1-2 minutes to warm up before readings stabilize.
- The box is **tared at startup**, so it must be empty when the board boots.

## 7. Automatic product detection (tuning)

The firmware watches the load-cell weight and writes an event to
`/devices/fridge_01/detection` on a stable change. Tune these constants at
the top of the sketch for your scale:

| Constant | Default | Meaning |
|----------|---------|---------|
| `WEIGHT_EVENT_THRESHOLD` | `50.0f` g | minimum change treated as a product event |
| `WEIGHT_NOISE_BAND` | `20.0f` g | smaller fluctuations are ignored |
| `WEIGHT_STABLE_MS` | `4000` ms | weight must hold steady this long (3-5 s) |
| `WEIGHT_CHECK_INTERVAL_MS` | `1000` ms | how often the weight is sampled |

- A stable **increase** => `newProductDetected: true`, `eventType: "added"`.
- A stable **decrease** => `eventType: "removed"` (no camera capture needed).
- The app/backend resets `newProductDetected` to `false` after registering.

## 8. Expected serial output

```
=== Zero Waste Smart Fridge -- ESP32 Sensor Node ===
[HX711] tared (empty box = 0 g).
[WiFi] Connected. IP: 192.168.1.42
[Weight] product ADDED  (+152 g)
[Detect] event 'added' (delta 152 g) sent.
[Read] T=5.8C  H=72%  Gas=1350  W=152g  Risk=24 (Fresh)
[Upload] sensors OK.
```

## 9. Troubleshooting

| Symptom | Fix |
|---------|-----|
| `DHT11 read failed` | Check 3V3, data on GPIO 4, add 10k pull-up |
| Weight is negative | Flip the sign of `HX711_CALIBRATION_FACTOR` |
| Detection never fires | Lower `WEIGHT_EVENT_THRESHOLD`; check HX711 wiring |
| Detection fires randomly | Raise `WEIGHT_NOISE_BAND` / `WEIGHT_STABLE_MS` |
| `PATCH ... failed, HTTP 401` | Wrong `FIREBASE_AUTH` or rules block writes |
| Gas value stuck | Wait for warm-up; confirm AOUT on GPIO 34 |
