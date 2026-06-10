// =====================================================================
//  HX711 Load-Cell Calibration  —  Smart Fridge
// =====================================================================
//
//  Tek seferlik kullanim icin. Bu sketch'i Arduino Uno'ya yukle, asagidaki
//  adimlarla calibration_factor degerini bul, sonra o sayiyi
//  firmware/arduino-uno/arduino-uno.ino icindeki "calibration_factor"
//  satirina yapistir ve esas (combined) sketch'i tekrar yukle.
//
//  Adimlar (Serial Monitor 9600 baud, "Newline" line ending):
//    1) Platform BOS olsun (veya sadece sabit mukavva varsa onu birak).
//    2) Serial Monitor'a 't' yaz, Enter -> dara alinir.
//    3) Bilinen agirlikta bir nesne koy (mesela 5000 g = 5 L su).
//       Daha agir nesne kullan, kalibrasyon o kadar dogru olur.
//    4) Serial Monitor'a o nesnenin agirligini gram olarak yaz, Enter
//       (orn: 5000).
//    5) Sketch 30 olcum alir ve "calibration_factor = X.XXXXXX" basar.
//    6) Bu sayiyi arduino-uno.ino'ya yapistir, ana sketch'i upload et.
//       Bu kalibrasyon sketch'ini bir daha calistirmana gerek yok.
//
//  Tekrar dene: kutleyi cikar -> 't' gonder -> yeni kutleyi koy/yaz.
//
//  Pinler ana sketch'le ayni: HX711 DT -> D4, SCK -> D5
//
// =====================================================================

#include "HX711.h"

#define HX711_DT_PIN   4
#define HX711_SCK_PIN  5

HX711 scale;
bool   tared  = false;
String buffer = "";

void setup() {
  Serial.begin(9600);
  scale.begin(HX711_DT_PIN, HX711_SCK_PIN);
  // Ham mod: scale = 1.0, get_units() ham HX711 sayisini dondurur.
  scale.set_scale();

  Serial.println();
  Serial.println(F("=== HX711 Calibration ==="));
  Serial.println(F("Platformu BOS birakin (sadece sabit mukavva varsa onu birakin)."));
  Serial.println(F("Hazirsa Serial Monitor'a 't' gonderin -> dara alinir."));
}

void loop() {
  if (!Serial.available()) return;
  char c = Serial.read();

  if (c == 't' || c == 'T') {
    Serial.println(F("Dara aliniyor (20 ornek)..."));
    scale.tare(20);
    tared = true;
    Serial.println(F("Dara tamam."));
    Serial.println(F("Simdi BILINEN kutleyi koyun ve gramini yazin (orn: 5000), Enter."));
    return;
  }

  if (isDigit(c)) {
    buffer += c;
    return;
  }

  if (c == '\n' || c == '\r') {
    if (buffer.length() == 0) return;
    if (!tared) {
      Serial.println(F("Once 't' ile dara alin."));
      buffer = "";
      return;
    }
    long mass = buffer.toInt();
    buffer = "";
    if (mass <= 0) {
      Serial.println(F("Gecersiz kutle."));
      return;
    }

    Serial.print(F("Bilinen kutle: "));
    Serial.print(mass);
    Serial.println(F(" g"));
    Serial.println(F("30 olcum aliniyor..."));

    double total = 0.0;
    for (int i = 0; i < 30; i++) {
      total += scale.get_units(1);   // ham sayim (cunku scale=1.0)
      delay(50);
    }
    double rawAvg = total / 30.0;
    double factor = rawAvg / (double)mass;

    Serial.println();
    Serial.print(F(">>> calibration_factor = "));
    Serial.println(factor, 6);
    Serial.println(F(">>> Bu sayiyi arduino-uno.ino icindeki"));
    Serial.println(F("    'float calibration_factor = ...;' satirina yapistirin."));
    Serial.println();
    Serial.println(F("Yeni deneme icin: kutleyi cikar -> 't' gonder -> yeni kutleyi koy/yaz."));
  }
}
