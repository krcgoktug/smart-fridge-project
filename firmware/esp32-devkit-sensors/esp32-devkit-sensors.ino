/*
 * ==========================================================================
 *  Zero Waste Smart Fridge  --  ESP32 DevKit V1  --  Sensor Node
 * ==========================================================================
 *
 *  Reads:
 *    - DHT11   : temperature + humidity   (GPIO 4)
 *    - MQ135   : gas / air quality (analog) (GPIO 34)
 *    - HX711   : weight from 4 load cells  (DT GPIO 16, SCK GPIO 17)
 *
 *  Computes a simplified SENSOR-ONLY risk score and uploads everything as
 *  JSON to Firebase Realtime Database at:
 *      /devices/<DEVICE_ID>/sensors
 *
 *  The full per-product risk score is computed by the mobile app; this
 *  firmware only contributes the environmental part as a fallback.
 *
 *  ------------------------------------------------------------------------
 *  REQUIRED LIBRARIES (Arduino Library Manager):
 *    - "DHT sensor library"        by Adafruit
 *    - "Adafruit Unified Sensor"   by Adafruit (dependency of the above)
 *    - "HX711"                     by Bogdan Necula  (Rob Tillaart's also OK*)
 *    - "ArduinoJson"               by Benoit Blanchon (v6 or v7)
 *  Board package: "esp32" by Espressif. Select board: "ESP32 Dev Module".
 *
 *  *If you use a different HX711 library, adapt the begin()/read calls.
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
// HX711 calibration: raw_value / KNOWN_GRAMS. Calibrate with a known weight,
// then replace this number. Positive or negative sign depends on wiring.
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
    return 0.0f;
  }
  float w = scale.get_units(10);            // average of 10 reads
  if (w < 0) w = 0;                         // clamp small negative drift
  return w;
}

// ==========================================================================
//  Sensor-only risk estimate (0..100). The app computes the full score.
// ==========================================================================
int computeSensorRisk(float temp, float hum, int gas) {
  int risk = 0;

  // Temperature deviation from the ideal cold range: +4 per degree, max 20.
  if (!isnan(temp)) {
    float dev = 0;
    if (temp < TEMP_IDEAL_MIN) dev = TEMP_IDEAL_MIN - temp;
    else if (temp > TEMP_IDEAL_MAX) dev = temp - TEMP_IDEAL_MAX;
    int tRisk = (int)(dev * 4.0f);
    if (tRisk > 20) tRisk = 20;
    risk += tRisk;
  }

  // Humidity deviation: +1 per percent outside the ideal band, max 15.
  if (!isnan(hum)) {
    float dev = 0;
    if (hum < HUM_IDEAL_MIN) dev = HUM_IDEAL_MIN - hum;
    else if (hum > HUM_IDEAL_MAX) dev = hum - HUM_IDEAL_MAX;
    int hRisk = (int)dev;
    if (hRisk > 15) hRisk = 15;
    risk += hRisk;
  }

  // Gas: MQ135 raw reading bands, max 25.
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
//  Upload to Firebase Realtime Database via REST (PATCH .../sensors.json)
// ==========================================================================
bool uploadSensors(float temp, float hum, int gas, float weight,
                    int riskScore, const char* status) {
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("[Upload] No Wi-Fi, skipping.");
    return false;
  }

  // Build JSON payload.
  StaticJsonDocument<256> doc;
  doc["temperature"] = isnan(temp) ? 0 : temp;
  doc["humidity"]    = isnan(hum)  ? 0 : hum;
  doc["gasValue"]    = gas;
  doc["weight"]      = (int)weight;
  doc["riskScore"]   = riskScore;
  doc["status"]      = status;
  doc["updatedAt"]   = (unsigned long)(millis() / 1000); // relative seconds

  String body;
  serializeJson(doc, body);

  // PATCH merges fields without deleting siblings.
  String url = String(FIREBASE_HOST) + "/devices/" + DEVICE_ID +
               "/sensors.json?auth=" + FIREBASE_AUTH;

  WiFiClientSecure client;
  client.setInsecure();          // skip cert validation (demo simplicity)

  HTTPClient http;
  if (!http.begin(client, url)) {
    Serial.println("[Upload] http.begin failed.");
    return false;
  }
  http.addHeader("Content-Type", "application/json");

  // Arduino's HTTPClient has no PATCH helper; sendRequest does it.
  int code = http.sendRequest("PATCH", (uint8_t*)body.c_str(), body.length());

  bool ok = (code == HTTP_CODE_OK);
  if (ok) {
    Serial.println("[Upload] OK -> /devices/" DEVICE_ID "/sensors");
  } else {
    Serial.print("[Upload] HTTP error: ");
    Serial.println(code);
    Serial.println(http.getString());
  }
  http.end();
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

  connectWiFi();
  Serial.println("[Setup] done. MQ135 needs ~1-2 min to warm up.");
}

// ==========================================================================
//  Main loop
// ==========================================================================
void loop() {
  // Keep Wi-Fi alive; reconnect if dropped.
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
