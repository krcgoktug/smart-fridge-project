import 'package:flutter_test/flutter_test.dart';
import 'package:smart_fridge_app/models/alert.dart';
import 'package:smart_fridge_app/models/camera_config.dart';
import 'package:smart_fridge_app/models/product.dart';
import 'package:smart_fridge_app/models/sensor_data.dart';
import 'package:smart_fridge_app/services/alert_service.dart';

int _now() => DateTime.now().millisecondsSinceEpoch ~/ 1000;

String _date(int daysFromNow) => DateTime.now()
    .add(Duration(days: daysFromNow))
    .toIso8601String()
    .split('T')
    .first;

Product _product(String name, int expiresInDays) => Product(
      productId: name.toLowerCase(),
      name: name,
      category: 'Dairy',
      expiryDate: _date(expiresInDays),
      addedDate: _date(0),
    );

void main() {
  group('Product expiry status', () {
    test('classifies Fresh / Expiring Soon / Expired', () {
      expect(_product('A', 10).expiryStatus(), 'Fresh');
      expect(_product('B', 2).expiryStatus(), 'Expiring Soon');
      expect(_product('C', 0).expiryStatus(), 'Expiring Soon');
      expect(_product('D', -3).expiryStatus(), 'Expired');
    });

    test('parses a Firebase map', () {
      final Product p = Product.fromMap('milk_001', <String, dynamic>{
        'productId': 'milk_001',
        'name': 'Milk',
        'category': 'Dairy',
        'expiryDate': '2026-05-25',
        'addedDate': '2026-05-18',
      });
      expect(p.name, 'Milk');
      expect(p.category, 'Dairy');
    });
  });

  group('SensorData', () {
    test('online only when the update is recent', () {
      expect(SensorData(updatedAt: _now()).isOnline, isTrue);
      expect(SensorData(updatedAt: _now() - 30).isOnline, isTrue);
      expect(SensorData(updatedAt: _now() - 120).isOnline, isFalse);
      expect(SensorData().isOnline, isFalse);
    });
  });

  group('CameraConfig', () {
    test('builds stream and capture URLs from a bare IP', () {
      final CameraConfig c = CameraConfig(localIp: '172.19.15.112');
      expect(c.streamUrl, 'http://172.19.15.112/stream');
      expect(c.captureUrl, 'http://172.19.15.112/capture');
      expect(c.isConfigured, isTrue);
    });

    test('accepts an IP that already has http://', () {
      final CameraConfig c = CameraConfig(localIp: 'http://192.168.1.44/');
      expect(c.streamUrl, 'http://192.168.1.44/stream');
    });

    test('empty when not configured', () {
      expect(CameraConfig().isConfigured, isFalse);
      expect(CameraConfig().streamUrl, '');
    });
  });

  group('AlertService', () {
    test('flags offline ESP32, offline camera and expiring products', () {
      final List<Alert> alerts = AlertService.derive(
        sensors: SensorData(), // offline
        products: <Product>[
          _product('Milk', -1), // expired
          _product('Eggs', 30), // fresh
        ],
        cameraConfigured: true,
        cameraOnline: false,
      );
      expect(alerts.any((Alert a) => a.type == 'esp32'), isTrue);
      expect(alerts.any((Alert a) => a.type == 'camera'), isTrue);
      expect(alerts.any((Alert a) => a.message.contains('Milk')), isTrue);
      expect(alerts.any((Alert a) => a.message.contains('Eggs')), isFalse);
    });

    test('no alerts when everything is healthy', () {
      final List<Alert> alerts = AlertService.derive(
        sensors: SensorData(updatedAt: _now()),
        products: <Product>[_product('Cheese', 20)],
        cameraConfigured: true,
        cameraOnline: true,
      );
      expect(alerts, isEmpty);
    });
  });
}
