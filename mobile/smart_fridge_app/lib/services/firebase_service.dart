import 'package:firebase_database/firebase_database.dart';

import '../app_config.dart';
import '../models/camera_config.dart';
import '../models/product.dart';
import '../models/sensor_data.dart';
import 'local_sensor_bridge.dart';
import 'local_store.dart';
import 'settings_service.dart';

/// Data access layer for Firebase Realtime Database.
///
/// The app READS sensors, products and the camera config, and WRITES products
/// (after a QR scan) and the camera config (when the IP is set).
///
/// When [ready] is false (Firebase not configured) the read streams emit
/// empty data so the UI shows honest "offline / no data" states.
class FirebaseService {
  /// True once Firebase is initialised against a real project.
  static bool ready = false;

  static DatabaseReference get _root =>
      FirebaseDatabase.instance.ref(AppConfig.deviceRoot);

  // --- Reads -----------------------------------------------------------------

  static Stream<SensorData> sensorStream() {
    // When Firebase isn't configured we fall back to polling the small
    // Python bridge that reads the Arduino Uno over USB. That way the app
    // shows live DHT11 / MQ135 / HX711 data with zero cloud setup.
    if (!ready) {
      return LocalSensorBridge.stream(SettingsService.sensorBridgeUrl);
    }
    return _root.child('sensors').onValue.map(
          (DatabaseEvent e) => SensorData.fromMap(_asMap(e.snapshot.value)),
        );
  }

  static Stream<CameraConfig> cameraStream() {
    if (!ready) return Stream<CameraConfig>.value(CameraConfig());
    return _root.child('camera').onValue.map(
          (DatabaseEvent e) => CameraConfig.fromMap(_asMap(e.snapshot.value)),
        );
  }

  static Stream<List<Product>> productsStream() {
    // Without Firebase, fall back to the local in-memory store so the user's
    // scanned products still appear in the Products tab.
    if (!ready) return LocalStore.instance.productsStream();
    return _root.child('products').onValue.map((DatabaseEvent e) {
      final Map<dynamic, dynamic>? map = _asMap(e.snapshot.value);
      if (map == null) return <Product>[];
      final List<Product> list = <Product>[];
      map.forEach((dynamic key, dynamic value) {
        final Map<dynamic, dynamic>? pm = _asMap(value);
        if (pm != null) list.add(Product.fromMap(key.toString(), pm));
      });
      list.sort((Product a, Product b) =>
          a.daysUntilExpiry().compareTo(b.daysUntilExpiry()));
      return list;
    });
  }

  // --- Writes ----------------------------------------------------------------

  /// Register/update a product (after a QR scan from the camera).
  static Future<void> saveProduct(Product product) async {
    if (!ready) {
      LocalStore.instance.saveProduct(product);
      return;
    }
    await _root.child('products/${product.productId}').set(product.toMap());
  }

  /// Remove a product (e.g. it left the fridge).
  static Future<void> deleteProduct(String productId) async {
    if (!ready) {
      LocalStore.instance.deleteProduct(productId);
      return;
    }
    await _root.child('products/$productId').remove();
  }

  /// Save the camera configuration so every team member's app shares it.
  static Future<void> saveCameraConfig(CameraConfig config) async {
    if (!ready) return;
    await _root.child('camera').set(config.toMap());
  }

  // --- Helpers ---------------------------------------------------------------

  static Map<dynamic, dynamic>? _asMap(Object? value) {
    if (value is Map) return value;
    return null;
  }
}
