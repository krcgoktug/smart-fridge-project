"""Smart Fridge — optional banana browning analysis service.

A small Flask app that the mobile app can POST images to, gets back a
ripeness band. The image processing pipeline (segmentation, RGB band
classification) lives in the team archive.
"""

from flask import Flask, jsonify, request

app = Flask(__name__)


@app.route("/health")
def health():
    return jsonify(status="ok")


@app.route("/analyze", methods=["POST"])
def analyze():
    # image = request.files.get("image")
    # band = classify_browning(image)
    return jsonify(error="analysis pipeline not loaded", band=None), 503


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
