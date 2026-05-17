/*
 * cam_secrets.example.h  --  TEMPLATE, safe to commit.
 *
 * SETUP:
 *   1. Copy this file to "cam_secrets.h" in the same folder.
 *   2. Fill in your real values in cam_secrets.h.
 *   3. cam_secrets.h is git-ignored and must NEVER be committed.
 */
#ifndef CAM_SECRETS_H
#define CAM_SECRETS_H

// ---- Wi-Fi (use the SAME network as the phone and the sensor node) ----
#define WIFI_SSID      "YOUR_WIFI_SSID"
#define WIFI_PASSWORD  "YOUR_WIFI_PASSWORD"

// ---- Firebase Realtime Database (only used if WRITE_URLS_TO_FIREBASE) ----
// Database URL WITHOUT trailing slash.
#define FIREBASE_HOST  "https://YOUR-PROJECT-default-rtdb.firebaseio.com"
#define FIREBASE_AUTH  "YOUR_FIREBASE_DATABASE_SECRET_OR_TOKEN"

// ---- Device identity (must match the sensor node) ----
#define DEVICE_ID      "fridge_01"

#endif // CAM_SECRETS_H
