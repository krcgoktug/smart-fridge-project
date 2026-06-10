// =====================================================================
//  Zero Waste Smart Fridge - Arduino Uno sensor node
// =====================================================================
//  DHT11 DATA -> D3 | MQ135 AOUT -> A0 | HX711 DT -> D4, SCK -> D5 | LED -> D9
//  Libraries: "DHT sensor library" (Adafruit) + "HX711 Arduino Library" (Bogdan Necula)
//  Serial: 9600 baud. Commands: t/T = re-tare. LED stays on while the
//  board is powered (system-on indicator on D9).
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
int mq135Baseline = 0;            
// HX711 calibration factor for THIS rig (4 load cells under a piece of
// cardboard). Computed once with the separate calibration sketch in
// firmware/arduino-uno-calibration/. Don't re-derive it at runtime — the
// factor is a property of the hardware and stays constant; only the zero
// point drifts (and we handle that below).
float calibration_factor = 20.626;
float zero_threshold = 0.0;      // 0 = let small positive readings show
                                 // through (sub-50 g items become visible);
                                 // negative readings are still clamped to 0
float lastStableWeight = 0;      // used to reject sudden nonsense spikes

// Soft drift compensation. The HX711's zero point creeps over time due
// to temperature and load-cell creep. We keep a software offset that
// slowly absorbs NEGATIVE drift (a real load can never make the scale
// read negative, so a sub-zero reading is drift by definition). Pressing
// the in-app Tare button resets this immediately.
float baselineDrift = 0.0;
const float DRIFT_NEG_LIMIT = -500.0;  // skip auto-zero if drift exceeds this
const float DRIFT_ABSORB    = 0.05;    // fraction of each negative reading
                                       // folded into the offset per cycle

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
// warmupMs lets the caller pick: long wait at boot (sensor heater needs
// time to reach steady state), short wait when the user re-baselines
// later with the 'g' command (sensor already warm).
int calculateMQ135Baseline(unsigned long warmupMs) {
  long total = 0;
  Serial.print(F("MQ135 baseline aliniyor ("));
  Serial.print(warmupMs / 1000);
  Serial.println(F(" sn warm-up)..."));
  Serial.println(F("Lutfen sensoru TEMIZ HAVADA tutun."));
  delay(warmupMs);
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
  // This MQ135 module is wired so the AO voltage DROPS when gas is
  // present (more gas -> lower Rs -> lower divider output). Flip the
  // sign so the displayed value INCREASES with gas concentration, the
  // way the dashboard and the risk score expect.
  long delta = (long)mq135Baseline - (long)gasValue;   // +ve when gas detected
  if (delta < 0) delta = 0;                            // ignore sub-baseline noise
  int sensitive = (int)(mq135Baseline + delta * 3L);
  return sensitive;
}

// ===================== HX711 READ =====================
// Mirrors the validated standalone load-cell sketch: average of 20
// samples, NaN/inf guard, sub-threshold values snapped to 0, and a
// spike rejector that keeps the last stable reading.
float readWeight() {
  if (!scale.is_ready()) return -999;
  float raw = scale.get_units(20);
  if (isnan(raw) || isinf(raw)) raw = lastStableWeight + baselineDrift;

  // Apply the software drift offset so the value the rest of the sketch
  // sees is the "true" weight above the moving baseline.
  float w = raw - baselineDrift;

  if (abs(w - lastStableWeight) > 30000) w = lastStableWeight;

  // Slowly absorb NEGATIVE drift into the offset. We never absorb
  // positive readings, so a real load on the scale is left alone — the
  // 5 kg you place stays 5 kg even if the baseline has drifted under it.
  // Extreme drift (< -500 g) is left for the user to fix with the Tare
  // button so we don't slow-track huge offsets.
  if (w < 0 && w > DRIFT_NEG_LIMIT) {
    baselineDrift += w * DRIFT_ABSORB;
  }

  lastStableWeight = w;

  if (abs(w) < zero_threshold) w = 0;
  if (w < 0) w = 0;            // never report negative grams
  return w;
}

// ===================== SIMPLE RISK SCORE =====================
int calculateRiskScore(float temperature, float humidity, int gasValue) {
  int risk = 0;
  if      (temperature > 30) risk += 20;
  else if (temperature > 25) risk += 10;
  if      (humidity > 80)    risk += 20;
  else if (humidity > 65)    risk += 10;
  // gasValue here is already the corrected/inverted "display value" from
  // readMQ135Filtered, which goes UP when gas is present. So the diff
  // above baseline is positive in that case.
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
  // LED is a simple power/status indicator: stays ON as long as the
  // board has power. No risk-based blinking.
  digitalWrite(LED_PIN, HIGH);

  dht.begin();
  scale.begin(HX711_DT_PIN, HX711_SCK_PIN);
  scale.set_scale(calibration_factor);

  Serial.println(F("Zero Waste Smart Fridge - Arduino UNO Sensor System"));
  Serial.println(F("---------------------------------------------------"));
  Serial.println(F("Tartiyi BOS birakin, dara aliniyor..."));
  delay(3000);
  scale.tare();
  Serial.println(F("Dara alindi."));

  // 20-second warmup gives the MQ135's heater enough time to reach
  // steady state before we record what "clean air" looks like.
  mq135Baseline = calculateMQ135Baseline(20000);

  Serial.println(F("Sistem hazir."));
  Serial.println(F("Komutlar:  t/T = HX711 dara al, g/G = MQ135 baseline yenile"));
  Serial.println();
}

// ===================== LOOP =====================
void loop() {
  if (Serial.available()) {
    char cmd = Serial.read();
    if (cmd == 't' || cmd == 'T') {
      scale.tare();
      lastStableWeight = 0;
      baselineDrift = 0;            // hard reset of the soft offset too
      Serial.println(F(">> Dara yeniden alindi <<"));
    }
    if (cmd == 'g' || cmd == 'G') {
      // Re-baseline the gas sensor. Sensor is already warm at runtime,
      // so a short 2-second sample is enough. User MUST hold clean air
      // around the sensor before issuing this command.
      Serial.println(F(">> MQ135 baseline yenileniyor (temiz havada bekle) <<"));
      mq135Baseline = calculateMQ135Baseline(2000);
      Serial.println(F(">> MQ135 baseline yenilendi <<"));
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

  // LED stays ON the entire time (set HIGH once in setup); no risk-based
  // toggle. Risk score is still emitted via JSON for the app.

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

  // JSON line (Python bridge bunu okuyor)
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