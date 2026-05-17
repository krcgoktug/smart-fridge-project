"""
Zero Waste Smart Fridge -- Optional Image Analysis Service
==========================================================

Lightweight banana browning detection. NO machine learning.

It uses classic image processing only:
  - HSV thresholding for brown/dark hues
  - RGB darkness check
  - brown-pixel ratio
  - simple status mapping

Pipeline:
  1. Fetch the latest JPEG from the ESP32-CAM /capture URL
     (or read a local file in --file mode).
  2. Compute `browningRatio` and `visualStatus`.
  3. Optionally PATCH the result into Firebase Realtime Database at
     /devices/<DEVICE_ID>/products/<PRODUCT_ID>.

This service is OPTIONAL. The Flutter app can do the same analysis itself;
this exists so the work can run on a laptop instead of the phone.

Config: copy .env.example -> .env  (see README.md). No secrets are committed.
"""

import io
import os
import sys
import time
import argparse

import numpy as np
from PIL import Image

try:
    import requests
except ImportError:  # pragma: no cover
    print("Missing dependency. Run: pip install -r requirements.txt")
    sys.exit(1)

# Optional .env loading (the service still runs without python-dotenv).
try:
    from dotenv import load_dotenv
    load_dotenv()
except ImportError:
    pass

from flask import Flask, jsonify, request


# --------------------------------------------------------------------------
# Configuration (all overridable via environment variables / .env)
# --------------------------------------------------------------------------
CAPTURE_URL = os.getenv("CAPTURE_URL", "http://172.19.15.112/capture")
FIREBASE_HOST = os.getenv("FIREBASE_HOST", "").rstrip("/")
FIREBASE_AUTH = os.getenv("FIREBASE_AUTH", "")
DEVICE_ID = os.getenv("DEVICE_ID", "fridge_01")
HTTP_PORT = int(os.getenv("PORT", "5000"))


# --------------------------------------------------------------------------
# Core image analysis -- the banana browning detector
# --------------------------------------------------------------------------
def analyze_browning(image: Image.Image) -> dict:
    """Return browningRatio (0..1) and visualStatus for a banana image.

    A pixel counts as "brown/dark" when it is either:
      * dark overall (low RGB brightness), or
      * a brownish hue in HSV with moderate-to-low value.

    Bright yellow banana pixels are explicitly excluded so a fresh banana
    scores near zero.
    """
    rgb = image.convert("RGB").resize((320, 240))
    arr = np.asarray(rgb).astype(np.float32)

    r, g, b = arr[..., 0], arr[..., 1], arr[..., 2]

    # --- RGB darkness: average brightness clearly below mid-range ---
    brightness = (r + g + b) / 3.0
    dark_mask = brightness < 90.0

    # --- HSV conversion (vectorised) ---
    hsv = np.asarray(rgb.convert("HSV")).astype(np.float32)
    h, s, v = hsv[..., 0], hsv[..., 1], hsv[..., 2]  # all 0..255

    # Brown hue band: roughly orange-brown (~15-45 deg -> ~10-32 on 0..255),
    # with enough saturation but a darkened value (not bright yellow).
    brown_mask = (h >= 10) & (h <= 35) & (s >= 60) & (v < 150)

    # --- Bright fresh-yellow pixels: explicitly NOT browning ---
    fresh_yellow = (h >= 28) & (h <= 50) & (v >= 170) & (s >= 80)

    brown_like = (dark_mask | brown_mask) & (~fresh_yellow)

    total = brown_like.size
    brown_pixels = int(np.count_nonzero(brown_like))
    ratio = round(brown_pixels / total, 3) if total else 0.0

    return {
        "browningRatio": ratio,
        "visualStatus": status_from_ratio(ratio),
        "brownPixels": brown_pixels,
        "totalPixels": total,
    }


def status_from_ratio(ratio: float) -> str:
    """Map a browning ratio to a human-readable visual status."""
    if ratio < 0.10:
        return "Fresh"
    if ratio < 0.25:
        return "Slight Browning"
    if ratio < 0.50:
        return "Browning Detected"
    return "Consume Soon"


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
# Firebase write-back (Realtime Database REST API)
# --------------------------------------------------------------------------
def update_product_in_firebase(product_id: str, result: dict) -> bool:
    """PATCH browningRatio + visualStatus onto a product node.

    Returns False (without raising) if Firebase is not configured, so the
    analysis still works as a pure local tool.
    """
    if not FIREBASE_HOST:
        print("[Firebase] FIREBASE_HOST not set -- skipping write-back.")
        return False

    url = (f"{FIREBASE_HOST}/devices/{DEVICE_ID}/products/"
           f"{product_id}.json")
    if FIREBASE_AUTH:
        url += f"?auth={FIREBASE_AUTH}"

    payload = {
        "browningRatio": result["browningRatio"],
        "visualStatus": result["visualStatus"],
        "updatedAt": int(time.time()),
    }
    resp = requests.patch(url, json=payload, timeout=10)
    if resp.ok:
        print(f"[Firebase] updated product '{product_id}'.")
        return True
    print(f"[Firebase] update failed: {resp.status_code} {resp.text}")
    return False


# --------------------------------------------------------------------------
# Flask HTTP API
# --------------------------------------------------------------------------
app = Flask(__name__)


@app.get("/health")
def health():
    return jsonify({"status": "ok", "captureUrl": CAPTURE_URL})


@app.post("/analyze")
def analyze_endpoint():
    """Analyze the current camera image for a given banana product.

    JSON body: {"productId": "banana_001"}  (productId optional)
    Query param ?write=false disables the Firebase write-back.
    """
    body = request.get_json(silent=True) or {}
    product_id = body.get("productId", "banana_001")
    write_back = request.args.get("write", "true").lower() != "false"

    try:
        image = fetch_capture_image()
    except Exception as exc:  # network / camera error
        return jsonify({"error": f"could not fetch image: {exc}"}), 502

    result = analyze_browning(image)

    written = False
    if write_back:
        written = update_product_in_firebase(product_id, result)

    return jsonify({
        "productId": product_id,
        "firebaseUpdated": written,
        **result,
    })


# --------------------------------------------------------------------------
# CLI entry point
# --------------------------------------------------------------------------
def main():
    parser = argparse.ArgumentParser(
        description="Smart Fridge banana browning analysis service.")
    parser.add_argument("--file", help="analyze a local image instead of "
                                       "fetching from the camera")
    parser.add_argument("--product", default="banana_001",
                        help="product id for Firebase write-back")
    parser.add_argument("--no-write", action="store_true",
                        help="do not write the result to Firebase")
    parser.add_argument("--serve", action="store_true",
                        help="run the Flask HTTP server")
    args = parser.parse_args()

    if args.serve:
        print(f"[Service] starting on http://0.0.0.0:{HTTP_PORT}")
        app.run(host="0.0.0.0", port=HTTP_PORT)
        return

    # One-shot CLI analysis.
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
        update_product_in_firebase(args.product, result)


if __name__ == "__main__":
    main()
