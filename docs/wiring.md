# Wiring

| Sensor | ESP32 pin |
| --- | --- |
| DHT11 DATA | GPIO4 |
| MQ135 AOUT | GPIO34 |
| HX711 DT   | GPIO16 |
| HX711 SCK  | GPIO17 |
| Status LED | GPIO2 |

All sensors share 5 V and a common GND.

For the ESP32-CAM, use the default AI Thinker pinout (see
[camera_pins.h](../firmware/esp32-cam-camera/) in the team archive).
