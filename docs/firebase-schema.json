{
  "_comment": "Firebase Realtime Database layout for the Zero Waste Smart Fridge. Recreate this structure or import it. Timestamps are Unix seconds.",
  "devices": {
    "fridge_01": {
      "sensors": {
        "_comment": "Written by the ESP32 DevKit every 10 s. The app shows 'ESP32 Offline' when updatedAt is older than 60 s.",
        "weight": 482,
        "temperature": 5.8,
        "gas": 1350,
        "updatedAt": 1710000000,
        "alive": true
      },
      "products": {
        "_comment": "Written by the Python backend when it decodes a product QR code. The node key is a slug of the product name.",
        "milk": {
          "productName": "Milk",
          "expiryDate": "2026-05-25",
          "detectedAt": 1710000000,
          "source": "qr"
        }
      },
      "bananaAnalysis": {
        "_comment": "Written by the Python backend after each banana browning analysis cycle.",
        "brownPercent": 18.4,
        "status": "Warning",
        "analyzedAt": 1710000000
      }
    }
  }
}
