/*
 * cam_secrets.example.h  --  TEMPLATE, safe to commit.
 *
 * SETUP:
 *   1. Copy this file to "cam_secrets.h" in the same folder.
 *   2. Fill in your real Wi-Fi values in cam_secrets.h.
 *   3. cam_secrets.h is git-ignored and must NEVER be committed.
 *
 * The ESP32-CAM is camera-only: it needs Wi-Fi, nothing else.
 */
#ifndef CAM_SECRETS_H
#define CAM_SECRETS_H

// ---- Wi-Fi (use the SAME network as the phone running the app) ----
#define WIFI_SSID      "YOUR_WIFI_SSID"
#define WIFI_PASSWORD  "YOUR_WIFI_PASSWORD"

#endif // CAM_SECRETS_H
