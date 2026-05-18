import 'package:flutter_test/flutter_test.dart';
import 'package:smart_fridge_app/models/alert.dart';
import 'package:smart_fridge_app/models/banana_analysis.dart';
import 'package:smart_fridge_app/models/camera_status.dart';
import 'package:smart_fridge_app/models/product.dart';
import 'package:smart_fridge_app/models/sensor_data.dart';

String _date(Duration offset) =>
    DateTime.now().add(offset).toIso8601String().split('T').first;

int _now() => DateTime.now().millisecondsSinceEpoch ~/ 1000;

Product _product(String name, String expiry) =>
    Product(key: name, productName: name, expiryDate: expiry);

void main() {
  group('Product', () {
    test('classifies Fresh / Expiring Soon / Expired', () {
      expect(_product('A', _date(const Duration(days: 10))).expiryStatus(),
          'Fresh');
      expect(_product('B', _date(const Duration(hours: 24))).expiryStatus(),
          'Expiring Soon');
      expect(_product('C', _date(const Duration(days: -2))).expiryStatus(),
          'Expired');
    });

    test('parses the QR-schema fields', () {
      final Product p = Product.fromMap('banana_001', <String, dynamic>{
        'productId': 'banana_001',
        'productName': 'Banana',
        'category': 'Fruit',
        'expiryDate': '2026-05-25',
        'detectedAt': 1710000000,
      });
      expect(p.productId, 'banana_001');
      expect(p.category, 'Fruit');
      expect(p.productName, 'Banana');
    });
  });

  group('SensorData online detection', () {
    test('fresh + alive is online; stale or not-alive is offline', () {
      expect(SensorData(updatedAt: _now(), alive: true).isOnline, isTrue);
      expect(SensorData(updatedAt: _now() - 30, alive: true).isOnline,
          isTrue);
      expect(SensorData(updatedAt: _now() - 120, alive: true).isOnline,
          isFalse);
      expect(SensorData(updatedAt: _now(), alive: false).isOnline, isFalse);
      expect(SensorData().isOnline, isFalse);
    });
  });

  group('BananaAnalysis', () {
    test('parses the four-tier schema and flags warnings', () {
      final BananaAnalysis fresh = BananaAnalysis.fromMap(<String, dynamic>{
        'brownPercent': 8,
        'visualStatus': 'Fresh',
        'status': 'Good',
        'analyzedAt': _now(),
      });
      expect(fresh.brownPercent, 8.0);
      expect(fresh.needsWarning, isFalse);

      final BananaAnalysis spoiled =
          BananaAnalysis.fromMap(<String, dynamic>{
        'brownPercent': 72,
        'visualStatus': 'Spoilage Risk',
        'status': 'Do Not Consume',
        'analyzedAt': _now(),
      });
      expect(spoiled.needsWarning, isTrue);
      expect(spoiled.message.toLowerCase(), contains('do not consume'));
    });
  });

  group('CameraStatus', () {
    test('parses the camera node', () {
      final CameraStatus c = CameraStatus.fromMap(<String, dynamic>{
        'online': true,
        'ip': 'http://192.168.1.50',
        'lastFrameAt': _now(),
        'frameWidth': 640,
        'frameHeight': 480,
      });
      expect(c.online, isTrue);
      expect(c.resolutionLabel, '640 x 480');
    });
  });

  group('Alert', () {
    test('parses a Firebase alert and ranks severity', () {
      final Alert danger = Alert.fromMap(<String, dynamic>{
        'type': 'banana',
        'message': 'Banana shows spoilage risk.',
        'severity': 'danger',
        'createdAt': _now(),
      });
      final Alert warning = Alert.fromMap(<String, dynamic>{
        'type': 'expiry',
        'message': 'Milk expires soon.',
        'severity': 'warning',
        'createdAt': _now(),
      });
      expect(danger.message, contains('spoilage'));
      expect(danger.severityRank, lessThan(warning.severityRank));
    });
  });
}
