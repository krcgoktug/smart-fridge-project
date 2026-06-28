# ESP32-CAM Camera Node

Runs a small HTTP server on the camera so the mobile app can pull a
live MJPEG stream and a single JPEG capture for image analysis.

## Endpoints

- `http://<cam-ip>/capture` — single JPEG
- `http://<cam-ip>:81/stream` — MJPEG live video

## Setup

1. Copy `cam_secrets.example.h` to `cam_secrets.h` and fill in Wi-Fi.
2. Board: "AI Thinker ESP32-CAM".
3. Upload via FTDI / programmer shield with GPIO0 grounded.
4. Reset; on the serial monitor (115200) you'll see the camera IP.
