import 'package:firebase_database/firebase_database.dart';

import '../app_config.dart';
import '../models/banana_analysis.dart';
import '../models/product.dart';
import '../models/sensor_data.dart';

/// Read-only data access layer.
///
/// The Flutter app is a pure visualization layer: it only **reads** from
/// Firebase Realtime Database. The ESP32 boards and the Python backend are
/// the only writers.
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

  static Map<dynamic, dynamic>? _asMap(Object? value) {
    if (value is Map) return value;
    return null;
  }
}
