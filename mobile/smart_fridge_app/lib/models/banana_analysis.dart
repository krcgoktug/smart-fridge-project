/// Latest banana browning result computed by the image analysis service,
/// read from `devices/<id>/bananaAnalysis`.
class BananaAnalysis {
  BananaAnalysis({
    this.brownPercent = 0,
    this.visualStatus = 'Fresh',
    this.status = 'Good',
    this.analyzedAt = 0,
  });

  final double brownPercent; // 0..100
  /// What the camera sees: Fresh / Slight Browning / Browning Detected /
  /// Spoilage Risk.
  final String visualStatus;
  /// What the user should do: Good / Monitor / Consume Soon / Do Not Consume.
  final String status;
  final num analyzedAt; // Unix seconds

  bool get hasData => analyzedAt > 0;

  bool get needsWarning =>
      visualStatus == 'Browning Detected' || visualStatus == 'Spoilage Risk';

  /// A short message describing the current banana state.
  String get message {
    switch (visualStatus) {
      case 'Spoilage Risk':
        return 'Spoilage risk — do not consume.';
      case 'Browning Detected':
        return 'Browning detected — consume soon.';
      case 'Slight Browning':
        return 'Slight browning — monitor it.';
      default:
        return 'Banana looks fresh.';
    }
  }

  factory BananaAnalysis.fromMap(Map<dynamic, dynamic>? map) {
    if (map == null) return BananaAnalysis();
    double d(dynamic v) {
      if (v == null) return 0;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString()) ?? 0;
    }

    return BananaAnalysis(
      brownPercent: d(map['brownPercent']),
      visualStatus: (map['visualStatus'] ?? 'Fresh').toString(),
      status: (map['status'] ?? 'Good').toString(),
      analyzedAt: map['analyzedAt'] is num ? map['analyzedAt'] as num : 0,
    );
  }
}
