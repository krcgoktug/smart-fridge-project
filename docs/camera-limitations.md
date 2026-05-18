# Camera Visibility & Limitations

This document explains, honestly, **where the live ESP32-CAM stream works and
where it does not** — and why. The project does not fake camera previews.

---

## 1. How the camera is reached

The ESP32-CAM runs a plain **HTTP** server on the local network:

| URL | Purpose |
|-----|---------|
| `http://<cam-ip>/` | HTML page with the live stream |
| `http://<cam-ip>/stream` | continuous multipart MJPEG stream |
| `http://<cam-ip>/capture` | a single JPEG frame |

Two consumers reach it:

- The **image analysis service** pulls `/capture` frames for QR + banana CV.
- The **Flutter app** displays the `/stream` MJPEG on the Camera screen.

Both must be on the **same Wi-Fi / LAN** as the ESP32-CAM. There is no
public/internet access to the camera — that is intentional for a local IoT
device.

---

## 2. The mixed-content limitation

The ESP32-CAM only speaks **HTTP** (it has no TLS certificate, and adding one
to an ESP32-CAM is impractical).

A web page served over **HTTPS** is not allowed by browsers to load an
**HTTP** resource — this is the *mixed content* security policy. So if the
Flutter app is built for the web and hosted on any HTTPS site, the browser
**blocks the camera stream**. This is a browser security rule, not a bug in
the app, and it cannot be worked around from the page.

> The previous version of this project tried to force the live camera into a
> hosted GitHub Pages build. That does not work and has been removed. The web
> build is not treated as a hardware-capable target.

---

## 3. Where the live stream works

| How the app runs | Live ESP32-CAM stream? |
|------------------|------------------------|
| **Android app** (`flutter build apk`, on the LAN) | ✅ Yes |
| **Local desktop run** (`flutter run`, on the LAN) | ✅ Yes |
| **Local web run** (`flutter run -d chrome`, http://localhost) | ✅ Usually — localhost is HTTP, no mixed content |
| **Web build hosted over HTTPS** | ❌ No — mixed content blocked |

The recommended way to demo the real camera is the **Android app on a phone
connected to the same Wi-Fi as the ESP32-CAM**.

---

## 4. What the app shows in each case

- **Stream reachable** → the live MJPEG plays on the Camera screen.
- **Stream not reachable** (wrong network, camera off, mixed content) → the
  Camera screen shows an honest "cannot reach the camera" message. It never
  shows a fake or placeholder image.
- The Camera screen also surfaces the `camera` node status (online / offline)
  that the image analysis service publishes to Firebase.

---

## 5. Summary

The camera is a **local HTTP device**. Use the **Android app or a local run**
on the **same Wi-Fi** for the real stream. A hosted HTTPS web build can show
the rest of the dashboard (sensors, products, banana analysis, alerts from
Firebase) but **not** the live camera — and that is stated in the app rather
than hidden.
