# ESP32-CAM — Camera Node

Runs an always-on CameraWebServer on the AI-Thinker ESP32-CAM. The mobile app
shows the live stream and grabs frames from it to read product QR codes.

Endpoints (at the **local IP** printed on the serial monitor):

| URL | Purpose |
|-----|---------|
| `http://<ip>/` | HTML page with the live stream |
| `http://<ip>/stream` | continuous MJPEG stream |
| `http://<ip>/capture` | a single JPEG frame |

> Each ESP32-CAM gets its **own local IP** from the Wi-Fi router. The IP is
> never hard-coded — you type it into the app's **Camera** screen.

## 1. Tools

- Arduino IDE 2.x with the **esp32 by Espressif** board package.
- An **FTDI / USB-TTL adapter** at **3.3 V** (the ESP32-CAM has no USB port).
- No external libraries needed. Board: **AI Thinker ESP32-CAM**, PSRAM enabled.

## 2. Configure

```
cp cam_secrets.example.h cam_secrets.h
```

Fill in Wi-Fi only (same network as the phone). `cam_secrets.h` is git-ignored.

## 3. Flashing wiring

See [../../docs/wiring.md](../../docs/wiring.md).

| FTDI | ESP32-CAM |
|------|-----------|
| 5V | 5V |
| GND | GND |
| TX | U0R |
| RX | U0T |

Jumper **GPIO 0 → GND** to enter flash mode.

## 4. Upload & verify

1. Open `esp32-cam.ino`, select **AI Thinker ESP32-CAM**.
2. GPIO 0 → GND, press RESET, select the FTDI port, **Upload**.
3. Remove the GPIO 0 jumper, press RESET.
4. Open the **Serial Monitor** at **115200 baud**:

```
Camera Ready!
Local IP: 192.168.1.44
Stream:   http://192.168.1.44/stream
Capture:  http://192.168.1.44/capture
```

5. Type that IP into the app → **Camera** screen.

## Notes

- No SD card is used.
- The camera stream is **local-network only** — the phone must be on the same
  Wi-Fi as the ESP32-CAM to view it.
