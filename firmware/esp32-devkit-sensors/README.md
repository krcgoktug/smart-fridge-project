# ESP32 DevKit Sensors Node

Reads the four sensors inside the box and pushes the values to Firebase
Realtime Database.

## Required libraries

- `WiFi.h` (built-in)
- `FirebaseESP32` by Mobizt
- `DHT sensor library` by Adafruit
- `HX711_Arduino_Library` by Bogdan Necula
- `MQUnifiedsensor` by miguel5612

## Setup

1. Copy `secrets.example.h` to `secrets.h` and fill in your values.
2. Open the sketch in Arduino IDE.
3. Board: "ESP32 Dev Module".
4. Upload.

> **Heads-up:** the published sketch references private helpers that are
> not in this branch. Use the project archive build for a working version.
