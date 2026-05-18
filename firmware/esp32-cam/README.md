# ESP32-CAM AI-Thinker — Camera Node Firmware

**Camera only.** This board runs an always-on MJPEG stream and a snapshot
endpoint. It does **not** decode QR codes, run AI, or talk to Firebase — the
Python backend pulls frames from it and does all the processing.

Endpoints (replace the IP with the one on the serial monitor):

| URL | Purpose |
|-----|---------|
| `http://<ip>/` | HTML page with the live stream |
| `http://<ip>/stream` | continuous multipart MJPEG stream |
| `http://<ip>/capture` | a single JPEG frame |

## 1. Required tools

- Arduino IDE 2.x with the **esp32 by Espressif** board package.
- An **FTDI / USB-TTL adapter** at **3.3 V logic** (the ESP32-CAM has no USB).
- No external libraries are needed.

## 2. Configure secrets

```
cp cam_secrets.example.h cam_secrets.h
```

Fill in Wi-Fi only (same network as the backend and the phone).
`cam_secrets.h` is git-ignored.

## 3. Wiring for flashing

See [../../docs/wiring.md](../../docs/wiring.md).

| FTDI | ESP32-CAM |
|------|-----------|
| 5V | 5V |
| GND | GND |
| TX | U0R |
| RX | U0T |

Jumper **GPIO 0 -> GND** to enter flash mode.

## 4. Upload

1. Open `esp32-cam.ino`.
2. **Tools -> Board -> AI Thinker ESP32-CAM**, **PSRAM: Enabled**.
3. Connect GPIO 0 to GND, press RESET, select the FTDI port, **Upload**.
4. Remove the GPIO 0 jumper, press RESET.
5. Open the **Serial Monitor** at **115200 baud** to read the IP.

## 5. Verify

Open `http://<ip>/` in a browser on the same network — you should see the
live stream. Put `<ip>` into:

- the backend `.env` (`CAMERA_BASE_URL`),
- the app **Settings -> ESP32-CAM address**.

## 6. Troubleshooting

| Symptom | Fix |
|---------|-----|
| `camera init failed` | Reseat the OV2640 ribbon; use a solid 5 V supply |
| Board keeps rebooting | Power brown-out — stronger 5 V source |
| Upload fails | GPIO 0 not grounded, or TX/RX swapped |
| Stream slow | Normal on Wi-Fi; lower `frame_size` in the sketch |
