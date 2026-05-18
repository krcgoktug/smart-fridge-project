# Setup Guide — Click by Click

A beginner walkthrough for the parts that **only you can do**: creating the
Firebase database, filling in the config files, and flashing the two ESP32
boards. The code itself is already finished.

Do the parts **in order**. Each part says clearly what to click.

---

## 0. What you need

**Accounts**
- A Google account (free) — for Firebase.

**Hardware**
- ESP32 DevKit V1 board + DHT11 + MQ135 + HX711 + load cells.
- ESP32-CAM (AI-Thinker) + an FTDI / USB-TTL adapter (3.3 V).
- USB cables; a Wi-Fi network.

**Software on your PC**
- Arduino IDE 2.x — <https://www.arduino.cc/en/software>
- Python 3.x — <https://www.python.org/downloads/> (tick *"Add to PATH"*).
- Flutter SDK — <https://docs.flutter.dev/get-started/install/windows>
  (already installed on this PC at `C:\Users\HUAWEI\flutter`).

---

## Part A — Create the Firebase Realtime Database

1. Open <https://console.firebase.google.com> and sign in with Google.
2. Click **Add project** (or **Create a project**).
3. Project name: type `smart-fridge` → **Continue**.
4. Google Analytics screen: toggle it **off** → **Continue** (analytics is
   not needed) → **Create project** → wait → **Continue**.
5. On the left menu click **Build → Realtime Database**.
6. Click **Create Database**.
7. Database location: pick the closest (e.g. *europe-west1*) → **Next**.
8. Security rules: choose **Start in test mode** → **Enable**.
   > Test mode lets the boards read/write without login. It is fine for a
   > class demo but expires after 30 days and is not secure — that is a
   > deliberate, documented trade-off.
9. You now see the database. Copy the URL shown at the top, it looks like:
   `https://smart-fridge-xxxx-default-rtdb.firebaseio.com`
   **Save this — it is your `FIREBASE_HOST`.**

### Get the database secret (for the ESP32 + the service)

10. Click the **gear icon** (top-left, next to *Project Overview*) →
    **Project settings**.
11. Open the **Service accounts** tab.
12. Scroll to **Database secrets**, click **Show** and copy the long string.
    **Save this — it is your `FIREBASE_AUTH`.**
    > If you do not see "Database secrets", you can leave `FIREBASE_AUTH`
    > empty and rely on the test-mode rules from step 8 instead.

---

## Part B — Fill in the config files

All three files below are **git-ignored** — they are yours and never get
committed.

### B1. ESP32 DevKit — `firmware/esp32-devkit/secrets.h`

1. Open the folder `firmware\esp32-devkit`.
2. Copy `secrets.example.h` and rename the copy to `secrets.h`.
3. Open `secrets.h` in any text editor and fill in:
   - `WIFI_SSID` — your Wi-Fi name.
   - `WIFI_PASSWORD` — your Wi-Fi password.
   - `FIREBASE_HOST` — the URL from Part A step 9.
   - `FIREBASE_AUTH` — the secret from Part A step 12.
   - `DEVICE_ID` — leave it as `fridge_01`.

### B2. ESP32-CAM — `firmware/esp32-cam/cam_secrets.h`

1. Open the folder `firmware\esp32-cam`.
2. Copy `cam_secrets.example.h` and rename the copy to `cam_secrets.h`.
3. Fill in `WIFI_SSID` and `WIFI_PASSWORD` — the **same Wi-Fi** as B1.

### B3. Image analysis service — `backend/image-analysis-service/.env`

1. Open the folder `backend\image-analysis-service`.
2. Copy `.env.example` and rename the copy to `.env`.
3. Fill in:
   - `CAMERA_BASE_URL` — leave for now; you set it after Part F.
   - `FIREBASE_HOST` — the URL from Part A step 9.
   - `FIREBASE_AUTH` — the secret from Part A step 12.
   - `DEVICE_ID` — leave as `fridge_01`.

---

## Part C — Connect the Flutter app to Firebase

This generates `lib/firebase_options.dart` so the app can read your database.

1. Open **PowerShell**.
2. Install the Firebase CLI — download the standalone installer from
   <https://firebase.tools> and run it.
3. Log in (a browser window opens — pick your Google account):
   ```powershell
   firebase login
   ```
4. Install the FlutterFire CLI:
   ```powershell
   C:\Users\HUAWEI\flutter\bin\dart.bat pub global activate flutterfire_cli
   ```
5. Generate the config:
   ```powershell
   cd C:\Users\HUAWEI\smart-fridge-project\mobile\smart_fridge_app
   C:\Users\HUAWEI\flutter\bin\flutter.bat pub global run flutterfire_cli:flutterfire configure
   ```
6. When asked, use the **arrow keys** to select your `smart-fridge` project,
   press **Enter**. For platforms, keep **android** and **web** ticked →
   **Enter**.
7. It writes `lib/firebase_options.dart`. The app is now linked to Firebase.

---

## Part D — Install Arduino IDE + ESP32 support

1. Install and open **Arduino IDE 2.x**.
2. **File → Preferences**. In *Additional boards manager URLs* paste:
   ```
   https://espressif.github.io/arduino-esp32/package_esp32_index.json
   ```
   → **OK**.
3. Open **Tools → Board → Boards Manager**, search **esp32**, install
   **esp32 by Espressif Systems**.
4. Open **Tools → Manage Libraries** and install (search each, click
   *Install*):
   - **DHT sensor library** (Adafruit)
   - **Adafruit Unified Sensor** (Adafruit)
   - **HX711** (Bogdan Necula)
   - **ArduinoJson** (Benoit Blanchon)

> If a board never appears under *Tools → Port*, install the USB-serial
> driver for your board's chip (CP2102 or CH340) and re-plug it.

---

## Part E — Flash the ESP32 DevKit (sensor board)

1. Wire the sensors as in [wiring.md](wiring.md). **Power off while wiring.**
2. Plug the ESP32 DevKit into the PC by USB.
3. In Arduino IDE open `firmware\esp32-devkit\esp32-devkit.ino`.
4. **Tools → Board → esp32 → ESP32 Dev Module**.
5. **Tools → Port →** select the COM port that appeared.
6. Click the **Upload** button (right arrow). Wait for *Done uploading*.
7. Open **Tools → Serial Monitor**, set baud to **115200**. You should see:
   ```
   [WiFi] Connected. IP: 192.168.1.42
   [Heartbeat] sent -> devices/fridge_01/sensors
   ```
8. Check Firebase: the **Realtime Database** page now shows a `devices`
   node — the board is working.

---

## Part F — Flash the ESP32-CAM (camera board)

The ESP32-CAM has **no USB port**, so it is flashed through the FTDI adapter.

1. Wire FTDI ↔ ESP32-CAM (see [wiring.md](wiring.md)):
   | FTDI | ESP32-CAM |
   |------|-----------|
   | 5V | 5V |
   | GND | GND |
   | TX | U0R |
   | RX | U0T |
2. **To enter flash mode:** connect a jumper wire from **GPIO 0 to GND**.
3. Plug the FTDI adapter into the PC.
4. In Arduino IDE open `firmware\esp32-cam\esp32-cam.ino`.
5. **Tools → Board → esp32 → AI Thinker ESP32-CAM**.
6. **Tools → Port →** select the FTDI's COM port.
7. Click **Upload**. When the IDE says *Connecting...*, press the **RST**
   button on the ESP32-CAM once.
8. After *Done uploading*: **remove the GPIO 0 ↔ GND jumper**, then press
   **RST** again.
9. Open **Serial Monitor** at **115200**. Note the printed IP, e.g.:
   ```
   [Ready] stream  : http://192.168.1.50
   ```
   **Save this IP.**
10. Test it: open `http://192.168.1.50/` in a browser on the same Wi-Fi —
    you should see the live camera page.

### Put the camera IP into the config

- Edit `backend\image-analysis-service\.env` → set
  `CAMERA_BASE_URL=http://192.168.1.50` (your IP).

---

## Part G — Run the image analysis service

```powershell
cd C:\Users\HUAWEI\smart-fridge-project\backend\image-analysis-service
python -m venv .venv
.venv\Scripts\activate
pip install -r requirements.txt
python app.py
```

Leave this window running. It pulls camera frames, decodes QR stickers and
analyses bananas, writing results to Firebase. Print QR stickers using
[../qr-samples/qr-generation-guide.md](../qr-samples/qr-generation-guide.md).

---

## Part H — Run the Flutter app

Pick one (full commands in
[../mobile/smart_fridge_app/README.md](../mobile/smart_fridge_app/README.md)):

```powershell
cd C:\Users\HUAWEI\smart-fridge-project\mobile\smart_fridge_app
C:\Users\HUAWEI\flutter\bin\flutter.bat pub get
C:\Users\HUAWEI\flutter\bin\flutter.bat run -d chrome
```

In the app: **Settings → ESP32-CAM address** → enter `http://<your-cam-ip>`
→ **Save**. The phone / PC must be on the **same Wi-Fi** as the ESP32-CAM.

---

## Final check

| You should see | Where |
|----------------|-------|
| `devices/fridge_01` tree filling up | Firebase Realtime Database page |
| Live weight / temperature / gas | App → Dashboard |
| Products appearing when a QR is shown | App → Products |
| Banana browning % and status | App → Dashboard |
| Live video | App → Camera (Android app or local run only) |

If something is empty, re-check the matching part above — the config files
in Part B are the most common cause.
