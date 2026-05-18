/// A single product stored in the fridge.
///
/// The identity fields come from the scanned QR code. The dynamic fields
/// (currentWeight, browningRatio, visualStatus, remainingHours, riskScore,
/// status) are computed/updated over time.
class Product {
  Product({
    required this.productId,
    required this.name,
    required this.category,
    required this.brand,
    required this.expiryDate,
    required this.addedDate,
    required this.expectedWeight,
    required this.weightMin,
    required this.weightMax,
    this.storageType = 'Cold',
    this.currentWeight,
    this.browningRatio,
    this.visualStatus,
    this.remainingHours,
    this.riskScore = 0,
    this.status = 'Fresh',
  });

  // --- QR / identity fields ---
  final String productId;
  final String name;
  final String category;
  final String brand;
  final String expiryDate; // YYYY-MM-DD
  final String addedDate; // YYYY-MM-DD
  final num expectedWeight;
  final num weightMin;
  final num weightMax;
  final String storageType;

  // --- dynamic fields ---
  num? currentWeight;
  double? browningRatio;
  String? visualStatus;
  num? remainingHours;
  num riskScore;
  String status;

  /// Hours left until the expiry date, computed from [expiryDate].
  /// Negative when the product is already expired.
  int hoursUntilExpiry() {
    final DateTime? expiry = DateTime.tryParse(expiryDate);
    if (expiry == null) return 0;
    return expiry.difference(DateTime.now()).inHours;
  }

  /// Human-friendly remaining time string.
  String remainingTimeLabel() {
    final int hours = remainingHours?.toInt() ?? hoursUntilExpiry();
    if (hours <= 0) return 'Expired';
    if (hours < 24) return '$hours h left';
    final int days = hours ~/ 24;
    final int rem = hours % 24;
    return rem == 0 ? '$days d left' : '$days d $rem h left';
  }

  bool get isFruitOrVegetable =>
      category == 'Fruit' || category == 'Vegetable';

  bool get isBanana => name.toLowerCase().contains('banana');

  /// Expiry-based status derived purely from the expiry date:
  ///   Expired       -> past the expiry date
  ///   Expiring Soon -> 3 days (72 h) or less remaining
  ///   Fresh         -> more than 3 days remaining
  String expiryStatus() {
    final int hours = remainingHours?.toInt() ?? hoursUntilExpiry();
    if (hours <= 0) return 'Expired';
    if (hours <= 72) return 'Expiring Soon';
    return 'Fresh';
  }

  /// True when the product needs an expiry warning.
  bool get expiryNeedsWarning => expiryStatus() != 'Fresh';

  /// Build a product from a scanned QR JSON map.
  factory Product.fromQrJson(Map<String, dynamic> json) {
    return Product(
      productId: (json['productId'] ?? '').toString(),
      name: (json['name'] ?? 'Unknown').toString(),
      category: (json['category'] ?? 'Packaged Food').toString(),
      brand: (json['brand'] ?? 'Generic').toString(),
      expiryDate: (json['expiryDate'] ?? '').toString(),
      addedDate: (json['addedDate'] ?? '').toString(),
      expectedWeight: _toNum(json['expectedWeight']),
      weightMin: _toNum(json['weightMin']),
      weightMax: _toNum(json['weightMax']),
      storageType: (json['storageType'] ?? 'Cold').toString(),
    );
  }

  /// Build a product from a Firebase Realtime Database node.
  factory Product.fromMap(String key, Map<dynamic, dynamic> map) {
    return Product(
      productId: (map['productId'] ?? key).toString(),
      name: (map['name'] ?? 'Unknown').toString(),
      category: (map['category'] ?? 'Packaged Food').toString(),
      brand: (map['brand'] ?? 'Generic').toString(),
      expiryDate: (map['expiryDate'] ?? '').toString(),
      addedDate: (map['addedDate'] ?? '').toString(),
      expectedWeight: _toNum(map['expectedWeight']),
      weightMin: _toNum(map['weightMin']),
      weightMax: _toNum(map['weightMax']),
      storageType: (map['storageType'] ?? 'Cold').toString(),
      currentWeight:
          map['currentWeight'] == null ? null : _toNum(map['currentWeight']),
      browningRatio: map['browningRatio'] == null
          ? null
          : _toNum(map['browningRatio']).toDouble(),
      visualStatus: map['visualStatus']?.toString(),
      remainingHours:
          map['remainingHours'] == null ? null : _toNum(map['remainingHours']),
      riskScore: _toNum(map['riskScore']),
      status: (map['status'] ?? 'Fresh').toString(),
    );
  }

  /// Serialise for writing to Firebase.
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'productId': productId,
      'name': name,
      'category': category,
      'brand': brand,
      'expiryDate': expiryDate,
      'addedDate': addedDate,
      'expectedWeight': expectedWeight,
      'weightMin': weightMin,
      'weightMax': weightMax,
      'storageType': storageType,
      'currentWeight': currentWeight,
      'browningRatio': browningRatio,
      'visualStatus': visualStatus,
      'remainingHours': remainingHours,
      'riskScore': riskScore,
      'status': status,
      'updatedAt': DateTime.now().millisecondsSinceEpoch ~/ 1000,
    };
  }

  static num _toNum(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v;
    return num.tryParse(v.toString()) ?? 0;
  }
}
