"""
Zero Waste Smart Fridge -- Image Analysis Service
=================================================

This service is the processing layer of the system. The ESP32-CAM only
serves images and the ESP32 DevKit only reads sensors -- all computer vision
runs here.

Each cycle the service:

  1. Pulls a snapshot frame from the ESP32-CAM /capture endpoint.
  2. Decodes product QR codes (OpenCV + pyzbar) and registers products.
  3. Runs a pixel-based banana browning analysis (HSV thresholding).
  4. Writes the camera online status.
  5. Recomputes the alert list from sensors, products and banana data.

There is NO machine learning and NO fake AI -- only classic computer vision.

Firebase paths written:
  devices/<id>/camera            { online, ip, lastFrameAt, frameWidth, frameHeight }
  devices/<id>/products/<id>     { productId, productName, category, expiryDate, ... }
  devices/<id>/bananaAnalysis    { brownPercent, visualStatus, status, analyzedAt }
  devices/<id>/alerts            { <alertId>: { type, message, severity, createdAt } }

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
from datetime import date, datetime

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

# Banana browning thresholds -- percent of the banana region.
# 0-15 Fresh | 15-35 Slight Browning | 35-60 Browning Detected | 60+ Spoilage Risk
FRESH_MAX = 15.0
SLIGHT_MAX = 35.0
BROWNING_MAX = 60.0

# A sensor heartbeat older than this many seconds means the board is offline.
SENSOR_OFFLINE_AFTER = 90
# Products inside this many days of expiry raise an "expiring soon" alert.
EXPIRY_WARNING_DAYS = 3


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


def write_camera_status(frame):
    """Publish the ESP32-CAM online status. The camera itself never writes to
    Firebase -- this service reports whether it could reach it."""
    online = frame is not None
    status = {
        "online": online,
        "ip": CAMERA_BASE_URL,
        "lastFrameAt": int(time.time()) if online else 0,
        "frameWidth": int(frame.shape[1]) if online else 0,
        "frameHeight": int(frame.shape[0]) if online else 0,
    }
    _firebase_put("camera", status)


# --------------------------------------------------------------------------
# QR detection (OpenCV frame + pyzbar)
# --------------------------------------------------------------------------
def detect_qr_products(frame):
    """Return a list of product dicts decoded from QR codes in the frame.

    Expected QR payload (our own printed stickers):
      {"productId": "banana_001", "name": "Banana",
       "expiryDate": "2026-05-25", "category": "Fruit"}
    """
    products = []
    for symbol in qr_decode(frame):
        try:
            payload = json.loads(symbol.data.decode("utf-8"))
        except (ValueError, UnicodeDecodeError):
            print(f"[QR] non-JSON QR ignored: {symbol.data!r}")
            continue
        product_id = str(payload.get("productId", "")).strip()
        name = str(payload.get("name", "")).strip()
        expiry = str(payload.get("expiryDate", "")).strip()
        category = str(payload.get("category", "")).strip()
        if product_id and name:
            products.append({
                "productId": product_id,
                "productName": name,
                "expiryDate": expiry,
                "category": category,
            })
        else:
            print(f"[QR] payload missing productId/name, ignored: {payload}")
    return products


def _slug(text):
    return re.sub(r"[^a-z0-9]+", "_", text.lower()).strip("_") or "product"


def register_product(product):
    """Write/update a product under devices/<id>/products/<productId>."""
    key = _slug(product["productId"])
    payload = {
        "productId": product["productId"],
        "productName": product["productName"],
        "category": product["category"],
        "expiryDate": product["expiryDate"],
        "detectedAt": int(time.time()),
        "source": "qr",
    }
    if _firebase_put(f"products/{key}", payload):
        print(f"[QR] registered '{product['productName']}' "
              f"({product['productId']}).")


# --------------------------------------------------------------------------
# Banana browning analysis (real pixel-based computer vision, no ML)
# --------------------------------------------------------------------------
def classify_banana(brown_percent):
    """Map a browning percentage to (visualStatus, status)."""
    if brown_percent < FRESH_MAX:
        return "Fresh", "Good"
    if brown_percent < SLIGHT_MAX:
        return "Slight Browning", "Monitor"
    if brown_percent < BROWNING_MAX:
        return "Browning Detected", "Consume Soon"
    return "Spoilage Risk", "Do Not Consume"


def analyze_banana(frame):
    """Estimate banana spoilage from dark/brown spot coverage using HSV
    colour thresholding. Returns {brownPercent, visualStatus, status,
    analyzedAt}."""
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

    visual_status, status = classify_banana(brown_percent)
    return {
        "brownPercent": brown_percent,
        "visualStatus": visual_status,
        "status": status,
        "analyzedAt": int(time.time()),
    }


def write_banana_analysis(result):
    if _firebase_put("bananaAnalysis", result):
        print(f"[Banana] {result['brownPercent']}% -> "
              f"{result['visualStatus']} ({result['status']})")


# --------------------------------------------------------------------------
# Alerts -- recomputed every cycle from sensors / products / banana data
# --------------------------------------------------------------------------
def _days_until(expiry_date):
    """Whole days from today to an ISO date string (negative if past).
    Returns None when the date is missing or unparseable."""
    if not expiry_date:
        return None
    try:
        target = datetime.strptime(expiry_date, "%Y-%m-%d").date()
    except ValueError:
        return None
    return (target - date.today()).days


def build_alerts(banana):
    """Recompute the full alert set. Returns a dict keyed by a stable alert
    id; an empty dict clears all alerts."""
    alerts = {}
    now = int(time.time())

    # --- ESP32 sensor board ---
    sensors = _firebase_get("sensors") or {}
    updated_at = sensors.get("updatedAt", 0) or 0
    if not sensors or (now - int(updated_at)) > SENSOR_OFFLINE_AFTER:
        alerts["esp32_offline"] = {
            "type": "sensor",
            "message": "ESP32 sensor board is offline -- no live sensor data.",
            "severity": "warning",
            "createdAt": now,
        }
    else:
        temperature = sensors.get("temperature")
        if isinstance(temperature, (int, float)) and temperature > 10:
            alerts["fridge_temp_high"] = {
                "type": "sensor",
                "message": f"Fridge temperature is high ({temperature} C).",
                "severity": "warning",
                "createdAt": now,
            }
        gas = sensors.get("gas")
        if isinstance(gas, (int, float)) and gas > 2000:
            alerts["air_quality"] = {
                "type": "sensor",
                "message": "Air quality degraded -- possible spoilage gas.",
                "severity": "warning",
                "createdAt": now,
            }

    # --- Product expiry ---
    products = _firebase_get("products") or {}
    for key, product in products.items():
        if not isinstance(product, dict):
            continue
        name = product.get("productName", key)
        days = _days_until(product.get("expiryDate", ""))
        if days is None:
            continue
        if days < 0:
            alerts[f"expired_{key}"] = {
                "type": "expiry",
                "message": f"{name} has expired.",
                "severity": "danger",
                "createdAt": now,
            }
        elif days <= EXPIRY_WARNING_DAYS:
            alerts[f"expiring_{key}"] = {
                "type": "expiry",
                "message": f"{name} expires in {days} day(s).",
                "severity": "warning",
                "createdAt": now,
            }

    # --- Banana spoilage ---
    visual = banana.get("visualStatus")
    if visual == "Spoilage Risk":
        alerts["banana_spoilage"] = {
            "type": "banana",
            "message": "Banana shows spoilage risk -- do not consume.",
            "severity": "danger",
            "createdAt": now,
        }
    elif visual == "Browning Detected":
        alerts["banana_spoilage"] = {
            "type": "banana",
            "message": "Banana browning detected -- consume soon.",
            "severity": "warning",
            "createdAt": now,
        }

    return alerts


def write_alerts(alerts):
    # PUT replaces the whole node, so cleared conditions disappear.
    if _firebase_put("alerts", alerts):
        print(f"[Alerts] {len(alerts)} active alert(s).")


# --------------------------------------------------------------------------
# Firebase Realtime Database (REST API)
# --------------------------------------------------------------------------
def _firebase_url(path):
    url = f"{FIREBASE_HOST}/devices/{DEVICE_ID}/{path}.json"
    if FIREBASE_AUTH:
        url += f"?auth={FIREBASE_AUTH}"
    return url


def _firebase_put(path, payload):
    if not FIREBASE_HOST:
        print(f"[Firebase] FIREBASE_HOST not set -- '{path}' not written.")
        return False
    try:
        resp = requests.put(_firebase_url(path), json=payload, timeout=10)
        if resp.ok:
            return True
        print(f"[Firebase] PUT {path} failed: {resp.status_code} {resp.text}")
    except Exception as exc:
        print(f"[Firebase] PUT {path} error: {exc}")
    return False


def _firebase_get(path):
    if not FIREBASE_HOST:
        return None
    try:
        resp = requests.get(_firebase_url(path), timeout=10)
        if resp.ok:
            return resp.json()
        print(f"[Firebase] GET {path} failed: {resp.status_code}")
    except Exception as exc:
        print(f"[Firebase] GET {path} error: {exc}")
    return None


# --------------------------------------------------------------------------
# Processing cycle
# --------------------------------------------------------------------------
def process_once():
    """Run one full processing cycle."""
    frame = fetch_frame()
    write_camera_status(frame)
    if frame is None:
        # Camera unreachable: still refresh alerts from sensors/products.
        write_alerts(build_alerts({}))
        return

    for product in detect_qr_products(frame):
        register_product(product)

    banana = analyze_banana(frame)
    write_banana_analysis(banana)

    write_alerts(build_alerts(banana))


def main():
    parser = argparse.ArgumentParser(
        description="Smart Fridge image analysis service.")
    parser.add_argument("--once", action="store_true",
                        help="run a single processing cycle and exit")
    args = parser.parse_args()

    print("=== Zero Waste Smart Fridge -- Image Analysis Service ===")
    print(f"camera  : {CAMERA_BASE_URL}")
    print(f"firebase: {FIREBASE_HOST or '(not configured)'}")

    if args.once:
        process_once()
        return

    print(f"Processing every {LOOP_INTERVAL}s. Press Ctrl+C to stop.")
    while True:
        try:
            process_once()
        except KeyboardInterrupt:
            print("\n[Service] stopped.")
            break
        except Exception as exc:  # keep the loop alive
            print(f"[Service] cycle error: {exc}")
        time.sleep(LOOP_INTERVAL)


if __name__ == "__main__":
    main()
