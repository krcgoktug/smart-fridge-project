"""
Zero Waste Smart Fridge -- Backend Processing Engine
====================================================

The backend is the intelligent processing layer of the system. It runs as a
continuous loop and, for each cycle:

  1. Pulls a snapshot frame from the ESP32-CAM.
  2. Decodes QR codes (OpenCV + pyzbar) and registers products in Firebase.
  3. Runs a real pixel-based banana browning analysis (HSV thresholding)
     and writes the result to Firebase.

There is NO machine learning and NO fake AI -- only classic computer vision.

Firebase paths written:
  devices/<id>/products/<slug>   { productName, expiryDate, detectedAt, source }
  devices/<id>/bananaAnalysis    { brownPercent, status, analyzedAt }

Config: copy .env.example -> .env and fill it in. No secrets are committed.

Run:
  python app.py            # continuous processing loop
  python app.py --once     # a single processing cycle
"""

import os
import re
import sys
import json
import time
import argparse

import numpy as np

try:
    import cv2
    import requests
    from pyzbar.pyzbar import decode as qr_decode
except ImportError as exc:  # pragma: no cover
    print(f"Missing dependency ({exc}). Run: pip install -r requirements.txt")
    print("Note: pyzbar needs the zbar library. On Debian/Ubuntu: "
          "sudo apt-get install libzbar0")
    sys.exit(1)

try:
    from dotenv import load_dotenv
    load_dotenv()
except ImportError:
    pass


# --------------------------------------------------------------------------
# Configuration (overridable via environment variables / .env)
# --------------------------------------------------------------------------
CAMERA_BASE_URL = os.getenv("CAMERA_BASE_URL", "http://192.168.1.50").rstrip("/")
FIREBASE_HOST = os.getenv("FIREBASE_HOST", "").rstrip("/")
FIREBASE_AUTH = os.getenv("FIREBASE_AUTH", "")
DEVICE_ID = os.getenv("DEVICE_ID", "fridge_01")
LOOP_INTERVAL = float(os.getenv("LOOP_INTERVAL", "5"))   # seconds per cycle

# Banana browning thresholds (percent of the banana region).
FRESH_MAX = 15.0
WARNING_MAX = 35.0


# --------------------------------------------------------------------------
# Camera
# --------------------------------------------------------------------------
def fetch_frame():
    """Fetch a single JPEG frame from the ESP32-CAM /capture endpoint and
    return it as a BGR numpy array (None on failure)."""
    url = f"{CAMERA_BASE_URL}/capture"
    try:
        resp = requests.get(url, timeout=10)
        resp.raise_for_status()
    except Exception as exc:
        print(f"[Camera] could not fetch {url}: {exc}")
        return None
    data = np.frombuffer(resp.content, dtype=np.uint8)
    frame = cv2.imdecode(data, cv2.IMREAD_COLOR)
    if frame is None:
        print("[Camera] frame could not be decoded.")
    return frame


# --------------------------------------------------------------------------
# QR detection (OpenCV frame + pyzbar)
# --------------------------------------------------------------------------
def detect_qr_products(frame):
    """Return a list of product dicts decoded from QR codes in the frame.

    Expected QR payload: {"product": "Milk", "expiry": "2026-05-25"}
    """
    products = []
    for symbol in qr_decode(frame):
        try:
            payload = json.loads(symbol.data.decode("utf-8"))
        except (ValueError, UnicodeDecodeError):
            print(f"[QR] non-JSON QR ignored: {symbol.data!r}")
            continue
        name = str(payload.get("product", "")).strip()
        expiry = str(payload.get("expiry", "")).strip()
        if name:
            products.append({"productName": name, "expiryDate": expiry})
    return products


def _slug(name):
    return re.sub(r"[^a-z0-9]+", "_", name.lower()).strip("_") or "product"


def register_product(product):
    """Write/update a product under devices/<id>/products/<slug>."""
    key = _slug(product["productName"])
    payload = {
        "productName": product["productName"],
        "expiryDate": product["expiryDate"],
        "detectedAt": int(time.time()),
        "source": "qr",
    }
    if _firebase_put(f"products/{key}", payload):
        print(f"[QR] registered product '{product['productName']}'.")


# --------------------------------------------------------------------------
# Banana browning analysis (real pixel-based computer vision, no ML)
# --------------------------------------------------------------------------
def analyze_banana(frame):
    """Estimate banana spoilage from dark/brown spot coverage using HSV
    colour thresholding. Returns {brownPercent, status, analyzedAt}."""
    hsv = cv2.cvtColor(frame, cv2.COLOR_BGR2HSV)

    # Healthy yellow banana flesh.
    yellow = cv2.inRange(hsv, (18, 70, 80), (40, 255, 255))
    # Brown overripe regions (warm hue, mid-low value).
    brown = cv2.inRange(hsv, (5, 50, 30), (25, 255, 170))
    # Very dark / black spots (low value).
    dark = cv2.inRange(hsv, (0, 0, 0), (180, 255, 55))

    spots = cv2.bitwise_or(brown, dark)
    banana = cv2.bitwise_or(yellow, spots)

    banana_pixels = int(cv2.countNonZero(banana))
    spot_pixels = int(cv2.countNonZero(spots))
    if banana_pixels == 0:
        brown_percent = 0.0
    else:
        brown_percent = round(spot_pixels / banana_pixels * 100.0, 1)

    if brown_percent < FRESH_MAX:
        status = "Fresh"
    elif brown_percent < WARNING_MAX:
        status = "Warning"
    else:
        status = "Rotten"

    return {
        "brownPercent": brown_percent,
        "status": status,
        "analyzedAt": int(time.time()),
    }


def write_banana_analysis(result):
    if _firebase_put("bananaAnalysis", result):
        print(f"[Banana] {result['brownPercent']}% -> {result['status']}")


# --------------------------------------------------------------------------
# Firebase Realtime Database (REST API)
# --------------------------------------------------------------------------
def _firebase_put(path, payload):
    if not FIREBASE_HOST:
        print(f"[Firebase] FIREBASE_HOST not set -- '{path}' not written.")
        return False
    url = f"{FIREBASE_HOST}/devices/{DEVICE_ID}/{path}.json"
    if FIREBASE_AUTH:
        url += f"?auth={FIREBASE_AUTH}"
    try:
        resp = requests.put(url, json=payload, timeout=10)
        if resp.ok:
            return True
        print(f"[Firebase] PUT {path} failed: {resp.status_code} {resp.text}")
    except Exception as exc:
        print(f"[Firebase] PUT {path} error: {exc}")
    return False


# --------------------------------------------------------------------------
# Processing cycle
# --------------------------------------------------------------------------
def process_once():
    """Run one full processing cycle."""
    frame = fetch_frame()
    if frame is None:
        return

    products = detect_qr_products(frame)
    for product in products:
        register_product(product)

    write_banana_analysis(analyze_banana(frame))


def main():
    parser = argparse.ArgumentParser(
        description="Smart Fridge backend processing engine.")
    parser.add_argument("--once", action="store_true",
                        help="run a single processing cycle and exit")
    args = parser.parse_args()

    print("=== Zero Waste Smart Fridge -- Backend Processing Engine ===")
    print(f"camera : {CAMERA_BASE_URL}")
    print(f"firebase: {FIREBASE_HOST or '(not configured)'}")

    if args.once:
        process_once()
        return

    print(f"Processing every {LOOP_INTERVAL}s. Press Ctrl+C to stop.")
    while True:
        try:
            process_once()
        except KeyboardInterrupt:
            print("\n[Engine] stopped.")
            break
        except Exception as exc:  # keep the loop alive
            print(f"[Engine] cycle error: {exc}")
        time.sleep(LOOP_INTERVAL)


if __name__ == "__main__":
    main()
