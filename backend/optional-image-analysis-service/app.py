"""
Zero Waste Smart Fridge -- Optional Image Analysis Service
==========================================================

An OPTIONAL helper service. The Flutter app already does all of this on the
phone; this lets the same work run on a laptop instead.

It mirrors two camera-driven features:

  1. QR product registration  -- fetch the ESP32-CAM image, decode the QR
     code, and save the product under /devices/<id>/products/<productId>.

  2. Banana browning analysis  -- pixel-based (NO machine learning):
       brownSpotPercentage, darkSpotPercentage, totalBrowningPercentage
     are computed from simple RGB thresholds and saved under
     /devices/<id>/bananaAnalysis/<productId>.

The ESP32-CAM only provides the image; decoding/analysis happens here.
There is no load-cell dependency anywhere.

Config: copy .env.example -> .env  (see README.md). No secrets are committed.
"""

import io
import os
import sys
import json
import time
import argparse
from datetime import datetime

import numpy as np
from PIL import Image

# OpenCV is only needed for QR-code decoding.
try:
    import cv2
except ImportError:  # pragma: no cover
    cv2 = None

try:
    import requests
except ImportError:  # pragma: no cover
    print("Missing dependency. Run: pip install -r requirements.txt")
    sys.exit(1)

try:
    from dotenv import load_dotenv
    load_dotenv()
except ImportError:
    pass

from flask import Flask, jsonify, request


# --------------------------------------------------------------------------
# Configuration (all overridable via environment variables / .env)
# --------------------------------------------------------------------------
CAPTURE_URL = os.getenv("CAPTURE_URL", "http://192.168.1.50/capture")
FIREBASE_HOST = os.getenv("FIREBASE_HOST", "").rstrip("/")
FIREBASE_AUTH = os.getenv("FIREBASE_AUTH", "")
DEVICE_ID = os.getenv("DEVICE_ID", "fridge_01")
HTTP_PORT = int(os.getenv("PORT", "5000"))


# --------------------------------------------------------------------------
# Banana browning analysis -- pixel-based, no ML
# --------------------------------------------------------------------------
def status_from_percentage(total: float) -> str:
    """Map a total browning percentage (0-100) to a visual status."""
    if total >= 50:
        return "Consume Soon"
    if total >= 25:
        return "Browning Detected"
    if total >= 10:
        return "Slight Browning"
    return "Fresh"


def analyze_browning(image: Image.Image) -> dict:
    """Classify each pixel with simple RGB thresholds and return the
    brown / dark / total browning percentages of the banana region.
    """
    rgb = image.convert("RGB").resize((320, 240))
    arr = np.asarray(rgb).astype(np.int32)
    r, g, b = arr[..., 0], arr[..., 1], arr[..., 2]
    brightness = (r + g + b) / 3.0

    dark = brightness < 60
    brown = (~dark) & (brightness < 150) & (r > 60) & (r >= g) & \
            (g >= b) & ((r - b) > 25)
    yellow = (~dark) & (~brown) & (r > 140) & (g > 120) & ((r - b) > 45)

    banana = dark | brown | yellow
    banana_count = int(np.count_nonzero(banana))
    if banana_count == 0:
        return {
            "brownSpotPercentage": 0.0,
            "darkSpotPercentage": 0.0,
            "totalBrowningPercentage": 0.0,
            "visualStatus": "Fresh",
        }

    brown_pct = round(int(np.count_nonzero(brown)) / banana_count * 100, 1)
    dark_pct = round(int(np.count_nonzero(dark)) / banana_count * 100, 1)
    total = round(brown_pct + dark_pct, 1)
    return {
        "brownSpotPercentage": brown_pct,
        "darkSpotPercentage": dark_pct,
        "totalBrowningPercentage": total,
        "visualStatus": status_from_percentage(total),
    }


# --------------------------------------------------------------------------
# QR-code decoding
# --------------------------------------------------------------------------
def decode_qr_from_image(image: Image.Image):
    """Decode a QR code from a PIL image. Returns the text, or None."""
    if cv2 is None:
        raise RuntimeError(
            "opencv-python is required for QR decoding. "
            "Run: pip install -r requirements.txt")
    frame = np.asarray(image.convert("RGB"))
    data, _points, _qr = cv2.QRCodeDetector().detectAndDecode(frame)
    return data if data else None


# --------------------------------------------------------------------------
# Image acquisition
# --------------------------------------------------------------------------
def fetch_capture_image(url: str = None) -> Image.Image:
    """Download a single JPEG frame from the ESP32-CAM /capture endpoint."""
    url = url or CAPTURE_URL
    resp = requests.get(url, timeout=10)
    resp.raise_for_status()
    return Image.open(io.BytesIO(resp.content))


def load_image_file(path: str) -> Image.Image:
    """Load an image from a local file (offline / demo fallback)."""
    return Image.open(path)


# --------------------------------------------------------------------------
# Firebase Realtime Database (REST API)
# --------------------------------------------------------------------------
def _node_url(path: str) -> str:
    url = f"{FIREBASE_HOST}/devices/{DEVICE_ID}/{path}.json"
    if FIREBASE_AUTH:
        url += f"?auth={FIREBASE_AUTH}"
    return url


def save_banana_analysis(product_id: str, result: dict) -> bool:
    """Write a browning result to /bananaAnalysis/<id> and mirror the
    browning figure onto the product so the risk score stays consistent.
    """
    if not FIREBASE_HOST:
        print("[Firebase] FIREBASE_HOST not set -- skipping write-back.")
        return False

    payload = {"productId": product_id, "updatedAt": int(time.time()), **result}
    resp = requests.put(_node_url(f"bananaAnalysis/{product_id}"),
                        json=payload, timeout=10)
    requests.patch(_node_url(f"products/{product_id}"), json={
        "browningRatio": result["totalBrowningPercentage"] / 100.0,
        "visualStatus": result["visualStatus"],
        "updatedAt": int(time.time()),
    }, timeout=10)
    if resp.ok:
        print(f"[Firebase] saved bananaAnalysis for '{product_id}'.")
        return True
    print(f"[Firebase] write failed: {resp.status_code} {resp.text}")
    return False


def save_product(product: dict) -> bool:
    """Write a product under /devices/<id>/products/<productId>."""
    pid = product.get("productId")
    if not pid or not FIREBASE_HOST:
        return False
    try:
        expiry = datetime.fromisoformat(str(product["expiryDate"]))
        hours = int((expiry - datetime.now()).total_seconds() // 3600)
        product["remainingHours"] = max(hours, 0)
    except Exception:
        pass
    product["updatedAt"] = int(time.time())
    resp = requests.put(_node_url(f"products/{pid}"), json=product, timeout=10)
    return resp.ok


def register_product_from_camera() -> dict:
    """Fetch the camera image, decode its QR code and register the product."""
    image = fetch_capture_image()
    qr_text = decode_qr_from_image(image)
    if not qr_text:
        return {"ok": False, "error": "no QR code found in the image"}
    try:
        product = json.loads(qr_text)
    except json.JSONDecodeError:
        return {"ok": False, "error": "QR content is not valid JSON"}
    if not isinstance(product, dict) or not product.get("productId"):
        return {"ok": False, "error": "QR JSON missing productId"}
    return {"ok": save_product(product), "product": product}


# --------------------------------------------------------------------------
# Flask HTTP API
# --------------------------------------------------------------------------
app = Flask(__name__)


@app.get("/health")
def health():
    return jsonify({"status": "ok", "captureUrl": CAPTURE_URL})


@app.post("/analyze")
def analyze_endpoint():
    """Analyze the current camera image for banana browning.

    JSON body: {"productId": "banana_001"}  (productId optional)
    Query param ?write=false disables the Firebase write-back.
    """
    body = request.get_json(silent=True) or {}
    product_id = body.get("productId", "banana_001")
    write_back = request.args.get("write", "true").lower() != "false"

    try:
        image = fetch_capture_image()
    except Exception as exc:
        return jsonify({"error": f"could not fetch image: {exc}"}), 502

    result = analyze_browning(image)
    written = save_banana_analysis(product_id, result) if write_back else False
    return jsonify({"productId": product_id, "firebaseUpdated": written,
                    **result})


@app.post("/register")
def register_endpoint():
    """Capture the camera image, decode its QR code and register the product."""
    try:
        result = register_product_from_camera()
    except Exception as exc:
        return jsonify({"ok": False, "error": str(exc)}), 502
    return jsonify(result), 200 if result.get("ok") else 422


# --------------------------------------------------------------------------
# CLI entry point
# --------------------------------------------------------------------------
def main():
    parser = argparse.ArgumentParser(
        description="Smart Fridge image analysis service (optional).")
    parser.add_argument("--file", help="analyze a local image instead of "
                                       "fetching from the camera")
    parser.add_argument("--product", default="banana_001",
                        help="product id for the banana analysis write-back")
    parser.add_argument("--no-write", action="store_true",
                        help="do not write the result to Firebase")
    parser.add_argument("--serve", action="store_true",
                        help="run the Flask HTTP server")
    parser.add_argument("--register", action="store_true",
                        help="capture once, decode the QR and register it")
    args = parser.parse_args()

    if args.serve:
        print(f"[Service] starting on http://0.0.0.0:{HTTP_PORT}")
        app.run(host="0.0.0.0", port=HTTP_PORT)
        return

    if args.register:
        print(register_product_from_camera())
        return

    # One-shot banana browning analysis.
    if args.file:
        print(f"[CLI] analyzing local file: {args.file}")
        image = load_image_file(args.file)
    else:
        print(f"[CLI] fetching image from: {CAPTURE_URL}")
        image = fetch_capture_image()

    result = analyze_browning(image)
    print("[CLI] result:")
    for k, v in result.items():
        print(f"  {k}: {v}")

    if not args.no_write:
        save_banana_analysis(args.product, result)


if __name__ == "__main__":
    main()
