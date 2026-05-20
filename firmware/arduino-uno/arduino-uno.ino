// =====================================================================
//  Zero Waste Smart Fridge - Arduino Uno sensor node
// =====================================================================
//
//  All three sensors + an alarm LED on a single Arduino Uno. Every two
//  seconds the sketch prints a human-readable block and one JSON line:
//
//    {"temperature":24.3,"humidity":45,"gasValue":312,"weight":12.34,
//     "riskScore":40}
//
//  The Python bridge (bridge/arduino_serial_bridge.py) parses the JSON
//  line and serves it on http://localhost:8787/sensors so the Flutter
//  app can show the live values.
//
//  Wiring:
//    DHT11   DATA  -> D3      (VCC -> 5 V, GND -> GND)
//    MQ135   AOUT  -> A0      (VCC -> 5 V, GND -> GND)
//    HX711   DT    -> D4      (VCC -> 5 V, GND -> GND)
//    HX711   SCK   -> D5
//    LED     +     -> D9      (through a 330 ohm resistor to GND)
//
//  Libraries (Library Manager):
//    - "DHT sensor library" by Adafruit (pulls Adafruit Unified Sensor)
//    - "HX711 Arduino Library" by Bogdan Necula
//
//  Serial console (also accepts commands):
//    t / T  -> re-tare the HX711
//    l / L  -> toggle the LED for a quick wiring test
//
//  Baud rate: 9600 (matches the Python bridge default).
// =====================================================================

#include <DHT.h>
#include "HX711.h"

// ===================== PINS =====================
#define DHTPIN          3
#define DHTTYPE         DHT11
#define MQ135_PIN       A0
#define HX711_DT_PIN    4
#define HX711_SCK_PIN   5
#define LED_PIN         9

// ===================== OBJECTS =====================
DHT   dht(DHTPIN, DHTTYPE);
HX711 scale;

// ===================== SETTINGS =====================
const int SAMPLE_COUNT = 30;

// MQ135 baseline (taken in setup() while the air is clean).
int mq135Baseline = 0;

// HX711 calibration. Place a known mass and tune until the readings
// match the actual grams. If the weight comes out negative, flip the
// sign here.
float calibration_factor = 420.5;

// Reporting cadence.
unsigned long lastReadTime = 0;
const unsigned long READ_INTERVAL = 2000;

// ===================== MEDIAN FILTER =====================
int getMedian(int arr[], int size) {
  int temp[size];
  for (int i = 0; i < size; i++) temp[i] = arr[i];
  for (int i = 0; i < size - 1; i++) {
    for (int j = i + 1; j < size; j++) {
      if (temp[j] < temp[i]) {
        int t  = temp[i];
        temp[i] = temp[j];
        temp[j] = t;
      }
    }
  }
  return temp[size / 2];
}

// ===================== MQ135 BASELINE =====================
int calculateMQ135Baseline() {
  long total = 0;
  Serial.println(F("MQ135 baseline aliniyor..."));
  Serial.println(F("Lutfen sensoru temiz ortamda 5 saniye bekletin."));
  delay(5000);
  for (int i = 0; i < 100; i++) {
    total += analogRead(MQ135_PIN);
    delay(50);
  }
  int baseline = total / 100;
  Serial.print(F("MQ135 baseline: "));
  Serial.println(baseline);
  return baseline;
}

// ===================== DHT11 READ =====================
bool readDHT11(float &temperature, float &humidity) {
  float tempTotal = 0;
  float humTotal  = 0;
  int   valid     = 0;
  for (int i = 0; i < 10; i++) {
    float t = dht.readTemperature();
    float h = dht.readHumidity();
    if (!isnan(t) && !isnan(h)) {
      tempTotal += t;
      humTotal  += h;
      valid++;
    }
    delay(100);
  }
  if (valid > 0) {
    temperature = tempTotal / valid;
    humidity    = humTotal  / valid;
    return true;
  }
  temperature = -999;
  humidity    = -999;
  return false;
}

// ===================== MQ135 READ =====================
int readMQ135Filtered() {
  int samples[SAMPLE_COUNT];
  for (int i = 0; i < SAMPLE_COUNT; i++) {
    samples[i] = analogRead(MQ135_PIN);
    delay(10);
  }
  int medianValue  = getMedian(samples, SAMPLE_COUNT);
  long gasTotal    = 0;
  for (int i = 0; i < SAMPLE_COUNT; i++) gasTotal += samples[i];
  int averageValue = gasTotal / SAMPLE_COUNT;
  int gasValue     = (medianValue + averageValue) / 2;
  // Amplify deviation from baseline so the dashboard reacts visibly.
  int sensitive    = mq135Baseline + ((gasValue - mq135Baseline) * 3);
  return sensitive;
}

// ===================== HX711 READ =====================
float readWeight() {
  if (!scale.is_ready()) return -999;
  float w = scale.get_units(10);
  if (abs(w) < 2.0) w = 0;     // squash sub-2 g noise to a clean 0
  return w;
}

// ===================== SIMPLE RISK SCORE =====================
int calculateRiskScore(float temperature, float humidity, int gasValue) {
  int risk = 0;
  if      (temperature > 30) risk += 20;
  else if (temperature > 25) risk += 10;

  if      (humidity > 80)    risk += 20;
  else if (humidity > 65)    risk += 10;

  int gasDiff = gasValue - mq135Baseline;
  if      (gasDiff > 250)    risk += 40;
  else if (gasDiff > 120)    risk += 20;
  else if (gasDiff > 60)     risk += 10;

  if (risk > 100) risk = 100;
  if (risk < 0)   risk = 0;
  return risk;
}

// ===================== SETUP =====================
void setup() {
  Serial.begin(9600);
  pinMode(LED_PIN, OUTPUT);
  digitalWrite(LED_PIN, LOW);

  dht.begin();
  scale.begin(HX711_DT_PIN, HX711_SCK_PIN);
  scale.set_scale(calibration_factor);

  Serial.println(F("Zero Waste Smart Fridge - Arduino UNO Sensor System"));
  Serial.println(F("---------------------------------------------------"));
  Serial.println(F("Tartiyi BOS birakin, dara aliniyor..."));
  delay(3000);
  scale.tare();
  Serial.println(F("Dara alindi."));

  mq135Baseline = calculateMQ135Baseline();

  Serial.println(F("Sistem hazir."));
  Serial.println(F("Komutlar:"));
  Serial.println(F("  t/T = HX711 dara al"));
  Serial.println(F("  l/L = LED ac/kapat test"));
  Serial.println();
}

// ===================== LOOP =====================
void loop() {
  // ----- serial commands -----
  if (Serial.available()) {
    char cmd = Serial.read();
    if (cmd == 't' || cmd == 'T') {
      scale.tare();
      Serial.println(F(">> Dara yeniden alindi <<"));
    }
    if (cmd == 'l' || cmd == 'L') {
      digitalWrite(LED_PIN, !digitalRead(LED_PIN));
      Serial.print(F(">> LED durumu: "));
      Serial.println(digitalRead(LED_PIN) ? F("ON") : F("OFF"));
    }
  }

  const unsigned long now = millis();
  if (now - lastReadTime < READ_INTERVAL) return;
  lastReadTime = now;

  float temperature = 0;
  float humidity    = 0;
  bool  dhtOk       = readDHT11(temperature, humidity);
  int   gasValue    = readMQ135Filtered();
  float weight      = readWeight();
  int   riskScore   = dhtOk ? calculateRiskScore(temperature, humidity, gasValue) : 0;

  // Simple alarm: blink the LED when risk is high.
  digitalWrite(LED_PIN, riskScore >= 70 ? HIGH : LOW);

  // ----- human-readable block -----
  Serial.println(F("===== SENSOR DATA ====="));
  if (dhtOk) {
    Serial.print(F("Sicaklik: "));
    Serial.print(temperature, 1);
    Serial.println(F(" C"));
    Serial.print(F("Nem: "));
    Serial.print(humidity, 1);
    Serial.println(F(" %"));
  } else {
    Serial.println(F("DHT11 okunamadi!"));
  }
  Serial.print(F("MQ135 Degeri: "));
  Serial.println(gasValue);
  if (weight != -999) {
    Serial.print(F("Agirlik: "));
    Serial.print(weight, 2);
    Serial.println(F(" g"));
  } else {
    Serial.println(F("HX711 hazir degil!"));
  }
  Serial.print(F("Risk Score: "));
  Serial.println(riskScore);

  // ----- JSON line (consumed by the Python bridge) -----
  Serial.print(F("{"));
  Serial.print(F("\"temperature\":"));
  Serial.print(dhtOk ? temperature : -999, 1);
  Serial.print(F(",\"humidity\":"));
  Serial.print(dhtOk ? humidity : -999, 1);
  Serial.print(F(",\"gasValue\":"));
  Serial.print(gasValue);
  Serial.print(F(",\"weight\":"));
  Serial.print(weight, 2);
  Serial.print(F(",\"riskScore\":"));
  Serial.print(riskScore);
  Serial.println(F("}"));
  Serial.println(F("-----------------------"));
}
