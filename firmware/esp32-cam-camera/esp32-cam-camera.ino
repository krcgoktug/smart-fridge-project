/*
 * ==========================================================================
 *  Zero Waste Smart Fridge  --  ESP32-CAM AI-Thinker  --  Camera Node
 * ==========================================================================
 *
 *  PURPOSE: serve images of the box interior. NOTHING ELSE.
 *  This board does NOT decode QR codes and does NOT run image analysis --
 *  it only exposes a camera web server. Decoding/analysis happens in the
 *  mobile app or the optional Python backend.
 *
 *  ENDPOINTS (once running, at the IP printed on the serial monitor):
 *    GET /          -> simple HTML page with a live MJPEG stream
 *    GET /stream    -> raw multipart MJPEG stream
 *    GET /capture   -> a single JPEG frame
 *
 *  It also (optionally) writes its own streamUrl/captureUrl to Firebase:
 *      /devices/<DEVICE_ID>/camera
 *
 *  ------------------------------------------------------------------------
 *  BOARD: "AI Thinker ESP32-CAM"   (Tools -> Board)
 *  PSRAM: enabled (default for this board)
 *  No external libraries needed beyond the esp32 board package + ArduinoJson.
 *    - "ArduinoJson" by Benoit Blanchon (only used for the optional upload)
 *
 *  FLASHING: ESP32-CAM has no USB. Use an FTDI/USB-TTL adapter at 3.3V,
 *  jumper GPIO0 -> GND to enter flash mode, then remove it and reset.
 *  See docs/wiring.md.
 *
 *  CONFIG: copy cam_secrets.example.h -> cam_secrets.h and fill it in.
 * ==========================================================================
 */

#include <WiFi.h>
#include <HTTPClient.h>
#include <WiFiClientSecure.h>
#include <ArduinoJson.h>
#include <time.h>
#include "esp_camera.h"
#include "esp_http_server.h"

#include "camera_pins.h"
#include "cam_secrets.h"   // copy from cam_secrets.example.h (git-ignored)

// Set to false if you do not want the board to touch Firebase at all.
#define WRITE_URLS_TO_FIREBASE  true

static httpd_handle_t camera_httpd = NULL;

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

  // PSRAM present on the AI-Thinker board -> use a larger frame + 2 buffers.
  if (psramFound()) {
    config.frame_size   = FRAMESIZE_VGA;   // 640x480, good for browning CV
    config.jpeg_quality = 12;              // lower number = better quality
    config.fb_count     = 2;
  } else {
    config.frame_size   = FRAMESIZE_CIF;   // 400x296 fallback
    config.jpeg_quality = 15;
    config.fb_count     = 1;
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

// GET /capture  -> a single JPEG frame.
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

// GET /stream  -> continuous MJPEG.
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

// GET /  -> minimal HTML page embedding the stream.
static esp_err_t indexHandler(httpd_req_t* req) {
  static const char page[] =
    "<!DOCTYPE html><html><head><title>Smart Fridge Camera</title>"
    "<meta name='viewport' content='width=device-width,initial-scale=1'>"
    "<style>body{font-family:sans-serif;text-align:center;background:#111;"
    "color:#eee;margin:0;padding:16px}img{max-width:100%;border-radius:8px}"
    "</style></head><body><h2>Zero Waste Smart Fridge</h2>"
    "<p>Live box camera</p><img src='/stream'>"
    "<p><a style='color:#4caf50' href='/capture'>/capture</a> "
    "for a single frame</p></body></html>";
  httpd_resp_set_type(req, "text/html");
  return httpd_resp_send(req, page, strlen(page));
}

void startCameraServer() {
  httpd_config_t config = HTTPD_DEFAULT_CONFIG();
  config.server_port = 80;

  httpd_uri_t indexUri   = { "/",        HTTP_GET, indexHandler,   NULL };
  httpd_uri_t streamUri  = { "/stream",  HTTP_GET, streamHandler,  NULL };
  httpd_uri_t captureUri = { "/capture", HTTP_GET, captureHandler, NULL };

  if (httpd_start(&camera_httpd, &config) == ESP_OK) {
    httpd_register_uri_handler(camera_httpd, &indexUri);
    httpd_register_uri_handler(camera_httpd, &streamUri);
    httpd_register_uri_handler(camera_httpd, &captureUri);
    Serial.println("[HTTP] camera server started on port 80.");
  } else {
    Serial.println("[HTTP] failed to start camera server.");
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

// Real Unix time from NTP; falls back to uptime seconds before first sync.
unsigned long nowEpoch() {
  time_t t = time(nullptr);
  if (t < 100000) return millis() / 1000;
  return (unsigned long)t;
}

// ==========================================================================
//  Optional: publish the camera URLs to Firebase
// ==========================================================================
void publishCameraUrls() {
  if (!WRITE_URLS_TO_FIREBASE) return;
  if (WiFi.status() != WL_CONNECTED) return;

  String ip = WiFi.localIP().toString();
  String streamUrl  = "http://" + ip;
  String captureUrl = "http://" + ip + "/capture";

  StaticJsonDocument<192> doc;
  doc["streamUrl"]  = streamUrl;
  doc["captureUrl"] = captureUrl;
  doc["updatedAt"]  = nowEpoch();

  String body;
  serializeJson(doc, body);

  String url = String(FIREBASE_HOST) + "/devices/" + DEVICE_ID +
               "/camera.json?auth=" + FIREBASE_AUTH;

  WiFiClientSecure client;
  client.setInsecure();

  HTTPClient http;
  if (!http.begin(client, url)) {
    Serial.println("[Firebase] http.begin failed.");
    return;
  }
  http.addHeader("Content-Type", "application/json");
  int code = http.sendRequest("PATCH", (uint8_t*)body.c_str(), body.length());
  if (code == HTTP_CODE_OK) {
    Serial.println("[Firebase] camera URLs published.");
  } else {
    Serial.printf("[Firebase] PATCH failed: %d\n", code);
  }
  http.end();
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
  configTime(0, 0, "pool.ntp.org", "time.nist.gov");  // real timestamps
  startCameraServer();
  publishCameraUrls();

  if (WiFi.status() == WL_CONNECTED) {
    Serial.print("[Ready] open  http://");
    Serial.println(WiFi.localIP());
    Serial.print("[Ready] capture http://");
    Serial.print(WiFi.localIP());
    Serial.println("/capture");
  }
}

void loop() {
  // Reconnect Wi-Fi if it drops, and re-publish the URLs (IP may change).
  static unsigned long lastCheck = 0;
  if (millis() - lastCheck > 30000UL) {
    lastCheck = millis();
    if (WiFi.status() != WL_CONNECTED) {
      Serial.println("[WiFi] lost -- reconnecting.");
      connectWiFi();
      publishCameraUrls();
    }
  }
  delay(200);
}
