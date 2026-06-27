# Contributors

This file documents the people who have contributed code, design, or
infrastructure to this repository, as reflected in its git history.
For an authoritative, per-commit record, see the `git log`.

---

## Primary contributor

### Göktuğ Karaca — [@krcgoktug](https://github.com/krcgoktug)

**Role:** Author of the entire codebase as of the
`v1.0-goktug-final-contribution` tag — firmware, USB serial bridge,
Flutter mobile/web application, deployment configuration, and
documentation.

**Period of active contribution:** 2026-05-17 → 2026-06-26

**Contribution summary** (auto-generated from `git log`):

- **46** commits authored
- **416** files touched
- ~**228,000** lines added across firmware, bridge, Flutter app, and docs

**Specific subsystems authored:**

| Subsystem | Path | Notes |
| --- | --- | --- |
| Arduino UNO firmware | `firmware/arduino-uno/` | DHT11 + MQ135 + HX711 sensor reader, JSON serial output, runtime tare & gas recalibration commands |
| HX711 calibration sketch | `firmware/arduino-uno-calibration/` | One-shot weight calibration helper |
| ESP32-CAM firmware | `firmware/esp32-cam/` | Camera HTTP server, MJPEG stream, JPEG capture |
| USB-serial bridge | `bridge/arduino_serial_bridge.py` | Python serial → HTTP gateway, auto port detect, `/sensors` `/tare` `/recalibrate_gas` endpoints |
| Flutter application | `mobile/smart_fridge_app/` | Dashboard, Camera, Products, Alerts, Settings — including multi-QR tiled decoder and banana ripeness analysis |
| Web build / Pages deploy | `docs/`, `serve_local.py` | GitHub Pages-ready build + local-dev HTTP server |
| Demo QR generator | `qr-samples-demo/` | Python QR PNG/PDF generator |
| Documentation | `README.md`, `docs/*.md` | Architecture, wiring, English + Turkish setup guides |

**Snapshot tag:** [`v1.0-goktug-final-contribution`](../../tree/v1.0-goktug-final-contribution)
— marks the state of the codebase as of the end of this author's
active contribution period.

---

## Note on future contributions

Commits made to this repository **after** the
`v1.0-goktug-final-contribution` tag may be authored by other
contributors. Their work, if any, is reflected in the git log from
that point onward and should be attributed accordingly in any
publication, presentation, patent application, or commercialization
effort derived from this codebase.

Any redistribution, academic publication (including IEEE submissions),
TÜBİTAK / similar grant proposals, patent applications, or
commercialization of code at or before the
`v1.0-goktug-final-contribution` tag must accurately credit the
primary contributor listed above, in accordance with:

- **FSEK (Fikir ve Sanat Eserleri Kanunu) m. 14-17** — non-waivable
  moral rights of the author, including the right to be named.
- **IEEE Publication Ethics** (Section 8.2.1.A.2) — authorship must
  reflect actual contribution; ghost authorship is a violation.
- **YÖK Bilimsel Araştırma ve Yayın Etiği Yönergesi m. 4** —
  attribution requirements for academic publications.

---

*This file is part of the canonical project history. It is committed
to the main branch and preserved in the immutable git log.*
