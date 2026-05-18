/// A product registered from a QR code by the image analysis service, read
/// from `devices/<id>/products/<key>`.
class Product {
  Product({
    required this.key,
    this.productId = '',
    required this.productName,
    this.category = '',
    required this.expiryDate,
    this.detectedAt = 0,
    this.source = 'qr',
  });

  final String key; // Firebase node key (== productId)
  final String productId;
  final String productName;
  final String category; // Fruit / Vegetable / Dairy / Packaged / ...
  final String expiryDate; // YYYY-MM-DD
  final num detectedAt; // Unix seconds
  final String source; // "qr"

  /// Hours left until the expiry date. Negative when already expired.
  int hoursUntilExpiry() {
    final DateTime? expiry = DateTime.tryParse(expiryDate);
    if (expiry == null) return 0;
    return expiry.difference(DateTime.now()).inHours;
  }

  /// Expiry-based status: Fresh / Expiring Soon / Expired.
  String expiryStatus() {
    if (expiryDate.isEmpty) return 'Fresh';
    final int hours = hoursUntilExpiry();
    if (hours <= 0) return 'Expired';
    if (hours <= 72) return 'Expiring Soon';
    return 'Fresh';
  }

  bool get needsWarning => expiryStatus() != 'Fresh';

  /// Human-friendly remaining-time label.
  String remainingLabel() {
    if (expiryDate.isEmpty) return 'No expiry date';
    final int hours = hoursUntilExpiry();
    if (hours <= 0) return 'Expired';
    if (hours < 24) return '$hours h left';
    final int days = hours ~/ 24;
    return '$days day(s) left';
  }

  factory Product.fromMap(String key, Map<dynamic, dynamic> map) {
    num n(dynamic v) {
      if (v == null) return 0;
      if (v is num) return v;
      return num.tryParse(v.toString()) ?? 0;
    }

    return Product(
      key: key,
      productId: (map['productId'] ?? key).toString(),
      productName: (map['productName'] ?? 'Unknown').toString(),
      category: (map['category'] ?? '').toString(),
      expiryDate: (map['expiryDate'] ?? '').toString(),
      detectedAt: n(map['detectedAt']),
      source: (map['source'] ?? 'qr').toString(),
    );
  }
}
