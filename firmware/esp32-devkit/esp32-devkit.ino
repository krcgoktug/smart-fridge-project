/*
 * ==========================================================================
 *  Zero Waste Smart Fridge  --  ESP32 DevKit  --  Sensor Controller
 * ==========================================================================
 *
 *  Reads three sensors and uploads their live values to Firebase Realtime
 *  Database every few seconds:
 *
 *    - DHT11 : temperature (C) + humidity (%)   GPIO 4
 *    - MQ135 : air-quality / gas (raw ADC)      GPIO 34
 *    - HX711 : weight (grams) from load cells   DT GPIO 16, SCK GPIO 17
 *
 *  Firebase path:  devices/fridge_01/sensors
 *    {
 *      "temperature": 6.4,
 *      "humidity":    73,
 *      "gasValue":    1350,
 *      "weight":      482,
 *      "updatedAt":   1710000000
 *    }
 *
 *  `updatedAt` is a real Unix timestamp (NTP). If the mobile app sees no
 *  update for 60 seconds it shows "ESP32 Sensor Board Offline".
 *
 *  This board does NOT do anything with the camera.
 *
 *  ------------------------------------------------------------------------
 *  REQUIRED LIBRARIES (Arduino Library Manager):
 *    - "DHT sensor library"      by Adafruit
 *    - "Adafruit Unified Sensor" by Adafruit
 *    - "HX711"                   by Bogdan Necula
 *    - "ArduinoJson"             by Benoit Blanchon (v6 or v7)
 *  Board: "ESP32 Dev Module".
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
#define MQ135_PIN      34       // ADC1, input-only
#define HX711_DT_PIN   16
#define HX711_SCK_PIN  17

// -------------------------- Tuning ----------------------------------------
#define HX711_CALIBRATION_FACTOR  420.0f    // raw / known grams
#define UPLOAD_INTERVAL_MS        5000UL    // upload every 5 s

// -------------------------- Globals ---------------------------------------
DHT dht(DHT_PIN, DHT_TYPE);
HX711 scale;

unsigned long lastUpload = 0;
bool hx711Ready = false;

// ==========================================================================
//  Wi-Fi -- connect and auto-reconnect
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
    Serial.println("[WiFi] FAILED -- will retry on the next cycle.");
  }
}

// Real Unix time (NTP). Falls back to uptime seconds before the first sync.
unsigned long nowEpoch() {
  time_t t = time(nullptr);
  if (t < 100000) return millis() / 1000;
  return (unsigned long)t;
}

// ==========================================================================
//  Sensor reads
// ==========================================================================
float readTemperature() {
  float t = dht.readTemperature();          // Celsius
  if (isnan(t)) {
    Serial.println("[DHT11] temperature read failed.");
    return 0;
  }
  return t;
}

float readHumidity() {
  float h = dht.readHumidity();             // percent
  if (isnan(h)) {
    Serial.println("[DHT11] humidity read failed.");
    return 0;
  }
  return h;
}

// MQ135 raw 12-bit ADC value (0..4095), averaged for stability.
int readGas() {
  long sum = 0;
  for (int i = 0; i < 16; i++) {
    sum += analogRead(MQ135_PIN);
    delay(5);
  }
  return (int)(sum / 16);
}

// Weight in grams. Returns 0 if no HX711 is connected.
float readWeight() {
  if (!hx711Ready || !scale.is_ready()) return 0.0f;
  float w = scale.get_units(10);
  return w < 0 ? 0 : w;
}

// ==========================================================================
//  Upload to Firebase Realtime Database (REST PATCH)
// ==========================================================================
bool uploadSensors(float temperature, float humidity, int gasValue,
                    float weight) {
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("[Upload] No Wi-Fi, skipping.");
    return false;
  }

  StaticJsonDocument<192> doc;
  doc["temperature"] = temperature;
  doc["humidity"]    = humidity;
  doc["gasValue"]    = gasValue;
  doc["weight"]      = (int)weight;
  doc["updatedAt"]   = nowEpoch();

  String body;
  serializeJson(doc, body);

  String url = String(FIREBASE_HOST) + "/devices/" + DEVICE_ID +
               "/sensors.json?auth=" + FIREBASE_AUTH;

  WiFiClientSecure client;
  client.setInsecure();              // skip cert validation (demo)

  HTTPClient http;
  if (!http.begin(client, url)) {
    Serial.println("[Upload] http.begin failed.");
    return false;
  }
  http.addHeader("Content-Type", "application/json");
  int code = http.sendRequest("PATCH", (uint8_t*)body.c_str(), body.length());
  http.end();

  if (code == HTTP_CODE_OK) {
    Serial.println("[Upload] OK -> devices/" DEVICE_ID "/sensors");
    return true;
  }
  Serial.printf("[Upload] failed, HTTP %d\n", code);
  return false;
}

// ==========================================================================
//  Setup
// ==========================================================================
void setup() {
  Serial.begin(115200);
  delay(300);
  Serial.println();
  Serial.println("=== Zero Waste Smart Fridge -- ESP32 Sensor Controller ===");

  analogReadResolution(12);
  analogSetPinAttenuation(MQ135_PIN, ADC_11db);

  dht.begin();

  // HX711 is optional: if it never becomes ready, weight is reported as 0.
  scale.begin(HX711_DT_PIN, HX711_SCK_PIN);
  unsigned long hxStart = millis();
  while (!scale.is_ready() && millis() - hxStart < 2000UL) delay(50);
  hx711Ready = scale.is_ready();
  if (hx711Ready) {
    scale.set_scale(HX711_CALIBRATION_FACTOR);
    scale.tare();
    Serial.println("[HX711] connected and tared.");
  } else {
    Serial.println("[HX711] not detected -- weight = 0 g.");
  }

  connectWiFi();
  configTime(0, 0, "pool.ntp.org", "time.nist.gov");   // real timestamps

  Serial.println("[Setup] done. Uploading sensor data to Firebase.");
}

// ==========================================================================
//  Main loop
// ==========================================================================
void loop() {
  if (WiFi.status() != WL_CONNECTED) {
    connectWiFi();                   // reconnect handling
  }

  unsigned long now = millis();
  if (now - lastUpload >= UPLOAD_INTERVAL_MS) {
    lastUpload = now;

    float temperature = readTemperature();
    float humidity    = readHumidity();
    int   gasValue    = readGas();
    float weight      = readWeight();

    Serial.printf("[Read] T=%.1fC  H=%.0f%%  Gas=%d  W=%.0fg\n",
                  temperature, humidity, gasValue, weight);

    uploadSensors(temperature, humidity, gasValue, weight);
  }

  delay(50);
}
