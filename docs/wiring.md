# Wiring Guide

Wiring tables for both ESP32 boards. **Always wire with power disconnected.**

---

## 1. ESP32 DevKit V1 — Sensor node

Board: ESP32 DevKit V1 (30-pin). All sensors share the board's `GND`.

### 1.1 DHT11 — Temperature & Humidity

| DHT11 pin | ESP32 DevKit pin | Notes |
|-----------|------------------|-------|
| VCC (+)   | 3V3              | 3.3 V |
| DATA      | GPIO 4           | 10 kΩ pull-up to 3V3 recommended |
| GND (-)   | GND              | |

### 1.2 MQ135 — Air Quality / Gas

| MQ135 pin | ESP32 DevKit pin | Notes |
|-----------|------------------|-------|
| VCC       | VIN (5V)         | Heater needs 5 V |
| AOUT      | GPIO 34          | ADC1 input-only pin |
| DOUT      | not connected    | Digital threshold unused |
| GND       | GND              | |

> GPIO 34 is input-only and ADC1 — safe to use while Wi-Fi is active.
> Let the MQ135 heat up for 1-2 minutes before trusting readings.

### 1.3 HX711 + 4 Load Cells — Weight

The 4 load cells are combined into one full Wheatstone bridge feeding a single
HX711 module.

| HX711 pin | ESP32 DevKit pin | Notes |
|-----------|------------------|-------|
| VCC       | 3V3              | 3.3 V logic |
| GND       | GND              | |
| DT (DOUT) | GPIO 16          | Data |
| SCK       | GPIO 17          | Clock |

Load cell -> HX711 bridge wiring (typical 4 x half-bridge cells):

| Combined bridge wire | HX711 pad |
|----------------------|-----------|
| Excitation +         | E+        |
| Excitation -         | E-        |
| Signal +             | A+        |
| Signal -             | A-        |

> Calibrate `HX711_CALIBRATION_FACTOR` in the firmware with a known weight.

### 1.4 ESP32 DevKit V1 — Pin summary

| Function | GPIO |
|----------|------|
| DHT11 DATA | 4 |
| MQ135 AOUT | 34 (ADC, input-only) |
| HX711 DT   | 16 |
| HX711 SCK  | 17 |

Power: USB 5 V, or regulated 5 V into `VIN`.

---

## 2. ESP32-CAM AI Thinker — Camera node

The ESP32-CAM has **no USB port**. Flash it with an FTDI / USB-TTL adapter set
to **3.3 V logic** (5 V to the `5V` pin is fine for power).

### 2.1 Flashing connection (FTDI <-> ESP32-CAM)

| FTDI pin | ESP32-CAM pin |
|----------|---------------|
| 5V       | 5V            |
| GND      | GND           |
| TX       | U0R (RX)      |
| RX       | U0T (TX)      |

To enter flash mode: connect **GPIO 0 -> GND**, then power-cycle / press
RESET. Remove the GPIO 0 jumper after flashing and reset to run normally.

### 2.2 Normal operation

| ESP32-CAM pin | Connect to |
|---------------|------------|
| 5V            | 5 V supply (>= 500 mA) |
| GND           | Supply GND |
| GPIO 0        | leave open (only grounded for flashing) |

The OV2640 camera ribbon is already attached to the module — no extra wiring.
**No SD card is used.**

> The camera draws current spikes; use a solid 5 V supply or the board will
> brown-out and reboot.

---

## 3. Shared notes

- Keep a common ground reference if both boards share a supply.
- Place the MQ135 away from the camera's heat and away from the box wall vent.
- Mount the load cells flat under the box base so the whole box weight is
  measured.
