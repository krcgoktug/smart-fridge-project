/*
 * ==========================================================================
 *  Zero Waste Smart Fridge  --  ESP32 DevKit V1  --  Sensor Node
 * ==========================================================================
 *
 *  Reads:
 *    - DHT11   : temperature + humidity     (GPIO 4)
 *    - MQ135   : gas / air quality (analog) (GPIO 34)
 *    - HX711   : weight from 4 load cells   (DT GPIO 16, SCK GPIO 17)
 *
 *  Uploads the readings + a simplified sensor-only risk score every
 *  UPLOAD_INTERVAL to:   /devices/<DEVICE_ID>/sensors
 *
 *  IMPORTANT - this board is an INDEPENDENT, OPTIONAL sensor node:
 *    - It does NOT trigger the camera and does NOT drive product
 *      registration. The load cells are just one more sensor reading.
 *    - If this board is offline the rest of the system keeps working:
 *      the app detects stale `updatedAt` and shows "ESP32 not connected".
 *    - `updatedAt` is a real Unix timestamp (NTP) so the app can reliably
 *      decide whether the sensor data is fresh.
 *
 *  ------------------------------------------------------------------------
 *  REQUIRED LIBRARIES (Arduino Library Manager):
 *    - "DHT sensor library"        by Adafruit
 *    - "Adafruit Unified Sensor"   by Adafruit (dependency of the above)
 *    - "HX711"                     by Bogdan Necula
 *    - "ArduinoJson"               by Benoit Blanchon (v6 or v7)
 *  Board package: "esp32" by Espressif. Select board: "ESP32 Dev Module".
 *
 *  WIRING: see docs/wiring.md
 *  CONFIG: copy secrets.example.h -> secrets.h and fill it in.
 * ==========================================================================
 */

#include <WiFi.h>
#include <HTTPClient.h>
#include <WiFiClientSecure.h>
#include <ArduinoJson.h>
#include <DHT.h>
#include <HX711.h>
#include <time.h>

#include "secrets.h"   // copy from secrets.example.h (git-ignored)

// -------------------------- Pin configuration ----------------------------
#define DHT_PIN        4
#define DHT_TYPE       DHT11
#define MQ135_PIN      34      // ADC1, input-only pin
#define HX711_DT_PIN   16
#define HX711_SCK_PIN  17

// -------------------------- Tuning constants ------------------------------
// HX711 calibration: raw_value / KNOWN_GRAMS. Calibrate with a known weight.
#define HX711_CALIBRATION_FACTOR  420.0f

// How often to read sensors and upload (milliseconds).
#define UPLOAD_INTERVAL_MS        10000UL

// Ideal cold-storage ranges (used by the sensor-side risk estimate).
#define TEMP_IDEAL_MIN   2.0f
#define TEMP_IDEAL_MAX   6.0f
#define HUM_IDEAL_MIN    50.0f
#define HUM_IDEAL_MAX    80.0f

// -------------------------- Globals ---------------------------------------
DHT dht(DHT_PIN, DHT_TYPE);
HX711 scale;

unsigned long lastUpload = 0;
bool hx711Available = false;   // the system still works without load cells

// ==========================================================================
//  Wi-Fi
// ==========================================================================
void connectWiFi() {
  if (WiFi.status() == WL_CONNECTED) return;

  Serial.print("[WiFi] Connecting to ");
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
    Serial.print("[WiFi] Connected. IP: ");
    Serial.println(WiFi.localIP());
  } else {
    Serial.println("[WiFi] FAILED -- will retry next cycle.");
  }
}

// Real Unix time from NTP. Falls back to uptime seconds before the first
// sync so `updatedAt` is never zero.
unsigned long nowEpoch() {
  time_t t = time(nullptr);
  if (t < 100000) return millis() / 1000;   // NTP not synced yet
  return (unsigned long)t;
}

// ==========================================================================
//  Generic Firebase Realtime Database REST PATCH helper
// ==========================================================================
bool firebasePatch(const String& path, const String& body) {
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("[Firebase] No Wi-Fi, skipping write.");
    return false;
  }

  String url = String(FIREBASE_HOST) + path + ".json?auth=" + FIREBASE_AUTH;

  WiFiClientSecure client;
  client.setInsecure();          // skip cert validation (demo simplicity)

  HTTPClient http;
  if (!http.begin(client, url)) {
    Serial.println("[Firebase] http.begin failed.");
    return false;
  }
  http.addHeader("Content-Type", "application/json");

  int code = http.sendRequest("PATCH", (uint8_t*)body.c_str(), body.length());
  bool ok = (code == HTTP_CODE_OK);
  if (!ok) {
    Serial.print("[Firebase] PATCH ");
    Serial.print(path);
    Serial.print(" failed, HTTP ");
    Serial.println(code);
  }
  http.end();
  return ok;
}

// ==========================================================================
//  Sensor reads
// ==========================================================================
float readTemperature() {
  float t = dht.readTemperature();          // Celsius
  if (isnan(t)) {
    Serial.println("[DHT11] temperature read failed.");
    return NAN;
  }
  return t;
}

float readHumidity() {
  float h = dht.readHumidity();             // percent
  if (isnan(h)) {
    Serial.println("[DHT11] humidity read failed.");
    return NAN;
  }
  return h;
}

// MQ135: raw 12-bit ADC reading (0..4095). Averaged for stability.
int readGas() {
  long sum = 0;
  const int samples = 16;
  for (int i = 0; i < samples; i++) {
    sum += analogRead(MQ135_PIN);
    delay(5);
  }
  return (int)(sum / samples);
}

// Weight in grams. Returns 0 when no HX711 is connected (optional sensor).
float readWeight() {
  if (!hx711Available || !scale.is_ready()) return 0.0f;
  float w = scale.get_units(10);            // average of 10 reads
  if (w < 0) w = 0;                         // clamp small negative drift
  return w;
}

// ==========================================================================
//  Sensor-only risk estimate (0..100). The app computes the full score.
// ==========================================================================
int computeSensorRisk(float temp, float hum, int gas) {
  int risk = 0;

  if (!isnan(temp)) {
    float dev = 0;
    if (temp < TEMP_IDEAL_MIN) dev = TEMP_IDEAL_MIN - temp;
    else if (temp > TEMP_IDEAL_MAX) dev = temp - TEMP_IDEAL_MAX;
    int tRisk = (int)(dev * 4.0f);
    if (tRisk > 20) tRisk = 20;
    risk += tRisk;
  }

  if (!isnan(hum)) {
    float dev = 0;
    if (hum < HUM_IDEAL_MIN) dev = HUM_IDEAL_MIN - hum;
    else if (hum > HUM_IDEAL_MAX) dev = hum - HUM_IDEAL_MAX;
    int hRisk = (int)dev;
    if (hRisk > 15) hRisk = 15;
    risk += hRisk;
  }

  int gRisk = 0;
  if (gas >= 2500)      gRisk = 25;
  else if (gas >= 2000) gRisk = 21;
  else if (gas >= 1500) gRisk = 16;
  else if (gas >= 1000) gRisk = 9;
  risk += gRisk;

  if (risk > 100) risk = 100;
  return risk;
}

const char* statusFromScore(int score) {
  if (score >= 70) return "Spoilage Risk";
  if (score >= 40) return "Consume Soon";
  return "Fresh";
}

// ==========================================================================
//  Upload sensor data to /devices/<DEVICE_ID>/sensors
// ==========================================================================
bool uploadSensors(float temp, float hum, int gas, float weight,
                    int riskScore, const char* status) {
  StaticJsonDocument<256> doc;
  doc["temperature"] = isnan(temp) ? 0 : temp;
  doc["humidity"]    = isnan(hum)  ? 0 : hum;
  doc["gasValue"]    = gas;
  doc["weight"]      = (int)weight;
  doc["hasLoadCell"] = hx711Available;
  doc["riskScore"]   = riskScore;
  doc["status"]      = status;
  doc["updatedAt"]   = nowEpoch();           // real Unix time (NTP)

  String body;
  serializeJson(doc, body);

  String path = String("/devices/") + DEVICE_ID + "/sensors";
  bool ok = firebasePatch(path, body);
  if (ok) Serial.println("[Upload] sensors OK.");
  return ok;
}

// ==========================================================================
//  Setup
// ==========================================================================
void setup() {
  Serial.begin(115200);
  delay(300);
  Serial.println();
  Serial.println("=== Zero Waste Smart Fridge -- ESP32 Sensor Node ===");

  // ADC: 12-bit, full 0..3.3V range for the MQ135.
  analogReadResolution(12);
  analogSetPinAttenuation(MQ135_PIN, ADC_11db);

  dht.begin();

  // HX711 is OPTIONAL. If it never becomes ready, weight is reported as 0
  // and the rest of the system carries on normally.
  scale.begin(HX711_DT_PIN, HX711_SCK_PIN);
  unsigned long hxStart = millis();
  while (!scale.is_ready() && millis() - hxStart < 2000UL) {
    delay(50);
  }
  hx711Available = scale.is_ready();
  if (hx711Available) {
    scale.set_scale(HX711_CALIBRATION_FACTOR);
    scale.tare();
    Serial.println("[HX711] connected and tared (empty box = 0 g).");
  } else {
    Serial.println("[HX711] not detected -- weight reported as 0 g.");
  }

  connectWiFi();

  // NTP so `updatedAt` is a real timestamp (UTC).
  configTime(0, 0, "pool.ntp.org", "time.nist.gov");
  Serial.println("[Setup] done. MQ135 needs ~1-2 min to warm up.");
}

// ==========================================================================
//  Main loop
// ==========================================================================
void loop() {
  if (WiFi.status() != WL_CONNECTED) {
    connectWiFi();
  }

  unsigned long now = millis();
  if (now - lastUpload >= UPLOAD_INTERVAL_MS) {
    lastUpload = now;

    float temp   = readTemperature();
    float hum    = readHumidity();
    int   gas    = readGas();
    float weight = readWeight();

    int   risk   = computeSensorRisk(temp, hum, gas);
    const char* status = statusFromScore(risk);

    Serial.printf("[Read] T=%.1fC  H=%.0f%%  Gas=%d  W=%.0fg  Risk=%d (%s)\n",
                  isnan(temp) ? 0 : temp, isnan(hum) ? 0 : hum,
                  gas, weight, risk, status);

    uploadSensors(temp, hum, gas, weight, risk, status);
  }

  delay(50);
}
