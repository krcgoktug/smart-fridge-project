/*
 * secrets.example.h  --  TEMPLATE, safe to commit.
 *
 * SETUP:
 *   1. Copy this file to "secrets.h" in the same folder.
 *   2. Fill in your real Wi-Fi and Firebase values in secrets.h.
 *   3. secrets.h is git-ignored and must NEVER be committed.
 *
 * Do not put real credentials in this template file.
 */
#ifndef SECRETS_H
#define SECRETS_H

// ---- Wi-Fi ----
#define WIFI_SSID      "YOUR_WIFI_SSID"
#define WIFI_PASSWORD  "YOUR_WIFI_PASSWORD"

// ---- Firebase Realtime Database ----
// Database URL WITHOUT trailing slash, e.g.
//   https://smart-fridge-xxxx-default-rtdb.firebaseio.com
#define FIREBASE_HOST  "https://YOUR-PROJECT-default-rtdb.firebaseio.com"

// Database secret OR a long-lived auth token used as the ?auth= query param.
// For a class demo you may temporarily use test-mode rules and leave this
// blank, but a token is recommended.
#define FIREBASE_AUTH  "YOUR_FIREBASE_DATABASE_SECRET_OR_TOKEN"

// ---- Device identity ----
#define DEVICE_ID      "fridge_01"

#endif // SECRETS_H
