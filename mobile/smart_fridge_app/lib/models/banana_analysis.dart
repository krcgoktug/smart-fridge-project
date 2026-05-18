/// Latest banana browning result computed by the backend, read from
/// `devices/<id>/bananaAnalysis`.
class BananaAnalysis {
  BananaAnalysis({
    this.brownPercent = 0,
    this.status = 'Fresh',
    this.analyzedAt = 0,
  });

  final double brownPercent; // 0..100
  final String status; // Fresh / Warning / Rotten
  final num analyzedAt; // Unix seconds

  bool get hasData => analyzedAt > 0;

  bool get needsWarning => status == 'Warning' || status == 'Rotten';

  String get warningMessage => status == 'Rotten'
      ? 'Banana is rotten. Do not consume.'
      : 'Banana browning detected. Consume soon.';

  factory BananaAnalysis.fromMap(Map<dynamic, dynamic>? map) {
    if (map == null) return BananaAnalysis();
    double d(dynamic v) {
      if (v == null) return 0;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString()) ?? 0;
    }

    return BananaAnalysis(
      brownPercent: d(map['brownPercent']),
      status: (map['status'] ?? 'Fresh').toString(),
      analyzedAt: map['analyzedAt'] is num ? map['analyzedAt'] as num : 0,
    );
  }
}
