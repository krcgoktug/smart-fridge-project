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
 *  TWO JOBS:
 *  1. Every UPLOAD_INTERVAL it uploads sensor data + a simplified
 *     sensor-only risk score to:   /devices/<DEVICE_ID>/sensors
 *
 *  2. AUTOMATIC PRODUCT DETECTION (the primary registration trigger):
 *     It continuously watches the load-cell weight. When the weight
 *     changes by >= WEIGHT_EVENT_THRESHOLD grams and then stays stable
 *     for WEIGHT_STABLE_MS, it writes an event to:
 *           /devices/<DEVICE_ID>/detection
 *       - weight INCREASED -> { newProductDetected: true,  eventType: "added" }
 *       - weight DECREASED -> { newProductDetected: false, eventType: "removed" }
 *
 *     The Flutter app (or backend) listens for newProductDetected == true,
 *     calls the ESP32-CAM /capture endpoint, decodes the QR code, saves the
 *     product, and then resets newProductDetected back to false.
 *
 *     This board does NOT decode QR codes and does NOT take pictures.
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

// Sensor upload cadence.
#define UPLOAD_INTERVAL_MS        10000UL

// --- Automatic product detection (weight-change trigger) ---
// A change is only treated as a product event when it is at least this big.
#define WEIGHT_EVENT_THRESHOLD    50.0f    // grams
// Readings within this band of each other count as "the same" (noise).
#define WEIGHT_NOISE_BAND         20.0f    // grams
// The weight must hold steady this long before the event is accepted.
#define WEIGHT_STABLE_MS          4000UL   // 3-5 s recommended
// How often the weight is sampled for the detection logic.
#define WEIGHT_CHECK_INTERVAL_MS  1000UL

// Ideal cold-storage ranges (used by the sensor-side risk estimate).
#define TEMP_IDEAL_MIN   2.0f
#define TEMP_IDEAL_MAX   6.0f
#define HUM_IDEAL_MIN    50.0f
#define HUM_IDEAL_MAX    80.0f

// -------------------------- Globals ---------------------------------------
DHT dht(DHT_PIN, DHT_TYPE);
HX711 scale;

unsigned long lastUpload      = 0;
unsigned long lastWeightCheck = 0;

// Weight-change detection state.
float lastStableWeight   = 0.0f;  // last accepted stable weight level
float candidateWeight    = 0.0f;  // current candidate level being timed
unsigned long candidateSince = 0; // when the candidate level was first seen

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

// ==========================================================================
//  Generic Firebase Realtime Database REST PATCH helper
//  PATCH merges the given JSON into <path> without deleting siblings.
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

  // Arduino HTTPClient has no PATCH helper; sendRequest performs it.
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

// Weight in grams. Returns >= 0.
float readWeight() {
  if (!scale.is_ready()) {
    Serial.println("[HX711] not ready.");
    return lastStableWeight;          // fall back to last known good value
  }
  float w = scale.get_units(10);      // average of 10 reads
  if (w < 0) w = 0;                   // clamp small negative drift
  return w;
}

// ==========================================================================
//  AUTOMATIC PRODUCT DETECTION
//  Watches the load-cell weight and, on a stable significant change, writes
//  an event to /devices/<DEVICE_ID>/detection.
// ==========================================================================
void writeDetectionEvent(const char* eventType, int weightDelta,
                         int stableWeight, bool newProductDetected) {
  StaticJsonDocument<192> doc;
  doc["newProductDetected"] = newProductDetected;
  doc["eventType"]          = eventType;          // "added" | "removed"
  doc["weightDelta"]        = weightDelta;        // grams, signed
  doc["stableWeight"]       = stableWeight;       // grams
  doc["updatedAt"]          = (unsigned long)(millis() / 1000);

  String body;
  serializeJson(doc, body);

  String path = String("/devices/") + DEVICE_ID + "/detection";
  if (firebasePatch(path, body)) {
    Serial.printf("[Detect] event '%s' (delta %d g) sent.\n",
                  eventType, weightDelta);
  }
}

void checkWeightChange() {
  float w = readWeight();

  // If the reading moved away from the current candidate, start a new
  // candidate level and restart the stability timer.
  if (fabs(w - candidateWeight) > WEIGHT_NOISE_BAND) {
    candidateWeight = w;
    candidateSince  = millis();
    return;
  }

  // Reading is within the noise band of the candidate. Wait until it has
  // held steady long enough to be considered "stable".
  if (millis() - candidateSince < WEIGHT_STABLE_MS) return;

  // Stable. Compare against the last accepted stable level.
  float delta = candidateWeight - lastStableWeight;
  if (fabs(delta) < WEIGHT_EVENT_THRESHOLD) return;   // change too small

  if (delta > 0) {
    // Weight increased -> a product was placed. Ask the app to capture
    // an image and register it.
    Serial.printf("[Weight] product ADDED  (+%.0f g)\n", delta);
    writeDetectionEvent("added", (int)delta, (int)candidateWeight, true);
  } else {
    // Weight decreased -> a product was removed / consumed. No camera
    // capture needed, so newProductDetected stays false.
    Serial.printf("[Weight] product REMOVED (%.0f g)\n", delta);
    writeDetectionEvent("removed", (int)delta, (int)candidateWeight, false);
  }

  // Accept this as the new baseline so we do not fire again until the
  // weight settles at yet another level.
  lastStableWeight = candidateWeight;
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
  doc["riskScore"]   = riskScore;
  doc["status"]      = status;
  doc["updatedAt"]   = (unsigned long)(millis() / 1000);

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

  scale.begin(HX711_DT_PIN, HX711_SCK_PIN);
  scale.set_scale(HX711_CALIBRATION_FACTOR);
  scale.tare();                  // zero the empty box at startup
  Serial.println("[HX711] tared (empty box = 0 g).");

  // Detection baseline starts at the empty-box weight (0 g).
  lastStableWeight = 0.0f;
  candidateWeight  = 0.0f;
  candidateSince   = millis();

  connectWiFi();
  Serial.println("[Setup] done. Place a product on the scale to register it.");
  Serial.println("        MQ135 needs ~1-2 min to warm up.");
}

// ==========================================================================
//  Main loop
// ==========================================================================
void loop() {
  if (WiFi.status() != WL_CONNECTED) {
    connectWiFi();
  }

  unsigned long now = millis();

  // --- Automatic product detection (runs frequently) ---
  if (now - lastWeightCheck >= WEIGHT_CHECK_INTERVAL_MS) {
    lastWeightCheck = now;
    checkWeightChange();
  }

  // --- Periodic sensor upload ---
  if (now - lastUpload >= UPLOAD_INTERVAL_MS) {
    lastUpload = now;

    float temp   = readTemperature();
    float hum    = readHumidity();
    int   gas    = readGas();
    float weight = candidateWeight;          // latest known weight

    int   risk   = computeSensorRisk(temp, hum, gas);
    const char* status = statusFromScore(risk);

    Serial.printf("[Read] T=%.1fC  H=%.0f%%  Gas=%d  W=%.0fg  Risk=%d (%s)\n",
                  isnan(temp) ? 0 : temp, isnan(hum) ? 0 : hum,
                  gas, weight, risk, status);

    uploadSensors(temp, hum, gas, weight, risk, status);
  }

  delay(50);
}
