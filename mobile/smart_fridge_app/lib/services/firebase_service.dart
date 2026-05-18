import 'package:firebase_database/firebase_database.dart';

import '../app_config.dart';
import '../models/alert.dart';
import '../models/camera_info.dart';
import '../models/detection_event.dart';
import '../models/product.dart';
import '../models/sensor_data.dart';
import 'demo_data.dart';

/// Data access layer for the app.
///
/// When [ready] is true it talks to Firebase Realtime Database. When it is
/// false (placeholder config / no Firebase project) it transparently falls
/// back to [DemoRepository], so every screen is fully usable with realistic
/// sample data. Callers do not need to know which mode is active.
class FirebaseService {
  /// True once Firebase initialised against a real project.
  static bool ready = false;

  /// True when the app is running on built-in demo data.
  static bool get demoMode => !ready;

  static DemoRepository get _demo => DemoRepository.instance;

  static DatabaseReference get _root =>
      FirebaseDatabase.instance.ref(AppConfig.deviceRoot);

  // --- Streams ---------------------------------------------------------------

  static Stream<SensorData> sensorStream() {
    if (demoMode) return _demo.sensorStream();
    return _root.child('sensors').onValue.map(
          (DatabaseEvent e) => SensorData.fromMap(_asMap(e.snapshot.value)),
        );
  }

  static Stream<CameraInfo> cameraStream() {
    if (demoMode) return _demo.cameraStream();
    return _root.child('camera').onValue.map(
          (DatabaseEvent e) => CameraInfo.fromMap(_asMap(e.snapshot.value)),
        );
  }

  static Stream<List<Product>> productsStream() {
    if (demoMode) return _demo.productsStream();
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

  /// Live weight-detection events from the ESP32 DevKit.
  static Stream<DetectionEvent> detectionStream() {
    if (demoMode) return _demo.detectionStream();
    return _root.child('detection').onValue.map(
          (DatabaseEvent e) => DetectionEvent.fromMap(_asMap(e.snapshot.value)),
        );
  }

  static Stream<List<Alert>> alertsStream() {
    if (demoMode) return _demo.alertsStream();
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

  static Future<void> saveProduct(Product product) async {
    product.remainingHours ??= product.hoursUntilExpiry();
    if (demoMode) {
      _demo.saveProduct(product);
      return;
    }
    await _root.child('products/${product.productId}').set(product.toMap());
  }

  static Future<void> updateProductRisk(Product product) async {
    if (demoMode) {
      _demo.saveProduct(product);
      return;
    }
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
    if (demoMode) {
      _demo.deleteProduct(productId);
      return;
    }
    await _root.child('products/$productId').remove();
  }

  static Future<void> addAlert(String message, String severity,
      {String? productId}) async {
    if (demoMode) {
      _demo.addAlert(message, severity, productId: productId);
      return;
    }
    final DatabaseReference ref = _root.child('alerts').push();
    await ref.set(<String, dynamic>{
      'message': message,
      'severity': severity,
      'productId': productId,
      'createdAt': DateTime.now().millisecondsSinceEpoch ~/ 1000,
    });
  }

  static Future<void> deleteAlert(String alertId) async {
    if (demoMode) {
      _demo.deleteAlert(alertId);
      return;
    }
    await _root.child('alerts/$alertId').remove();
  }

  /// Demo-only: simulate a product being placed on the load cell. In real
  /// (Firebase-connected) mode this is a no-op — the ESP32 DevKit is the
  /// real trigger.
  static void simulateProductPlaced() {
    if (demoMode) _demo.simulateProductPlaced();
  }

  /// Clear the detection flag after a product has been registered.
  static Future<void> resetDetection() async {
    if (demoMode) {
      _demo.resetDetection();
      return;
    }
    await _root.child('detection').update(<String, dynamic>{
      'newProductDetected': false,
      'eventType': 'none',
    });
  }

  // --- Helpers ---------------------------------------------------------------

  static Map<dynamic, dynamic>? _asMap(Object? value) {
    if (value is Map) return value;
    return null;
  }
}
