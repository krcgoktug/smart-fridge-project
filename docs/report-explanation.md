# University Report Explanation

Report-style explanation of the project. Each section maps to a typical
report chapter.

## 1. Abstract

The Zero Waste Smart Fridge is an Internet-of-Things project that helps reduce
food waste. Two ESP32 devices monitor a storage box: one reads environmental
sensors, the other provides a camera. Sensor data is shared through Firebase
Realtime Database, and a Flutter mobile application displays everything and
registers products by reading their QR codes. The design is intentionally
simple and realistic — no backend server and no machine learning.

## 2. Problem

Food is wasted at home because items are forgotten or their expiry dates are
not tracked. The system provides continuous monitoring and early warnings.

## 3. System architecture

The system has three parts:

1. **ESP32 DevKit (sensor controller).** It reads an MQ135 gas sensor, a
   DHT11 temperature/humidity sensor and an HX711 load-cell amplifier, and
   uploads the values to Firebase every few seconds with a timestamp.

2. **ESP32-CAM (camera).** It runs a CameraWebServer that continuously
   provides a live MJPEG stream and a snapshot endpoint. Each camera receives
   its own local IP from the Wi-Fi router, so the application lets the user
   enter the IP rather than hard-coding it.

3. **Flutter application.** It reads sensor data, products and the camera
   configuration from Firebase, shows the live camera stream, and registers
   products by capturing a frame from the camera and decoding the QR code.

## 4. Product registration

Products carry our own printed QR stickers containing a small JSON payload
(product id, name, category, expiry date, added date). The application
captures an image from the ESP32-CAM, decodes the QR code on the device, and
writes the product to Firebase. The product then appears in the app with an
expiry-based status (Fresh, Expiring Soon, Expired). There is no manual
product entry.

## 5. Cloud and the network model

Firebase Realtime Database is the link between the devices and the app.
Because the ESP32 DevKit uploads over Wi-Fi, the sensor data, products and
alerts are visible to every team member in real time, from anywhere — even
though the board is physically connected to a single computer.

The ESP32-CAM stream is different: it is served over plain HTTP on the local
network, so only a device on the same Wi-Fi as the camera can view it. The
application and documentation state this honestly and never fake a working
stream.

## 6. Alerts

The application derives alerts from the data it reads: a product is flagged
when it is expiring or expired, the ESP32 board is flagged when no sensor
update has arrived for 60 seconds, and the camera is flagged when it cannot
be reached.

## 7. Implementation

The repository contains the two ESP32 firmware sketches, the Flutter
application and documentation. No secrets are committed — Wi-Fi and Firebase
credentials use template files kept out of version control.

## 8. Testing

- Sensor uploads were verified in the Arduino Serial Monitor and the Firebase
  console.
- Offline detection was checked by powering the boards off.
- QR registration was verified with printed sample stickers.
- The application logic was covered with unit tests (expiry status, online
  detection, URL building, alert derivation).

## 9. Limitations

- The MQ135 is uncalibrated and gives a qualitative gas trend only.
- The camera stream is limited to the local network.

## 10. Conclusion

The project is a complete, honest IoT system — real sensors, a real camera, a
real cloud database and a clean mobile app — that is simple enough to build,
explain and demonstrate as a university project.
