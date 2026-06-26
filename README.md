# Zero Waste Smart Fridge

> A real **IoT + computer-vision + mobile** university project. An Arduino Uno
> watches a storage box, an ESP32-CAM provides live video + QR scanning,
> and a Flutter app shows everything live.

### 🎬 [**Canlı demo (sadece arayüz)**](https://krcgoktug.github.io/smart-fridge-project/)

Canlı linkte gerçek Flutter web build çalışır. Sensörler bağlı olmadığı
için arayüz "offline" görünür — ekranları, layout'u önizlemek için iyidir.

---

# 🇹🇷 Sıfırdan Kurulum Kılavuzu

> Bu bölüm, projeyi devralan / kendi PC'sinde çalıştıracak ekip arkadaşları
> içindir. Daha önce hiç Arduino, Python ya da Flutter görmemiş biri bile
> bu sırayı takip ederek çalıştırabilir. İngilizce bölüm bu kılavuzun
> aşağısındadır.

## 0. Mantığı önce anlayalım

Sistemin üç ayağı var, ve hepsi aynı PC'de yan yana çalışır:

```
    [Arduino UNO]──USB──>[Python Bridge]──HTTP──>[Flutter Web Uygulama]
    (sensörler)           localhost:8787          localhost:8000
                                                       ▲
    [ESP32-CAM]──Wi-Fi──────────────────────────────────┘
    (kamera, kendi IP'si üzerinden direkt)
```

- **Arduino UNO** — DHT11 (sıcaklık/nem) + MQ135 (gaz) + HX711 (ağırlık)
  okur, USB kablodan PC'ye JSON gönderir.
- **Python Bridge** — USB seri portunu dinler, gelen JSON'u tarayıcıya
  açık bir HTTP endpoint'inde sunar (`/sensors`).
- **ESP32-CAM** — Wi-Fi'ye bağlanır, kendi IP'sinde HTTP server çalıştırır
  (port 80 = JPEG, port 81 = canlı video).
- **Flutter app** — Bridge'ten sensörleri, ESP32-CAM'den kamerayı çeker,
  ekranda gösterir.

Üçü de aynı Wi-Fi ağında olmak zorunda. PC ve ESP32-CAM aynı router'a
bağlı olmalı.

---

## 1. Ne lazım?

### Donanım
- 1 adet **Arduino UNO** (USB kablosuyla)
- 1 adet **AI Thinker ESP32-CAM** (programlamak için FTDI/USB-TTL adaptör
  veya programmer shield)
- 1 adet **DHT11** sıcaklık/nem sensörü
- 1 adet **MQ135** gaz sensörü
- 1 adet **HX711** + 4 adet **load cell** (ağırlık ölçer)
- Status LED (opsiyonel) + birkaç jumper kablo + breadboard
- Aynı evdeki bir **Wi-Fi router**

### Yazılım (PC'ye kurulacak — bir kerelik)
1. **[Python 3.10 veya üstü](https://www.python.org/downloads/)** — kurarken
   "Add Python to PATH" kutusunu mutlaka işaretle.
2. **[Arduino IDE 2.x](https://www.arduino.cc/en/software)** — Uno ve
   ESP32-CAM firmware'lerini yüklemek için.
3. **[Git](https://git-scm.com/downloads)** — repo'yu indirmek için
   (alternatif: GitHub'dan ZIP olarak indir).
4. **Modern bir tarayıcı** — Chrome / Edge tavsiye edilir.

> ⚠️ **Flutter SDK gerek YOK.** Uygulamayı kaynaktan değil, hazır web
> build'inden çalıştıracağız (`docs/` klasöründe Flutter web build'i hazır
> duruyor).

---

## 2. Repo'yu indir

PowerShell ya da Git Bash aç, istediğin bir klasöre git:

```bash
git clone https://github.com/krcgoktug/smart-fridge-project.git
cd smart-fridge-project
```

(Git yoksa GitHub sayfasından "Code → Download ZIP" → bir klasöre aç.)

---

## 3. Arduino UNO — kablolar + sketch yükleme

### 3.1 Kabloları bağla

| Sensör | Arduino pin |
| --- | --- |
| DHT11 DATA | **D3** |
| MQ135 AOUT | **A0** |
| HX711 DT | **D4** |
| HX711 SCK | **D5** |
| Status LED (+) | **D9** (220Ω direnç ile GND'ye) |
| Hepsinin VCC | **5V** |
| Hepsinin GND | **GND** |

### 3.2 Arduino IDE'de kütüphaneleri kur

Arduino IDE'yi aç → **Tools → Manage Libraries...** → tek tek ara ve
"Install" bas:

- `DHT sensor library` (yazar: **Adafruit**)
- `HX711 Arduino Library` (yazar: **Bogdan Necula**)

### 3.3 Uno'yu USB ile bağla, sketch'i aç ve yükle

1. Arduino UNO'yu USB ile PC'ye tak.
2. Arduino IDE → **File → Open** → `firmware/arduino-uno/arduino-uno.ino`
3. Üst toolbar:
   - **Board:** "Arduino UNO"
   - **Port:** Listede tek bir COM port göreceksin (Windows'ta genelde
     `COM3`–`COM10` arası). Bu **Arduino'nun portu**. Bu numarayı not al,
     birazdan bridge'e söyleyeceğiz.
4. Sol üstteki **→ (Upload)** butonuna bas. "Done uploading" yazınca tamam.

### 3.4 Veri geliyor mu test et (opsiyonel ama önerilir)

Arduino IDE'de:
1. Sağ üstteki büyüteç simgesine (**Serial Monitor**) bas.
2. Sağ alttaki **baud** dropdown'ından **9600 baud** seç.
3. Saniyede bir şu satırları görmen gerek:
   ```
   Sicaklik: 27.6 C
   Nem: 62.0 %
   MQ135 Degeri: 43
   Agirlik: 0.00 g
   Risk Score: 10
   {"temperature":27.6,"humidity":62.0,"gasValue":43,"weight":0.0,"riskScore":10}
   ```
   Görüyorsan donanım çalışıyor demektir. **Serial Monitor'ü kapat** (sağ
   üstteki X) — açıkken Bridge portu açamaz!

### 3.5 (Opsiyonel) Ağırlık kalibrasyonu

İlk kurulumda HX711 muhtemelen yanlış değer verir. Bir kerelik kalibrasyon:

1. `firmware/arduino-uno-calibration/arduino-uno-calibration.ino` sketch'ini
   yükle.
2. Serial Monitor (9600 baud) aç.
3. `t` gönder → tare (sıfırla).
4. Bilinen ağırlıklı bir şey koy (örn 100g).
5. Gerçek değeri yaz (örn `100`) ve Enter.
6. Çıkan `calibration_factor: 20.626` gibi sayıyı kopyala.
7. `firmware/arduino-uno/arduino-uno.ino` içinde `float calibration_factor = ...`
   satırına yapıştır, asıl sketch'i tekrar yükle.

---

## 4. ESP32-CAM — Wi-Fi şifresi + sketch yükleme

### 4.1 Wi-Fi şifresini ayarla

1. `firmware/esp32-cam/cam_secrets.example.h` dosyasını **kopyala**, aynı
   klasöre `cam_secrets.h` adıyla yapıştır.
2. `cam_secrets.h` içinde Wi-Fi SSID ve şifrenizi yaz:
   ```cpp
   #define WIFI_SSID     "Wi-Fi adınız"
   #define WIFI_PASSWORD "Wi-Fi şifreniz"
   ```

> Bu dosya `.gitignore`'da — yanlışlıkla GitHub'a yüklenmez.

### 4.2 Arduino IDE'ye ESP32 board desteği ekle

1. **File → Preferences → Additional Board Manager URLs** alanına şunu yapıştır:
   ```
   https://raw.githubusercontent.com/espressif/arduino-esp32/gh-pages/package_esp32_index.json
   ```
2. **Tools → Board → Boards Manager** → "esp32" ara → Espressif Systems'ı
   "Install".

### 4.3 ESP32-CAM'i programla

ESP32-CAM'in **direkt USB portu yoktur** — FTDI/USB-TTL adaptör veya
"ESP32-CAM-MB" programmer shield kullan. Programlama modu için **GPIO0'ı
GND'ye bağla** (shield kullanıyorsan otomatik).

1. `firmware/esp32-cam/esp32-cam.ino` dosyasını aç.
2. Toolbar:
   - **Board:** "AI Thinker ESP32-CAM"
   - **Port:** ESP32-CAM'in COM portu (Uno'nun portundan farklı, ayrı bir
     numara olacak)
3. **→ Upload**. "Hard resetting via RTS pin..." yazınca bitti.
4. GPIO0–GND bağlantısını kaldır, RESET butonuna bas.

### 4.4 ESP32-CAM'in IP'sini öğren

1. ESP32-CAM'i Arduino IDE'de seçili tut, **Serial Monitor**'ü **115200 baud**'da aç.
2. RESET'e bas. Birkaç saniye sonra şuna benzer satır görmen gerek:
   ```
   [WiFi] Connected!
   IP address: 192.168.1.42
   [HTTP] port 80 (capture) up
   [HTTP] port 81 (stream)  up
   ```
3. **`192.168.1.42` IP'sini not al** — uygulamaya bunu gireceğiz.
4. Tarayıcıdan `http://192.168.1.42/` aç → çalışıyorsa "Smart Fridge Camera"
   ana sayfası görünür. `http://192.168.1.42:81/stream` → canlı video.

> ESP32-CAM'in IP'si router her açıldığında değişebilir. Sabit kalsın
> istiyorsan router yönetim panelinden DHCP rezervasyonu yap.

---

## 5. Python Bridge'i başlat

### 5.1 pyserial kütüphanesini kur

PowerShell aç (Win+R → `powershell` → Enter):

```bash
pip install pyserial
```

### 5.2 Bridge'i çalıştır

Repo klasöründeyken:

```bash
python bridge/arduino_serial_bridge.py --port COM5
```

(`COM5` yerine kendi Arduino'nun portunu yaz — 3.3'te not aldığın numara.
Bilmiyorsan `--port` parametresini hiç yazmadan da çalıştırabilirsin,
otomatik bulmaya çalışır.)

Başarılı çıktı:
```
[serial] opening COM5 @ 9600
[http]   listening on http://localhost:8787/sensors
[serial] COM5 connected, listening for JSON lines
[serial] {'temperature': 27.6, 'humidity': 61.0, ...}
```

### 5.3 Bridge'in çalıştığını test et

Yeni bir tarayıcı sekmesi aç → `http://localhost:8787/sensors`. Şuna benzer
bir JSON görmelisin:

```json
{"temperature": 27.6, "humidity": 61.0, "gasValue": 41, "weight": 0,
 "updatedAt": 1781693881, "online": true}
```

**`"online": true` görüyorsan Arduino → Bridge zinciri tam çalışıyor.** ✅

### Bridge'le ilgili sık hatalar

| Hata | Sebep | Çözüm |
| --- | --- | --- |
| `PermissionError: 'COM5'` | Arduino IDE'nin **Serial Monitor**'ü açık, portu tutuyor | Arduino IDE'de Serial Monitor sekmesini kapat (×) |
| `could not find an arduino-looking port` | Arduino takılı değil veya driver yok | USB kabloyu kontrol et; CH340 driver gerekebilir (Çin clone'larda) |
| HTTP `online: false` | Bridge bağlandı ama JSON gelmiyor — baud yanlış olabilir | Sketch 9600 baud bekliyor, `--baud 9600` ekle |

---

## 6. Flutter web uygulamasını başlat (Flutter SDK gerek yok!)

`docs/` klasöründe Flutter web build'i hazır duruyor. Bunu küçük bir Python
sunucusuyla yayınlayacağız.

### 6.1 Sunucuyu başlat

Repo klasöründeyken **yeni bir PowerShell** aç (bridge'in çalıştığı pencereyi
kapatma!):

```bash
python serve_local.py
```

Çıktı:
```
serving docs/ at http://localhost:8000/smart-fridge-project/
```

### 6.2 Tarayıcıdan aç

```
http://localhost:8000/smart-fridge-project/
```

Smart Fridge dashboard'ı açılır.

> ⚠️ Direkt `http://localhost:8000/` açarsan 404 alırsın. `index.html`
> içindeki `<base href>` GitHub Pages için ayarlı; `serve_local.py` bunu
> handle ediyor ama tam URL'i doğru yazmalısın.

---

## 7. Uygulamayı yapılandır (bridge URL + kamera IP)

İlk açtığında app "offline" görür — çünkü bridge ve kameraya henüz
bağlanmadı. Onları söylemek için:

### 7.1 Bridge URL'ini gir

1. Uygulamada sağ alttaki **⚙️ Ayarlar (Settings)** ekranına git.
2. **"Bridge URL"** alanına:
   ```
   http://localhost:8787
   ```
   yaz, **Kaydet**.
3. Dashboard'a dönünce sensör değerleri canlı dökülmeye başlar.

> Telefondan açıyorsan `localhost` yerine PC'nin LAN IP'sini yaz
> (örn `http://192.168.1.20:8787`). PC IP'sini öğrenmek: PowerShell'de
> `ipconfig` → "IPv4 Address" satırına bak.

### 7.2 Kamerayı bağla

1. **📷 Kamera (Camera)** ekranına git.
2. **"ESP32-CAM IP"** alanına 4.4'te not aldığın IP'yi yaz
   (sadece IP, başına `http://`, sonuna `:80` ekleme):
   ```
   192.168.1.42
   ```
3. **Kaydet** bas. Canlı video akmaya başlar.
4. Önündeki QR sticker'ı kameraya tut → otomatik tanır ve "Ürünler" listesine
   ekler.

### 7.3 Demo QR kodlarını yazdır

```bash
pip install qrcode pillow
python qr-samples-demo/generate.py
```

`qr-samples-demo/a4_qrs_5p5cm.pdf` dosyasını **%100 ölçekte (gerçek boyut)**
yazdır. 5 demo ürün — bazı tarihleri geçmiş, bazıları yakında bitecek —
böylece Uyarılar (Alerts) ekranı dolu görünür.

---

## 8. Günlük kullanım (kurulum bittikten sonra)

Her başlangıçta **iki pencere** açık olmalı:

**Pencere 1 — Bridge:**
```bash
cd smart-fridge-project
python bridge/arduino_serial_bridge.py --port COM5
```

**Pencere 2 — Web sunucu:**
```bash
cd smart-fridge-project
python serve_local.py
```

Sonra tarayıcıdan: `http://localhost:8000/smart-fridge-project/`

Kapatmak için iki PowerShell'de de `Ctrl+C`.

---

## 9. Bir şey çalışmıyorsa hızlı checklist

| Belirti | Önce buna bak |
| --- | --- |
| App "Offline" diyor | Bridge çalışıyor mu? `http://localhost:8787/sensors` aç |
| Bridge bağlanamıyor | Arduino IDE'de Serial Monitor açık olabilir → kapat |
| Sensör değerleri 0 | Baud 9600 mu? Kabloları kontrol et |
| Kamera kara ekran | ESP32-CAM IP doğru mu? `http://IP:81/stream` doğrudan açılıyor mu? |
| Tarayıcı 404 veriyor | URL'i tam yaz: `/smart-fridge-project/` slash dahil |
| `pip install pyserial` hata veriyor | Python PATH'te değil → Python'u tekrar kur, "Add to PATH" kutusunu işaretle |
| ESP32-CAM Wi-Fi'ye bağlanmıyor | 2.4 GHz ağa bağla (5 GHz desteklemiyor); SSID/şifrede Türkçe karakter olmasın |

Daha detaylı kablolama/mimari diyagramları için: [`docs/`](docs/) klasörü.

---

## 10. Repo yapısı (nereye ne yazılı?)

```
smart-fridge-project/
├── bridge/
│   └── arduino_serial_bridge.py    ← USB → HTTP köprüsü (Python)
├── firmware/
│   ├── arduino-uno/                ← Asıl sensör sketch'i
│   ├── arduino-uno-calibration/    ← Tek seferlik ağırlık kalibrasyonu
│   └── esp32-cam/                  ← Kamera sketch'i + WiFi şablonu
├── mobile/smart_fridge_app/        ← Flutter app kaynak kodu (geliştirenlere)
├── docs/                           ← Hazır Flutter WEB BUILD (kullanıcı buradan açar)
├── qr-samples-demo/                ← Demo QR sticker üreteci + A4 PDF
├── serve_local.py                  ← docs/'u localhost:8000'de servisleyen mini server
└── README.md                       ← Bu dosya
```

---

> 💡 **Geliştirme yapmak istiyorsan** (UI'ya yeni ekran eklemek vs.) o
> zaman Flutter SDK kurman gerekir. Aşağıdaki İngilizce bölümde
> `flutter pub get` / `flutter run` adımlarına bak.

---

## What it does

- **Arduino Uno** reads:
  - **DHT11** — temperature + humidity
  - **MQ135** — gas / VOC concentration
  - **HX711 + 4× load cells** — weight (calibrated, with software drift
    compensation + tare command)
- **ESP32-CAM** runs a tiny HTTP server with:
  - **Port 80** `/capture` — JPEG snapshot
  - **Port 81** `/stream` — MJPEG live video
- **Python bridge** (`bridge/arduino_serial_bridge.py`) reads the Arduino's
  USB serial JSON lines and exposes them at `http://localhost:8787/sensors`
  with permissive CORS so the browser app can poll them.
- **Flutter app** (web + Android) shows:
  - Live sensors, status, alerts
  - ESP32-CAM live stream
  - **Multi-QR scanning** (3×3 tiled decode, registers every distinct sticker
    once per session)
  - **Banana ripeness analysis** from the camera feed (pixel-level RGB
    classification, banded into Fresh / Spotting / Spoiling / Spoiled)
  - **Re-tare load cells** button (round-trips through bridge → Arduino)
  - **Recalibrate gas baseline** endpoint
  - Product expiry tracking with Fresh / Expiring Soon / Expired bands

---

## Data flow

```
                       ┌─────────────────────────────┐
Arduino Uno  ──USB──>  │ bridge/arduino_serial_bridge│  ──HTTP──>  Flutter web app
(sensors)              │  (Python, localhost:8787)   │             (Dashboard / Alerts / Products)
                       └─────────────────────────────┘
                                                          ▲
ESP32-CAM    ──LAN Wi-Fi (port 80 + 81)──────────────────┘
(camera)
```

- **Sensors** ride the USB cable into the Python bridge, then HTTP into the
  browser.
- **Camera** is on the same Wi-Fi as the PC/phone running the app; the
  browser talks to it directly over the local network.
- Firebase Realtime Database integration is wired up in code but ships with
  placeholder credentials; the app works fully offline-first by default
  (in-memory product store).

Full diagrams: **[docs/architecture.md](docs/architecture.md)**.

---

## Repository structure

```
smart-fridge-project/
  README.md
  docs/                          architecture, wiring, setup, demo
  bridge/
    arduino_serial_bridge.py     USB-serial → HTTP at localhost:8787
  firmware/
    arduino-uno/                 main sensor sketch (DHT11 + MQ135 + HX711 + LED)
    arduino-uno-calibration/     one-shot HX711 calibration helper
    esp32-cam/                   camera firmware (AI Thinker board)
  mobile/
    smart_fridge_app/            Flutter app (Dashboard / Camera / Products / Alerts / Settings)
  qr-samples-demo/               generator + printable A4 PDFs for demo QR stickers
```

---

## Try it on your PC (full hardware setup)

### 1. Wire the Arduino Uno

| Sensor | Pin |
| --- | --- |
| DHT11 data | **D3** |
| MQ135 AOUT | **A0** |
| HX711 DT | **D4** |
| HX711 SCK | **D5** |
| Status LED | **D9** |

### 2. Flash the firmware

In Arduino IDE (Library Manager): install **DHT sensor library** (Adafruit) +
**HX711 Arduino Library** (Bogdan Necula), then upload
`firmware/arduino-uno/arduino-uno.ino` to the Uno (COM5, 9600 baud).

Optional — first-time HX711 calibration: flash
`firmware/arduino-uno-calibration/arduino-uno-calibration.ino`, send `t` to
tare, place a known mass, type its grams + Enter, paste the printed
`calibration_factor` into the main sketch and re-flash.

For the camera, flash `firmware/esp32-cam/esp32-cam.ino` to an AI Thinker
ESP32-CAM. The camera prints its assigned IP on the Serial Monitor when it
joins Wi-Fi.

### 3. Start the bridge

```bash
pip install pyserial
python bridge/arduino_serial_bridge.py --port COM5
```

It auto-detects an Arduino-looking COM port if `--port` is omitted. Exposes
GET `/sensors`, POST `/tare`, POST `/recalibrate_gas`.

### 4. Run the Flutter app

```bash
cd mobile/smart_fridge_app
flutter pub get
flutter run -d chrome             # web
# or
flutter run                       # Android (phone on same Wi-Fi)
```

On the app:

- **Settings** → set the bridge URL (`http://localhost:8787` if local; use
  the laptop's LAN IP from a phone)
- **Camera** → enter the ESP32-CAM IP (just the IP, no port), tap **Save**

You'll see sensors stream live, the camera feed, QR auto-scan, banana
analysis, and alerts. Press **Tare scale** on the Dashboard to zero the
load cells from the UI.

---

## QR codes for the demo

Each product is encoded as a JSON QR payload:

```json
{ "productId": "milk_001",
  "name":      "Milk",
  "category":  "Dairy",
  "expiryDate":"2026-06-14",
  "addedDate": "2026-06-02" }
```

The Camera screen scans **multiple QRs in one frame** (3×3 overlapping tile
decoder) and registers each sticker exactly once per session.

Generate your own + print an A4 sheet:

```bash
pip install qrcode pillow
python qr-samples-demo/generate.py
```

Output: individual PNGs and `a4_qrs_5p5cm.pdf` — print at **100% scale**
(Actual size). Five demo products with mixed expiry dates so the Alerts
screen shows both **Expired** and **Expiring Soon** states out of the box.

---

## What's honestly real vs. demo-scope

| Area | Status |
| --- | --- |
| Temperature / humidity / weight | ✅ Real sensors, live, calibrated |
| MQ135 gas | ✅ Real sensor; cheap modules show baseline drift |
| ESP32-CAM live stream | ✅ Real MJPEG + JPEG capture |
| QR scanning (multi-code) | ✅ zxing2 + tiled re-decoding |
| Banana ripeness | ⚠️ Honest pixel-level RGB classifier, **not** ML / histogram / texture |
| Firebase RTDB integration | ⚠️ Wired in code; ships with placeholders → in-memory only by default |
| Push notifications / auth | ❌ Not implemented |

The project is intentionally honest about what's done. See
[docs/report-explanation.md](docs/report-explanation.md) for the report
language we use.

---

## Demo deployment

The `docs/` folder is the Flutter web build configured for GitHub Pages
(`<base href="/smart-fridge-project/">` + `.nojekyll`). Visiting
[the live link](https://krcgoktug.github.io/smart-fridge-project/) loads
the real interface — every screen, every widget, exactly as it runs
locally. Without the bridge it shows "offline" for sensors, which is the
correct degraded behaviour.

To redeploy after changes:

```bash
cd mobile/smart_fridge_app
flutter build web --release --pwa-strategy=none --base-href "/smart-fridge-project/"
cp -r build/web/* ../../docs/
touch ../../docs/.nojekyll
git add docs && git commit -m "Refresh demo build" && git push
```

GitHub Pages → Settings → Pages → Source: **main / docs**.

---

## Security

No real secrets are committed. Wi-Fi / camera credentials use
`*.example` files (the real `cam_secrets.h`, `secrets.h` are `.gitignore`d).
`firebase_options.dart` ships with placeholders — replace it locally via
`flutterfire configure`.

## License

Educational / university project. Free to use for learning.
