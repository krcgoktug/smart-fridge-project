import 'dart:async';

import '../models/alert.dart';
import '../models/camera_info.dart';
import '../models/product.dart';
import '../models/sensor_data.dart';

/// In-memory data source used when Firebase is not configured.
///
/// It lets the whole app be explored — populated with realistic sample data —
/// without any Firebase project. Scanning/adding/deleting products and alerts
/// all work and update the UI live; the data simply is not persisted.
class DemoRepository {
  DemoRepository._() {
    _seed();
  }

  static final DemoRepository instance = DemoRepository._();

  // --- Backing state ---
  late SensorData _sensors;
  late CameraInfo _camera;
  final List<Product> _products = <Product>[];
  final List<Alert> _alerts = <Alert>[];

  // --- Broadcast controllers ---
  final StreamController<SensorData> _sensorCtrl =
      StreamController<SensorData>.broadcast();
  final StreamController<CameraInfo> _cameraCtrl =
      StreamController<CameraInfo>.broadcast();
  final StreamController<List<Product>> _productsCtrl =
      StreamController<List<Product>>.broadcast();
  final StreamController<List<Alert>> _alertsCtrl =
      StreamController<List<Alert>>.broadcast();

  void _seed() {
    final int now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    _sensors = SensorData(
      temperature: 5.8,
      humidity: 72,
      gasValue: 1350,
      weight: 1284,
      riskScore: 24,
      status: 'Fresh',
      updatedAt: now,
    );

    _camera = CameraInfo(
      streamUrl: 'http://172.19.15.112',
      captureUrl: 'http://172.19.15.112/capture',
    );

    String dateIn(int days) =>
        DateTime.now().add(Duration(days: days)).toIso8601String().split('T').first;
    String dateAgo(int days) =>
        DateTime.now().subtract(Duration(days: days)).toIso8601String().split('T').first;

    _products.addAll(<Product>[
      Product(
        productId: 'banana_001',
        name: 'Banana',
        category: 'Fruit',
        brand: 'Generic',
        expiryDate: dateIn(2),
        addedDate: dateAgo(3),
        expectedWeight: 150,
        weightMin: 100,
        weightMax: 180,
        storageType: 'Cool',
        currentWeight: 142,
        browningRatio: 0.32,
        visualStatus: 'Browning Detected',
      ),
      Product(
        productId: 'milk_001',
        name: 'Milk',
        category: 'Dairy',
        brand: 'Example Brand',
        expiryDate: dateIn(8),
        addedDate: dateAgo(1),
        expectedWeight: 1000,
        weightMin: 900,
        weightMax: 1100,
        storageType: 'Cold',
        currentWeight: 940,
      ),
      Product(
        productId: 'tomato_001',
        name: 'Tomato',
        category: 'Vegetable',
        brand: 'Generic',
        expiryDate: dateIn(1),
        addedDate: dateAgo(4),
        expectedWeight: 120,
        weightMin: 90,
        weightMax: 160,
        storageType: 'Cool',
        currentWeight: 118,
      ),
      Product(
        productId: 'egg_001',
        name: 'Egg Box',
        category: 'Egg',
        brand: 'Generic',
        expiryDate: dateIn(15),
        addedDate: dateAgo(1),
        expectedWeight: 600,
        weightMin: 480,
        weightMax: 660,
        storageType: 'Cold',
        currentWeight: 540,
      ),
    ]);

    _alerts.addAll(<Alert>[
      Alert(
        id: 'alert_001',
        message: 'Banana expiry date is approaching.',
        severity: 'warning',
        productId: 'banana_001',
        createdAt: now - 3600,
      ),
      Alert(
        id: 'alert_002',
        message: 'Banana browning detected by the camera.',
        severity: 'warning',
        productId: 'banana_001',
        createdAt: now - 1800,
      ),
      Alert(
        id: 'alert_003',
        message: 'Tomato should be consumed within a day.',
        severity: 'danger',
        productId: 'tomato_001',
        createdAt: now - 600,
      ),
    ]);

    // Gently drift the sensor values so the dashboard feels alive.
    // The repository is an app-lifetime singleton, so this timer is never
    // cancelled by design.
    Timer.periodic(const Duration(seconds: 5), (_) {
      final int tick = DateTime.now().second;
      _sensors = SensorData(
        temperature: 5.5 + (tick % 5) * 0.2,
        humidity: 68 + (tick % 8),
        gasValue: 1200 + (tick % 10) * 35,
        weight: _totalWeight(),
        riskScore: _sensors.riskScore,
        status: _sensors.status,
        updatedAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      );
      _sensorCtrl.add(_sensors);
    });
  }

  num _totalWeight() {
    num sum = 0;
    for (final Product p in _products) {
      sum += p.currentWeight ?? p.expectedWeight;
    }
    return sum;
  }

  // --- Streams: emit current state, then live updates ---

  Stream<SensorData> sensorStream() async* {
    yield _sensors;
    yield* _sensorCtrl.stream;
  }

  Stream<CameraInfo> cameraStream() async* {
    yield _camera;
    yield* _cameraCtrl.stream;
  }

  Stream<List<Product>> productsStream() async* {
    yield List<Product>.unmodifiable(_products);
    yield* _productsCtrl.stream;
  }

  Stream<List<Alert>> alertsStream() async* {
    yield _sortedAlerts();
    yield* _alertsCtrl.stream;
  }

  List<Alert> _sortedAlerts() {
    final List<Alert> list = List<Alert>.of(_alerts);
    list.sort((Alert a, Alert b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  // --- Writes ---

  void saveProduct(Product product) {
    _products.removeWhere((Product p) => p.productId == product.productId);
    product.remainingHours ??= product.hoursUntilExpiry();
    _products.add(product);
    _productsCtrl.add(List<Product>.unmodifiable(_products));
  }

  void deleteProduct(String productId) {
    _products.removeWhere((Product p) => p.productId == productId);
    _productsCtrl.add(List<Product>.unmodifiable(_products));
  }

  void addAlert(String message, String severity, {String? productId}) {
    _alerts.add(Alert(
      id: 'alert_${DateTime.now().millisecondsSinceEpoch}',
      message: message,
      severity: severity,
      productId: productId,
      createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
    ));
    _alertsCtrl.add(_sortedAlerts());
  }

  void deleteAlert(String alertId) {
    _alerts.removeWhere((Alert a) => a.id == alertId);
    _alertsCtrl.add(_sortedAlerts());
  }
}
