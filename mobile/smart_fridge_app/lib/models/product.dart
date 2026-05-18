/// A product registered from a QR code, stored under
/// `devices/fridge_01/products/<productId>`.
///
/// QR sticker payload:
/// `{ "productId", "name", "category", "expiryDate", "addedDate" }`
class Product {
  Product({
    required this.productId,
    required this.name,
    required this.category,
    required this.expiryDate,
    required this.addedDate,
    this.createdAt = 0,
  });

  final String productId;
  final String name;
  final String category;
  final String expiryDate; // YYYY-MM-DD
  final String addedDate; // YYYY-MM-DD
  final num createdAt; // Unix seconds the app registered it

  /// Whole days left until the expiry date (negative when expired).
  int daysUntilExpiry() {
    final DateTime? expiry = DateTime.tryParse(expiryDate);
    if (expiry == null) return 0;
    final DateTime today =
        DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final DateTime exp = DateTime(expiry.year, expiry.month, expiry.day);
    return exp.difference(today).inDays;
  }

  /// Expiry-based status: Fresh / Expiring Soon / Expired.
  String expiryStatus() {
    final int days = daysUntilExpiry();
    if (days < 0) return 'Expired';
    if (days <= 3) return 'Expiring Soon';
    return 'Fresh';
  }

  bool get needsWarning => expiryStatus() != 'Fresh';

  /// Human-friendly remaining-time label.
  String remainingLabel() {
    if (expiryDate.isEmpty) return 'No expiry date';
    final int days = daysUntilExpiry();
    if (days < 0) return 'Expired ${-days} day(s) ago';
    if (days == 0) return 'Expires today';
    if (days == 1) return '1 day left';
    return '$days days left';
  }

  factory Product.fromMap(String key, Map<dynamic, dynamic> map) {
    num n(dynamic v) {
      if (v == null) return 0;
      if (v is num) return v;
      return num.tryParse(v.toString()) ?? 0;
    }

    return Product(
      productId: (map['productId'] ?? key).toString(),
      name: (map['name'] ?? 'Unknown').toString(),
      category: (map['category'] ?? 'Other').toString(),
      expiryDate: (map['expiryDate'] ?? '').toString(),
      addedDate: (map['addedDate'] ?? '').toString(),
      createdAt: n(map['createdAt']),
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'productId': productId,
        'name': name,
        'category': category,
        'expiryDate': expiryDate,
        'addedDate': addedDate,
        'createdAt': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      };
}
