# Banana Browning Analysis

Banana spoilage is estimated with **real, lightweight computer vision** — not
machine learning and not a fake AI label. The method is classic OpenCV colour
segmentation, which is fast, explainable and needs no training data.

Implementation: [`backend/image-analysis-service/app.py`](../backend/image-analysis-service/app.py)
(`analyze_banana`).

---

## 1. Method

For each camera frame:

1. Convert the frame from BGR to the **HSV** colour space (HSV separates hue
   from brightness, so colour thresholds are stable under light changes).
2. Build three binary masks with `cv2.inRange`:
   - **yellow** — healthy banana flesh,
   - **brown** — overripe regions,
   - **dark** — black/brown spots.
3. `spots = brown OR dark` and `banana = yellow OR spots`.
4. Compute the spot coverage:

   ```
   brownPercent = (brown + dark pixels) / banana region pixels * 100
   ```

This is the **percentage of black/brown spots on the banana** — exactly the
quantity the project set out to measure.

### HSV thresholds (current values)

| Mask | HSV low | HSV high |
|------|---------|----------|
| yellow | (18, 70, 80) | (40, 255, 255) |
| brown  | (5, 50, 30)  | (25, 255, 170) |
| dark   | (0, 0, 0)    | (180, 255, 55) |

These are tuned for the enclosed box lighting and can be adjusted.

---

## 2. Status mapping

`brownPercent` maps to a `visualStatus` (what the camera sees) and a `status`
(what the user should do):

| brownPercent | visualStatus | status |
|--------------|-------------------|----------------|
| `0 – 15 %`   | Fresh             | Good           |
| `15 – 35 %`  | Slight Browning   | Monitor        |
| `35 – 60 %`  | Browning Detected | Consume Soon   |
| `60 %+`      | Spoilage Risk     | Do Not Consume |

Result written to `devices/fridge_01/bananaAnalysis`:

```json
{
  "brownPercent": 37,
  "visualStatus": "Browning Detected",
  "status": "Consume Soon",
  "analyzedAt": 1710000000
}
```

`Browning Detected` raises a `warning` alert and `Spoilage Risk` raises a
`danger` alert (see [firebase-schema.md](firebase-schema.md)).

---

## 3. Sensor contribution to spoilage risk

The banana percentage is the **visual** signal. The DHT11 (temperature) and
MQ135 (gas) readings are a secondary, environmental signal: a warm fridge or
rising spoilage gas means food degrades faster. The current implementation
keeps the visual analysis and the sensor alerts separate and honest — it does
**not** invent a single fused "AI score". Combining them into one weighted
risk index is listed as future work.

---

## 4. Honest limitations

- Colour thresholding is sensitive to lighting; the enclosed, evenly-lit box
  mitigates this but does not eliminate it.
- A very dark background can be misread as banana spots — keep the banana on a
  light, plain surface.
- The method estimates **surface** browning only; internal spoilage is not
  visible to the camera.
- It is deliberately simple so it runs in real time on a normal laptop and
  stays easy to explain in a university report.
