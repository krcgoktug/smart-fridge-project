// Smart Fridge — ESP32-CAM camera node
// Runs a small HTTP server with /capture (JPEG) and /stream (MJPEG).
//
// NOTE: This sketch depends on a custom CameraWebServer helper which
// is not bundled with this branch. Restore from the project archive
// before compiling.

#include <WiFi.h>
// #include "esp_camera.h"
// #include "camera_pins.h"
// #include "cam_secrets.h"

void startCameraServer();

void setup() {
  Serial.begin(115200);
  // WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  // camera_init();
  // startCameraServer();
}

void loop() {
  delay(10000);
}
