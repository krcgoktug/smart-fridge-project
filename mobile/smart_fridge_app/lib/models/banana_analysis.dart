/// Result of a real pixel-based banana browning analysis. No ML.
class BananaAnalysis {
  BananaAnalysis({
    required this.detected,
    required this.spotPercent,
    required this.status,
    required this.updatedAt,
  });

  /// True when a banana-yellow region was found in the frame.
  final bool detected;

  /// Percentage of brown + dark pixels inside the banana region (0..100).
  final double spotPercent;

  /// Status word: "Fresh" / "Spotting" / "Spoiling" / "Spoiled" / "No banana".
  final String status;

  final DateTime updatedAt;

  factory BananaAnalysis.empty() => BananaAnalysis(
        detected: false,
        spotPercent: 0,
        status: 'No banana',
        updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
      );

  /// Map a spot percentage to a status word (4 bands).
  static String statusFor(double pct) {
    if (pct < 20) return 'Fresh';
    if (pct < 50) return 'Spotting';
    if (pct < 80) return 'Spoiling';
    return 'Spoiled';
  }

  bool get hasData => updatedAt.millisecondsSinceEpoch > 0;
}
