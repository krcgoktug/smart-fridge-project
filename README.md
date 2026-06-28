# Smart Fridge — Load Cell Calibration

> **YAPANLAR:** Sıla Özgel · Göktuğ Karaca · Ezgi Erdoğan

Bir buzdolabı / saklama kabı projesi için HX711 yük hücresi (load cell)
kalibrasyon sketch'i. Bilinen bir ağırlık yardımıyla doğru
`calibration_factor` değerini bulur.

## Donanım

- Arduino UNO
- HX711 modülü + 4 adet load cell
- USB kablo

## Bağlantı

| HX711 pini | Arduino pini |
| --- | --- |
| DT | D4 |
| SCK | D5 |
| VCC | 5V |
| GND | GND |

## Kullanım

1. Arduino IDE'de **HX711 Arduino Library** (Bogdan Necula) kütüphanesini kur.
2. `firmware/arduino-uno-calibration/arduino-uno-calibration.ino` dosyasını
   Uno'ya yükle.
3. Serial Monitor'ü **9600 baud**'da aç.
4. Önce `t` gönder → tare (sıfırla).
5. Bilinen ağırlığı (örn 100 g) kefeye koy.
6. Bilinen ağırlığı gram olarak yaz, Enter.
7. Çıkan **`calibration_factor`** değerini not al — asıl ölçüm sketch'inizde
   bu değeri kullanırsınız.
