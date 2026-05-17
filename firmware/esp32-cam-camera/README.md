# ESP32-CAM AI-Thinker — Camera Node Firmware

Runs a camera web server on the ESP32-CAM. It only **serves images** —
no QR decoding, no AI, no image processing on this board.

Endpoints (replace the IP with the one printed on the serial monitor):

| URL | Purpose |
|-----|---------|
| `http://<ip>/` | HTML page with a live stream |
| `http://<ip>/stream` | raw MJPEG stream |
| `http://<ip>/capture` | a single JPEG frame |

Reference working deployment: `http://172.19.15.112` and
`http://172.19.15.112/capture`.

## 1. Required tools

- Arduino IDE 2.x with the **esp32 by Espressif** board package.
- An **FTDI / USB-TTL adapter** set to **3.3 V logic** (the ESP32-CAM has no
  USB port).
- **ArduinoJson** library (only needed for the optional Firebase URL upload).

## 2. Configure secrets

```
cp cam_secrets.example.h cam_secrets.h
```

Fill in Wi-Fi (same network as the phone) and, if you want the board to
publish its URLs, the Firebase values. `cam_secrets.h` is git-ignored.

To disable Firebase entirely, set `WRITE_URLS_TO_FIREBASE` to `false` in the
sketch — then the camera works fully offline on the LAN.

## 3. Wiring for flashing

See [../../docs/wiring.md](../../docs/wiring.md). Summary:

| FTDI | ESP32-CAM |
|------|-----------|
| 5V | 5V |
| GND | GND |
| TX | U0R |
| RX | U0T |

Jumper **GPIO 0 -> GND** to enter flash mode.

## 4. Upload steps

1. Open `esp32-cam-camera.ino` in the Arduino IDE.
2. **Tools -> Board -> AI Thinker ESP32-CAM**.
3. Confirm **PSRAM: Enabled** (default for this board).
4. Connect GPIO 0 to GND, then press the RESET button.
5. Select the FTDI **Port** and click **Upload**.
6. When upload finishes: **remove the GPIO 0 jumper** and press RESET.
7. Open the **Serial Monitor** at **115200 baud** to read the IP address.

## 5. Verify

Open `http://<ip>/` in a browser on the same network — you should see the live
box camera. `http://<ip>/capture` should return a single JPEG.

## 6. Troubleshooting

| Symptom | Fix |
|---------|-----|
| `camera init failed 0x...` | Reseat the OV2640 ribbon; use a solid 5 V supply |
| Board keeps rebooting | Power brown-out — use a stronger 5 V source |
| Upload fails / no port | GPIO 0 not grounded, or TX/RX swapped |
| Stream is very slow | Normal on Wi-Fi; lower `frame_size` in the sketch |
| IP changes between runs | Reserve a static DHCP lease on the router |

## 7. Note for the mobile app / backend

The capture URL is an HTTP (not HTTPS) LAN address. The phone and any backend
must be on the **same Wi-Fi network** to reach it.
