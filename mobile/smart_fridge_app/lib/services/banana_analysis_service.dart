import 'dart:typed_data';

import 'package:image/image.dart' as img;

import '../models/banana_analysis.dart';

/// Real, pixel-based banana browning analysis. No machine learning.
///
/// Steps:
///   1. Each pixel is classified by simple RGB rules as banana-yellow,
///      brown spot, dark spot, or background.
///   2. If yellow covers at least 5% of the frame, a banana is "detected".
///   3. spotPercent = (brown + dark) / (yellow + brown + dark) * 100
///   4. Status bands:  < 20 % Fresh, 20-50 % Spotting,
///                     50-80 % Spoiling, > 80 % Spoiled.
class BananaAnalysisService {
  static BananaAnalysis analyzeBytes(Uint8List bytes) {
    final img.Image? decoded = img.decodeImage(bytes);
    if (decoded == null) return BananaAnalysis.empty();

    // Downscale for speed; ratios are resolution-independent.
    final img.Image image = decoded.width > 320
        ? img.copyResize(decoded, width: 320)
        : decoded;

    int yellow = 0;
    int brown = 0;
    int dark = 0;
    final int totalPixels = image.width * image.height;

    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final img.Pixel p = image.getPixel(x, y);
        final int r = p.r.toInt();
        final int g = p.g.toInt();
        final int b = p.b.toInt();
        final double brightness = (r + g + b) / 3.0;

        // Banana-yellow: high R + G, low B, bright.
        if (r > 140 && g > 120 && (r - b) > 35 && brightness > 110) {
          yellow++;
        }
        // Brown overripe spot: warm hue, mid-low brightness.
        else if (brightness >= 50 &&
            brightness < 140 &&
            r >= g &&
            g >= b &&
            (r - b) > 25 &&
            r > 70) {
          brown++;
        }
        // Very dark / black spot.
        else if (brightness < 50) {
          dark++;
        }
      }
    }

    // Need at least 5% yellow to count as "banana visible".
    if (yellow < totalPixels * 0.05) {
      return BananaAnalysis(
        detected: false,
        spotPercent: 0,
        status: 'No banana',
        updatedAt: DateTime.now(),
      );
    }

    final int bananaPixels = yellow + brown + dark;
    final double spotPct =
        bananaPixels == 0 ? 0 : (brown + dark) / bananaPixels * 100.0;

    return BananaAnalysis(
      detected: true,
      spotPercent: spotPct,
      status: BananaAnalysis.statusFor(spotPct),
      updatedAt: DateTime.now(),
    );
  }
}
