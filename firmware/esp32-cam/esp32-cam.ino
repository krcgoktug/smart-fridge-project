/*
 * ==========================================================================
 *  Zero Waste Smart Fridge  --  ESP32-CAM AI-Thinker  --  Camera Node
 * ==========================================================================
 *
 *  CAMERA ONLY. This board runs an always-on CameraWebServer so the mobile
 *  app can show the live stream and grab frames to read product QR codes.
 *
 *  ENDPOINTS (at the LOCAL IP printed on the serial monitor):
 *    GET /          -> HTML page with the live stream
 *    GET /stream    -> continuous multipart MJPEG stream
 *    GET /capture   -> a single JPEG frame
 *
 *  Each ESP32-CAM gets its OWN local IP from the Wi-Fi router, so the IP is
 *  entered into the app's Camera screen (it is never hard-coded).
 *  The board does NOT decode QR codes and does NOT talk to Firebase.
 *
 *  ------------------------------------------------------------------------
 *  BOARD: "AI Thinker ESP32-CAM"   (Tools -> Board)
 *  PSRAM: enabled (default for this board)
 *  No external libraries are required beyond the esp32 board package.
 *
 *  FLASHING: the ESP32-CAM has no USB. Use an FTDI/USB-TTL adapter at 3.3V,
 *  jumper GPIO0 -> GND to enter flash mode, then remove it and reset.
 *  See docs/wiring.md.
 *
 *  CONFIG: copy cam_secrets.example.h -> cam_secrets.h and fill in Wi-Fi.
 * ==========================================================================
 */

#include <WiFi.h>
#include "esp_camera.h"
#include "esp_http_server.h"

#include "camera_pins.h"
#include "cam_secrets.h"   // copy from cam_secrets.example.h (git-ignored)

static httpd_handle_t camera_httpd = NULL;
static httpd_handle_t stream_httpd = NULL;

#define PART_BOUNDARY "123456789000000000000987654321"
static const char* STREAM_CONTENT_TYPE =
  "multipart/x-mixed-replace;boundary=" PART_BOUNDARY;
static const char* STREAM_BOUNDARY = "\r\n--" PART_BOUNDARY "\r\n";
static const char* STREAM_PART =
  "Content-Type: image/jpeg\r\nContent-Length: %u\r\n\r\n";

// ==========================================================================
//  Camera initialisation
// ==========================================================================
bool initCamera() {
  camera_config_t config;
  config.ledc_channel = LEDC_CHANNEL_0;
  config.ledc_timer   = LEDC_TIMER_0;
  config.pin_d0       = Y2_GPIO_NUM;
  config.pin_d1       = Y3_GPIO_NUM;
  config.pin_d2       = Y4_GPIO_NUM;
  config.pin_d3       = Y5_GPIO_NUM;
  config.pin_d4       = Y6_GPIO_NUM;
  config.pin_d5       = Y7_GPIO_NUM;
  config.pin_d6       = Y8_GPIO_NUM;
  config.pin_d7       = Y9_GPIO_NUM;
  config.pin_xclk     = XCLK_GPIO_NUM;
  config.pin_pclk     = PCLK_GPIO_NUM;
  config.pin_vsync    = VSYNC_GPIO_NUM;
  config.pin_href     = HREF_GPIO_NUM;
  config.pin_sccb_sda = SIOD_GPIO_NUM;
  config.pin_sccb_scl = SIOC_GPIO_NUM;
  config.pin_pwdn     = PWDN_GPIO_NUM;
  config.pin_reset    = RESET_GPIO_NUM;
  config.xclk_freq_hz = 20000000;
  config.pixel_format = PIXFORMAT_JPEG;

  // Single frame buffer + LATEST grab mode avoids cam_hal: FB-OVF (frame
  // buffer overflow) errors that can hang /capture and / endpoints.
  config.fb_location = CAMERA_FB_IN_PSRAM;
  config.grab_mode   = CAMERA_GRAB_LATEST;
  config.fb_count    = 1;
  if (psramFound()) {
    config.frame_size   = FRAMESIZE_VGA;   // 640x480, good for QR
    config.jpeg_quality = 12;
  } else {
    config.frame_size   = FRAMESIZE_CIF;
    config.jpeg_quality = 15;
  }

  esp_err_t err = esp_camera_init(&config);
  if (err != ESP_OK) {
    Serial.printf("[Camera] init failed 0x%x\n", err);
    return false;
  }
  Serial.println("[Camera] initialised.");
  return true;
}

// ==========================================================================
//  HTTP handlers
// ==========================================================================
static esp_err_t captureHandler(httpd_req_t* req) {
  camera_fb_t* fb = esp_camera_fb_get();
  if (!fb) {
    httpd_resp_send_500(req);
    return ESP_FAIL;
  }
  httpd_resp_set_type(req, "image/jpeg");
  httpd_resp_set_hdr(req, "Content-Disposition",
                     "inline; filename=capture.jpg");
  httpd_resp_set_hdr(req, "Access-Control-Allow-Origin", "*");
  esp_err_t res = httpd_resp_send(req, (const char*)fb->buf, fb->len);
  esp_camera_fb_return(fb);
  return res;
}

static esp_err_t streamHandler(httpd_req_t* req) {
  esp_err_t res = httpd_resp_set_type(req, STREAM_CONTENT_TYPE);
  if (res != ESP_OK) return res;
  httpd_resp_set_hdr(req, "Access-Control-Allow-Origin", "*");

  char part[64];
  while (true) {
    camera_fb_t* fb = esp_camera_fb_get();
    if (!fb) { res = ESP_FAIL; break; }

    size_t hlen = snprintf(part, sizeof(part), STREAM_PART, fb->len);
    res  = httpd_resp_send_chunk(req, STREAM_BOUNDARY, strlen(STREAM_BOUNDARY));
    if (res == ESP_OK)
      res = httpd_resp_send_chunk(req, part, hlen);
    if (res == ESP_OK)
      res = httpd_resp_send_chunk(req, (const char*)fb->buf, fb->len);

    esp_camera_fb_return(fb);
    if (res != ESP_OK) break;     // client disconnected
  }
  return res;
}

static esp_err_t indexHandler(httpd_req_t* req) {
  static const char page[] =
    "<!DOCTYPE html><html><head><title>Smart Fridge Camera</title>"
    "<meta name='viewport' content='width=device-width,initial-scale=1'>"
    "<style>body{font-family:sans-serif;text-align:center;background:#111;"
    "color:#eee;margin:0;padding:16px}a{color:#4caf50}</style>"
    "</head><body><h2>Smart Fridge Camera</h2>"
    "<p>Stream is on port 81, capture is on port 80.</p>"
    "<p><a href='/capture'>/capture (single frame)</a></p>"
    "</body></html>";
  httpd_resp_set_type(req, "text/html");
  return httpd_resp_send(req, page, strlen(page));
}

void startCameraServer() {
  // Two HTTP server tasks so /stream (long-lived) cannot block /capture.
  // Port 80 -> /, /capture     (short requests)
  // Port 81 -> /stream         (long-lived MJPEG)
  httpd_config_t cfg = HTTPD_DEFAULT_CONFIG();
  cfg.server_port = 80;
  cfg.ctrl_port   = 32768;
  httpd_uri_t indexUri   = { "/",        HTTP_GET, indexHandler,   NULL };
  httpd_uri_t captureUri = { "/capture", HTTP_GET, captureHandler, NULL };
  if (httpd_start(&camera_httpd, &cfg) == ESP_OK) {
    httpd_register_uri_handler(camera_httpd, &indexUri);
    httpd_register_uri_handler(camera_httpd, &captureUri);
    Serial.println("[HTTP] port 80 (capture) started.");
  }

  cfg.server_port = 81;
  cfg.ctrl_port   = 32769;
  httpd_uri_t streamUri  = { "/stream",  HTTP_GET, streamHandler,  NULL };
  if (httpd_start(&stream_httpd, &cfg) == ESP_OK) {
    httpd_register_uri_handler(stream_httpd, &streamUri);
    Serial.println("[HTTP] port 81 (stream)  started.");
  }
}

// ==========================================================================
//  Wi-Fi
// ==========================================================================
void connectWiFi() {
  Serial.print("[WiFi] connecting to ");
  Serial.println(WIFI_SSID);
  WiFi.mode(WIFI_STA);
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);

  unsigned long start = millis();
  while (WiFi.status() != WL_CONNECTED && millis() - start < 20000UL) {
    delay(500);
    Serial.print(".");
  }
  Serial.println();
  if (WiFi.status() == WL_CONNECTED) {
    Serial.print("[WiFi] connected. IP: ");
    Serial.println(WiFi.localIP());
  } else {
    Serial.println("[WiFi] FAILED.");
  }
}

// ==========================================================================
//  Setup / loop
// ==========================================================================
void setup() {
  Serial.begin(115200);
  delay(300);
  Serial.println();
  Serial.println("=== Zero Waste Smart Fridge -- ESP32-CAM Camera Node ===");

  if (!initCamera()) {
    Serial.println("[FATAL] camera init failed. Check ribbon/power. Halting.");
    while (true) delay(1000);
  }

  connectWiFi();
  startCameraServer();

  if (WiFi.status() == WL_CONNECTED) {
    String ip = WiFi.localIP().toString();
    Serial.println();
    Serial.println("Camera Ready!");
    Serial.println("Local IP: " + ip);
    Serial.println("Stream:   http://" + ip + ":81/stream");
    Serial.println("Capture:  http://" + ip + "/capture");
    Serial.println();
    Serial.println(">> Enter this IP in the app's Camera screen.");
  }
}

void loop() {
  // Reconnect Wi-Fi if it drops.
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("[WiFi] lost -- reconnecting.");
    connectWiFi();
  }
  delay(2000);
}
