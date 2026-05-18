import 'package:flutter_test/flutter_test.dart';
import 'package:smart_fridge_app/models/alert.dart';
import 'package:smart_fridge_app/models/banana_analysis.dart';
import 'package:smart_fridge_app/models/product.dart';
import 'package:smart_fridge_app/models/sensor_data.dart';
import 'package:smart_fridge_app/services/alert_service.dart';

String _date(Duration offset) =>
    DateTime.now().add(offset).toIso8601String().split('T').first;

int _now() => DateTime.now().millisecondsSinceEpoch ~/ 1000;

Product _product(String name, String expiry) =>
    Product(key: name, productName: name, expiryDate: expiry);

void main() {
  group('Product expiry status', () {
    test('classifies Fresh / Expiring Soon / Expired', () {
      expect(_product('A', _date(const Duration(days: 10))).expiryStatus(),
          'Fresh');
      expect(_product('B', _date(const Duration(hours: 24))).expiryStatus(),
          'Expiring Soon');
      expect(_product('C', _date(const Duration(days: -2))).expiryStatus(),
          'Expired');
    });

    test('warning flag follows the status', () {
      expect(_product('A', _date(const Duration(days: 10))).needsWarning,
          isFalse);
      expect(_product('C', _date(const Duration(days: -1))).needsWarning,
          isTrue);
    });
  });

  group('SensorData online detection', () {
    test('fresh + alive is online; stale or not-alive is offline', () {
      expect(
          SensorData(updatedAt: _now(), alive: true).isOnline, isTrue);
      expect(SensorData(updatedAt: _now() - 30, alive: true).isOnline,
          isTrue);
      expect(SensorData(updatedAt: _now() - 120, alive: true).isOnline,
          isFalse);
      expect(SensorData(updatedAt: _now(), alive: false).isOnline, isFalse);
      expect(SensorData().isOnline, isFalse);
    });
  });

  group('BananaAnalysis', () {
    test('parses a map and flags warnings', () {
      final BananaAnalysis fresh = BananaAnalysis.fromMap(<String, dynamic>{
        'brownPercent': 8.0,
        'status': 'Fresh',
        'analyzedAt': _now(),
      });
      expect(fresh.brownPercent, 8.0);
      expect(fresh.needsWarning, isFalse);

      final BananaAnalysis rotten = BananaAnalysis.fromMap(<String, dynamic>{
        'brownPercent': 60.0,
        'status': 'Rotten',
        'analyzedAt': _now(),
      });
      expect(rotten.needsWarning, isTrue);
      expect(rotten.warningMessage.toLowerCase(), contains('rotten'));
    });
  });

  group('AlertService', () {
    test('derives alerts for offline ESP32 and expiring products', () {
      final List<Alert> alerts = AlertService.derive(
        sensors: SensorData(), // offline
        products: <Product>[
          _product('Milk', _date(const Duration(days: -1))), // expired
          _product('Eggs', _date(const Duration(days: 30))), // fresh
        ],
        banana: BananaAnalysis(),
      );
      expect(alerts.any((Alert a) => a.message.contains('offline')), isTrue);
      expect(alerts.any((Alert a) => a.message.contains('Milk')), isTrue);
      expect(alerts.any((Alert a) => a.message.contains('Eggs')), isFalse);
    });

    test('no alerts when everything is healthy', () {
      final List<Alert> alerts = AlertService.derive(
        sensors: SensorData(updatedAt: _now(), alive: true),
        products: <Product>[
          _product('Cheese', _date(const Duration(days: 20))),
        ],
        banana: BananaAnalysis(
          brownPercent: 5,
          status: 'Fresh',
          analyzedAt: _now(),
        ),
      );
      expect(alerts, isEmpty);
    });
  });
}
