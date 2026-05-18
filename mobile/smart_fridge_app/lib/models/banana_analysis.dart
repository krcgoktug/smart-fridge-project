/// Result of a pixel-based banana browning analysis, stored under
/// `/devices/<id>/bananaAnalysis/<productId>`.
class BananaAnalysis {
  BananaAnalysis({
    required this.productId,
    required this.brownSpotPercentage,
    required this.darkSpotPercentage,
    required this.totalBrowningPercentage,
    required this.visualStatus,
    this.updatedAt = 0,
  });

  final String productId;
  final double brownSpotPercentage;
  final double darkSpotPercentage;
  final double totalBrowningPercentage;
  final String visualStatus;
  final num updatedAt;

  /// Map a total browning percentage (0-100) to a visual status.
  static String statusForPercentage(double total) {
    if (total >= 50) return 'Consume Soon';
    if (total >= 25) return 'Browning Detected';
    if (total >= 10) return 'Slight Browning';
    return 'Fresh';
  }

  /// True when the banana should be flagged to the user.
  bool get needsWarning => totalBrowningPercentage >= 10;

  String get warningMessage =>
      'Banana browning detected. Consume soon.';

  factory BananaAnalysis.empty(String productId) => BananaAnalysis(
        productId: productId,
        brownSpotPercentage: 0,
        darkSpotPercentage: 0,
        totalBrowningPercentage: 0,
        visualStatus: 'Fresh',
      );

  factory BananaAnalysis.fromMap(String id, Map<dynamic, dynamic> map) {
    double d(dynamic v) {
      if (v == null) return 0;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString()) ?? 0;
    }

    return BananaAnalysis(
      productId: (map['productId'] ?? id).toString(),
      brownSpotPercentage: d(map['brownSpotPercentage']),
      darkSpotPercentage: d(map['darkSpotPercentage']),
      totalBrowningPercentage: d(map['totalBrowningPercentage']),
      visualStatus: (map['visualStatus'] ?? 'Fresh').toString(),
      updatedAt: map['updatedAt'] is num ? map['updatedAt'] as num : 0,
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'productId': productId,
        'brownSpotPercentage':
            double.parse(brownSpotPercentage.toStringAsFixed(1)),
        'darkSpotPercentage':
            double.parse(darkSpotPercentage.toStringAsFixed(1)),
        'totalBrowningPercentage':
            double.parse(totalBrowningPercentage.toStringAsFixed(1)),
        'visualStatus': visualStatus,
        'updatedAt': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      };
}
