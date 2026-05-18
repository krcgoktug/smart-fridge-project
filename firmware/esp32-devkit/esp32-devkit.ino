/*
 * ==========================================================================
 *  Zero Waste Smart Fridge  --  ESP32 DevKit V1  --  Sensor Controller
 * ==========================================================================
 *
 *  This board is the SENSOR CONTROLLER only. It does NOT touch the camera
 *  and does NOT do any QR or image processing.
 *
 *  Every 10 seconds it reads the sensors and pushes a heartbeat to
 *  Firebase Realtime Database:
 *
 *      devices/fridge_01/sensors
 *      {
 *        "weight":      <grams>,
 *        "temperature": <Celsius>,
 *        "humidity":    <percent>,
 *        "gas":         <MQ135 raw ADC>,
 *        "updatedAt":   <Unix seconds, NTP>,
 *        "alive":       true
 *      }
 *
 *  The Flutter app treats the board as OFFLINE when `updatedAt` is older
 *  than 60 seconds.
 *
 *  Sensors:
 *    - HX711 + load cell  : weight                 (DT GPIO 16, SCK GPIO 17)
 *    - DHT11              : temperature + humidity  (GPIO 4)
 *    - MQ135              : gas / air               (GPIO 34, analog)
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
#define MQ135_PIN      34      // ADC1, input-only pin
#define HX711_DT_PIN   16
#define HX711_SCK_PIN  17

// -------------------------- Tuning constants ------------------------------
#define HX711_CALIBRATION_FACTOR  420.0f   // raw / known grams
#define HEARTBEAT_INTERVAL_MS     10000UL  // send every 10 s

// -------------------------- Globals ---------------------------------------
DHT dht(DHT_PIN, DHT_TYPE);
HX711 scale;

unsigned long lastHeartbeat = 0;
bool hx711Available = false;

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

// Real Unix time from NTP; uptime seconds as a fallback before first sync.
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

int readGas() {
  long sum = 0;
  for (int i = 0; i < 16; i++) {
    sum += analogRead(MQ135_PIN);
    delay(5);
  }
  return (int)(sum / 16);
}

float readWeight() {
  if (!hx711Available || !scale.is_ready()) return 0.0f;
  float w = scale.get_units(10);
  return w < 0 ? 0 : w;
}

// ==========================================================================
//  Heartbeat -> Firebase Realtime Database (REST PATCH)
// ==========================================================================
bool sendHeartbeat(float weight, float temperature, float humidity, int gas) {
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("[Firebase] No Wi-Fi, skipping heartbeat.");
    return false;
  }

  StaticJsonDocument<256> doc;
  doc["weight"]      = (int)weight;
  doc["temperature"] = temperature;
  doc["humidity"]    = humidity;
  doc["gas"]         = gas;
  doc["updatedAt"]   = nowEpoch();
  doc["alive"]       = true;

  String body;
  serializeJson(doc, body);

  String url = String(FIREBASE_HOST) + "/devices/" + DEVICE_ID +
               "/sensors.json?auth=" + FIREBASE_AUTH;

  WiFiClientSecure client;
  client.setInsecure();                  // skip cert validation (demo)

  HTTPClient http;
  if (!http.begin(client, url)) {
    Serial.println("[Firebase] http.begin failed.");
    return false;
  }
  http.addHeader("Content-Type", "application/json");
  int code = http.sendRequest("PATCH", (uint8_t*)body.c_str(), body.length());
  http.end();

  bool ok = (code == HTTP_CODE_OK);
  if (ok) {
    Serial.println("[Heartbeat] sent -> devices/" DEVICE_ID "/sensors");
  } else {
    Serial.printf("[Heartbeat] failed, HTTP %d\n", code);
  }
  return ok;
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
  hx711Available = scale.is_ready();
  if (hx711Available) {
    scale.set_scale(HX711_CALIBRATION_FACTOR);
    scale.tare();
    Serial.println("[HX711] connected and tared.");
  } else {
    Serial.println("[HX711] not detected -- weight = 0 g.");
  }

  connectWiFi();
  configTime(0, 0, "pool.ntp.org", "time.nist.gov");   // real timestamps
  Serial.println("[Setup] done. Sending a heartbeat every 10 s.");
}

// ==========================================================================
//  Main loop
// ==========================================================================
void loop() {
  if (WiFi.status() != WL_CONNECTED) connectWiFi();

  unsigned long now = millis();
  if (now - lastHeartbeat >= HEARTBEAT_INTERVAL_MS) {
    lastHeartbeat = now;

    float weight = readWeight();
    float temp   = readTemperature();
    float hum    = readHumidity();
    int   gas    = readGas();

    Serial.printf("[Read] W=%.0fg  T=%.1fC  H=%.0f%%  Gas=%d\n",
                  weight, temp, hum, gas);
    sendHeartbeat(weight, temp, hum, gas);
  }

  delay(50);
}
