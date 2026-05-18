import 'package:firebase_database/firebase_database.dart';

import '../app_config.dart';
import '../models/alert.dart';
import '../models/banana_analysis.dart';
import '../models/camera_status.dart';
import '../models/product.dart';
import '../models/sensor_data.dart';

/// Read-only data access layer.
///
/// The Flutter app is a pure visualization layer: it only **reads** from
/// Firebase Realtime Database. The ESP32 boards and the image analysis
/// service are the only writers.
///
/// When [ready] is false (Firebase not configured for a real project), the
/// streams emit empty data so the UI shows honest "offline / no data" states
/// instead of crashing.
class FirebaseService {
  /// True once Firebase is initialised against a real project.
  static bool ready = false;

  static DatabaseReference get _root =>
      FirebaseDatabase.instance.ref(AppConfig.deviceRoot);

  /// Live ESP32 sensor heartbeat.
  static Stream<SensorData> sensorStream() {
    if (!ready) return Stream<SensorData>.value(SensorData());
    return _root.child('sensors').onValue.map(
          (DatabaseEvent e) => SensorData.fromMap(_asMap(e.snapshot.value)),
        );
  }

  /// Live ESP32-CAM online status.
  static Stream<CameraStatus> cameraStatusStream() {
    if (!ready) return Stream<CameraStatus>.value(CameraStatus());
    return _root.child('camera').onValue.map(
          (DatabaseEvent e) => CameraStatus.fromMap(_asMap(e.snapshot.value)),
        );
  }

  /// Live list of QR-detected products.
  static Stream<List<Product>> productsStream() {
    if (!ready) return Stream<List<Product>>.value(<Product>[]);
    return _root.child('products').onValue.map((DatabaseEvent e) {
      final Map<dynamic, dynamic>? map = _asMap(e.snapshot.value);
      if (map == null) return <Product>[];
      final List<Product> list = <Product>[];
      map.forEach((dynamic key, dynamic value) {
        final Map<dynamic, dynamic>? pm = _asMap(value);
        if (pm != null) list.add(Product.fromMap(key.toString(), pm));
      });
      list.sort((Product a, Product b) =>
          b.detectedAt.compareTo(a.detectedAt));
      return list;
    });
  }

  /// Live banana browning analysis result.
  static Stream<BananaAnalysis> bananaAnalysisStream() {
    if (!ready) return Stream<BananaAnalysis>.value(BananaAnalysis());
    return _root.child('bananaAnalysis').onValue.map(
          (DatabaseEvent e) =>
              BananaAnalysis.fromMap(_asMap(e.snapshot.value)),
        );
  }

  /// Live list of alerts published by the image analysis service.
  static Stream<List<Alert>> alertsStream() {
    if (!ready) return Stream<List<Alert>>.value(<Alert>[]);
    return _root.child('alerts').onValue.map((DatabaseEvent e) {
      final Map<dynamic, dynamic>? map = _asMap(e.snapshot.value);
      if (map == null) return <Alert>[];
      final List<Alert> list = <Alert>[];
      map.forEach((dynamic key, dynamic value) {
        final Map<dynamic, dynamic>? am = _asMap(value);
        if (am != null) list.add(Alert.fromMap(am));
      });
      list.sort((Alert a, Alert b) {
        final int bySeverity = a.severityRank.compareTo(b.severityRank);
        if (bySeverity != 0) return bySeverity;
        return b.createdAt.compareTo(a.createdAt);
      });
      return list;
    });
  }

  static Map<dynamic, dynamic>? _asMap(Object? value) {
    if (value is Map) return value;
    return null;
  }
}
