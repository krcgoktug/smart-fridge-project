"""
Zero Waste Smart Fridge - Arduino Uno serial -> local HTTP bridge
=================================================================

Reads JSON lines from the Arduino Uno over USB and serves the latest
reading on a tiny HTTP endpoint that the Flutter web app polls.

JSON line emitted by the Arduino (one per second):
    {"temperature": 24.3, "humidity": 45, "gasValue": 312, "weight": 1234}

The bridge serves:
    GET  http://localhost:8787/sensors
        -> {"temperature":..., "humidity":..., "gasValue":...,
            "weight":..., "updatedAt":<unix seconds>, "online":true}

The endpoint always responds with permissive CORS headers so the
Flutter app (served from a different origin, e.g. localhost:8080) can
read it from the browser.

Usage
-----
    pip install pyserial
    python arduino_serial_bridge.py                # auto-detect COM port
    python arduino_serial_bridge.py --port COM5    # force a specific port
    python arduino_serial_bridge.py --baud 9600 --http-port 8787

Stop with Ctrl+C.
"""

from __future__ import annotations

import argparse
import json
import sys
import threading
import time
from dataclasses import dataclass, field
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

try:
    import serial               # pyserial
    from serial.tools import list_ports
except ImportError:
    print("ERROR: pyserial is not installed. Run:  pip install pyserial",
          file=sys.stderr)
    sys.exit(1)


# ---------------------------------------------------------------------------
# Shared state between the serial-reader thread and the HTTP handler
# ---------------------------------------------------------------------------
@dataclass
class SensorState:
    temperature: float = 0.0
    humidity: float = 0.0
    gasValue: int = 0
    weight: int = 0
    updatedAt: int = 0                  # unix seconds; 0 = never
    lock: threading.Lock = field(default_factory=threading.Lock)

    def update(self, payload: dict) -> None:
        with self.lock:
            self.temperature = float(payload.get("temperature", 0))
            self.humidity = float(payload.get("humidity", 0))
            self.gasValue = int(payload.get("gasValue", 0))
            self.weight = int(payload.get("weight", 0))
            self.updatedAt = int(time.time())

    def snapshot(self) -> dict:
        with self.lock:
            now = int(time.time())
            return {
                "temperature": self.temperature,
                "humidity": self.humidity,
                "gasValue": self.gasValue,
                "weight": self.weight,
                "updatedAt": self.updatedAt,
                "online": self.updatedAt > 0 and (now - self.updatedAt) <= 5,
            }


STATE = SensorState()


# ---------------------------------------------------------------------------
# Serial reader thread
# ---------------------------------------------------------------------------
def auto_detect_port() -> str | None:
    """Try to pick an Arduino-looking COM port automatically."""
    candidates = list(list_ports.comports())
    for p in candidates:
        desc = (p.description or "").lower()
        manuf = (p.manufacturer or "").lower()
        if "arduino" in desc or "arduino" in manuf or "ch340" in desc \
                or "wch" in manuf or "usb-serial" in desc:
            return p.device
    # Fall back to the first available port if there's only one.
    if len(candidates) == 1:
        return candidates[0].device
    return None


def serial_reader_loop(port: str, baud: int) -> None:
    """Open the serial port and feed STATE with every JSON line that arrives."""
    print(f"[serial] opening {port} @ {baud}")
    while True:
        try:
            with serial.Serial(port, baudrate=baud, timeout=2) as ser:
                # Give the Arduino time to reset after the port opens.
                time.sleep(2)
                ser.reset_input_buffer()
                print(f"[serial] {port} connected, listening for JSON lines")
                while True:
                    raw = ser.readline()
                    if not raw:
                        continue
                    line = raw.decode("utf-8", errors="ignore").strip()
                    if not line or not line.startswith("{"):
                        continue
                    try:
                        payload = json.loads(line)
                    except json.JSONDecodeError:
                        continue
                    STATE.update(payload)
                    print(f"[serial] {payload}")
        except (serial.SerialException, OSError) as ex:
            print(f"[serial] {port} error: {ex}. retrying in 3 s ...")
            time.sleep(3)


# ---------------------------------------------------------------------------
# HTTP handler
# ---------------------------------------------------------------------------
class SensorHandler(BaseHTTPRequestHandler):
    # Silence the default per-request access log
    def log_message(self, format: str, *args) -> None:  # noqa: A003
        return

    def _send_cors(self) -> None:
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        self.send_header("Cache-Control", "no-store")

    def do_OPTIONS(self) -> None:  # noqa: N802
        self.send_response(204)
        self._send_cors()
        self.end_headers()

    def do_GET(self) -> None:  # noqa: N802
        if self.path.rstrip("/") not in ("/sensors", "/"):
            self.send_response(404)
            self._send_cors()
            self.end_headers()
            return
        body = json.dumps(STATE.snapshot()).encode("utf-8")
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self._send_cors()
        self.end_headers()
        self.wfile.write(body)


def run_http(port: int) -> None:
    server = ThreadingHTTPServer(("0.0.0.0", port), SensorHandler)
    print(f"[http]   listening on http://localhost:{port}/sensors")
    server.serve_forever()


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------
def main() -> None:
    parser = argparse.ArgumentParser(
        description="Arduino Uno serial -> local HTTP bridge")
    parser.add_argument("--port", default=None,
                        help="Serial port (e.g. COM5). Auto-detected if omitted.")
    parser.add_argument("--baud", type=int, default=9600,
                        help="Serial baud rate (default: 9600).")
    parser.add_argument("--http-port", type=int, default=8787,
                        help="HTTP port to serve on (default: 8787).")
    args = parser.parse_args()

    port = args.port or auto_detect_port()
    if port is None:
        ports = list(list_ports.comports())
        print("ERROR: could not auto-detect an Arduino port.", file=sys.stderr)
        if ports:
            print("Available ports:", file=sys.stderr)
            for p in ports:
                print(f"  {p.device}  -  {p.description}", file=sys.stderr)
        else:
            print("No serial ports found - is the Arduino plugged in?",
                  file=sys.stderr)
        sys.exit(2)

    threading.Thread(
        target=serial_reader_loop, args=(port, args.baud), daemon=True
    ).start()

    try:
        run_http(args.http_port)
    except KeyboardInterrupt:
        print("\nstopping.")


if __name__ == "__main__":
    main()
