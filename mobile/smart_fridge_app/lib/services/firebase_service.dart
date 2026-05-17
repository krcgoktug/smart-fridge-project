import 'package:firebase_database/firebase_database.dart';

import '../app_config.dart';
import '../models/alert.dart';
import '../models/product.dart';
import '../models/sensor_data.dart';

/// Camera endpoint URLs published under `/devices/<id>/camera`.
class CameraInfo {
  CameraInfo({this.streamUrl, this.captureUrl});
  final String? streamUrl;
  final String? captureUrl;

  bool get hasUrls => (captureUrl != null && captureUrl!.isNotEmpty);

  factory CameraInfo.fromMap(Map<dynamic, dynamic>? map) {
    if (map == null) return CameraInfo();
    return CameraInfo(
      streamUrl: map['streamUrl']?.toString(),
      captureUrl: map['captureUrl']?.toString(),
    );
  }
}

/// Thin wrapper over Firebase Realtime Database for this device.
///
/// [ready] is set by `main.dart` after a successful `Firebase.initializeApp`.
/// When it is false (placeholder config / offline), the screens show a
/// "Firebase not configured" hint instead of crashing.
class FirebaseService {
  /// True once Firebase initialised successfully.
  static bool ready = false;

  static DatabaseReference get _root =>
      FirebaseDatabase.instance.ref(AppConfig.deviceRoot);

  // --- Streams ---------------------------------------------------------------

  /// Live environmental sensor data.
  static Stream<SensorData> sensorStream() {
    return _root.child('sensors').onValue.map(
          (DatabaseEvent e) =>
              SensorData.fromMap(_asMap(e.snapshot.value)),
        );
  }

  /// Live camera endpoint info.
  static Stream<CameraInfo> cameraStream() {
    return _root.child('camera').onValue.map(
          (DatabaseEvent e) =>
              CameraInfo.fromMap(_asMap(e.snapshot.value)),
        );
  }

  /// Live list of products.
  static Stream<List<Product>> productsStream() {
    return _root.child('products').onValue.map((DatabaseEvent e) {
      final Map<dynamic, dynamic>? map = _asMap(e.snapshot.value);
      if (map == null) return <Product>[];
      final List<Product> list = <Product>[];
      map.forEach((dynamic key, dynamic value) {
        final Map<dynamic, dynamic>? pm = _asMap(value);
        if (pm != null) list.add(Product.fromMap(key.toString(), pm));
      });
      return list;
    });
  }

  /// Live list of alerts, newest first.
  static Stream<List<Alert>> alertsStream() {
    return _root.child('alerts').onValue.map((DatabaseEvent e) {
      final Map<dynamic, dynamic>? map = _asMap(e.snapshot.value);
      if (map == null) return <Alert>[];
      final List<Alert> list = <Alert>[];
      map.forEach((dynamic key, dynamic value) {
        final Map<dynamic, dynamic>? am = _asMap(value);
        if (am != null) list.add(Alert.fromMap(key.toString(), am));
      });
      list.sort((Alert a, Alert b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  // --- Writes ----------------------------------------------------------------

  /// Create or overwrite a product (used after a QR scan).
  static Future<void> saveProduct(Product product) async {
    product.remainingHours ??= product.hoursUntilExpiry();
    await _root.child('products/${product.productId}').set(product.toMap());
  }

  /// Update only the dynamic fields of a product after a risk recompute.
  static Future<void> updateProductRisk(Product product) async {
    await _root.child('products/${product.productId}').update(<String, dynamic>{
      'riskScore': product.riskScore,
      'status': product.status,
      'remainingHours': product.remainingHours,
      'currentWeight': product.currentWeight,
      'browningRatio': product.browningRatio,
      'visualStatus': product.visualStatus,
      'updatedAt': DateTime.now().millisecondsSinceEpoch ~/ 1000,
    });
  }

  static Future<void> deleteProduct(String productId) async {
    await _root.child('products/$productId').remove();
  }

  /// Push a new alert.
  static Future<void> addAlert(String message, String severity,
      {String? productId}) async {
    final DatabaseReference ref = _root.child('alerts').push();
    await ref.set(<String, dynamic>{
      'message': message,
      'severity': severity,
      'productId': productId,
      'createdAt': DateTime.now().millisecondsSinceEpoch ~/ 1000,
    });
  }

  static Future<void> deleteAlert(String alertId) async {
    await _root.child('alerts/$alertId').remove();
  }

  // --- Helpers ---------------------------------------------------------------

  static Map<dynamic, dynamic>? _asMap(Object? value) {
    if (value is Map) return value;
    return null;
  }
}
