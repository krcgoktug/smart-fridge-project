# ESP32 DevKit — Sensor Controller

Reads DHT11 (temperature + humidity), MQ135 (gas) and HX711 (weight) and
uploads the live values to Firebase Realtime Database at
`devices/fridge_01/sensors`.

```json
{ "temperature": 6.4, "humidity": 73, "gasValue": 1350,
  "weight": 482, "updatedAt": 1710000000 }
```

The sensor data is in the cloud, so **every team member sees it live** in the
app — even though the ESP32 is plugged into only one computer by USB.

## 1. Tools

- [Arduino IDE](https://www.arduino.cc/en/software) 2.x.
- ESP32 board support — add this Boards Manager URL and install
  **esp32 by Espressif Systems**:
  `https://espressif.github.io/arduino-esp32/package_esp32_index.json`
- Board: **ESP32 Dev Module**.

## 2. Libraries (Library Manager)

| Library | Author |
|---------|--------|
| DHT sensor library | Adafruit |
| Adafruit Unified Sensor | Adafruit |
| HX711 | Bogdan Necula |
| ArduinoJson | Benoit Blanchon (v6 or v7) |

## 3. Configure

```
cp secrets.example.h secrets.h
```

Fill in Wi-Fi SSID/password, the Firebase database URL and auth token in
`secrets.h` (git-ignored — never commit it).

## 4. Wiring

See [../../docs/wiring.md](../../docs/wiring.md).

| Function | GPIO |
|----------|------|
| DHT11 DATA | 4 |
| MQ135 AOUT | 34 |
| HX711 DT | 16 |
| HX711 SCK | 17 |

## 5. Upload & verify

1. Open `esp32-devkit.ino`, select **ESP32 Dev Module** + the COM port.
2. **Upload**, then open **Serial Monitor** at **115200 baud**:

```
=== Zero Waste Smart Fridge -- ESP32 Sensor Controller ===
[HX711] connected and tared.
[WiFi] Connected. IP: 192.168.1.42
[Read] T=6.4C  H=73%  Gas=1350  W=482g
[Upload] OK -> devices/fridge_01/sensors
```

## Notes

- The HX711 is optional — without load cells the weight reads `0 g`.
- The MQ135 needs ~1-2 minutes to warm up.
- If the board stops uploading, the app shows **"ESP32 Sensor Board Offline"**
  after 60 seconds (stale `updatedAt`).
