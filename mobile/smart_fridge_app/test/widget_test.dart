import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:smart_fridge_app/models/banana_analysis.dart';
import 'package:smart_fridge_app/models/product.dart';
import 'package:smart_fridge_app/models/sensor_data.dart';
import 'package:smart_fridge_app/screens/dashboard_screen.dart' show sensorsOnline;
import 'package:smart_fridge_app/services/banana_analysis_service.dart';
import 'package:smart_fridge_app/services/risk_service.dart';

Product _product(String expiryDate, {String category = 'Fruit'}) => Product(
      productId: 'p1',
      name: 'Test',
      category: category,
      brand: 'b',
      expiryDate: expiryDate,
      addedDate: '2026-01-01',
      expectedWeight: 100,
      weightMin: 80,
      weightMax: 120,
    );

String _date(Duration offset) =>
    DateTime.now().add(offset).toIso8601String().split('T').first;

void main() {
  group('RiskService status bands', () {
    test('maps scores to the correct status', () {
      expect(RiskService.statusFromScore(10), 'Fresh');
      expect(RiskService.statusFromScore(40), 'Consume Soon');
      expect(RiskService.statusFromScore(70), 'Spoilage Risk');
    });
  });

  group('RiskService components', () {
    test('expiryRisk grows as expiry approaches', () {
      expect(RiskService.expiryRisk(200), 0);
      expect(RiskService.expiryRisk(60), 9);
      expect(RiskService.expiryRisk(0), 40);
    });

    test('gasRisk is banded on the MQ135 reading', () {
      expect(RiskService.gasRisk(500), 0);
      expect(RiskService.gasRisk(1600), 16);
      expect(RiskService.gasRisk(3000), 25);
    });
  });

  group('Product expiry status', () {
    test('classifies Fresh / Expiring Soon / Expired', () {
      expect(_product(_date(const Duration(days: 10))).expiryStatus(), 'Fresh');
      expect(_product(_date(const Duration(hours: 24))).expiryStatus(),
          'Expiring Soon');
      expect(_product(_date(const Duration(days: -2))).expiryStatus(),
          'Expired');
    });

    test('warning flag follows the status', () {
      expect(_product(_date(const Duration(days: 10))).expiryNeedsWarning,
          isFalse);
      expect(_product(_date(const Duration(days: -1))).expiryNeedsWarning,
          isTrue);
    });
  });

  group('ESP32 sensor online detection', () {
    test('fresh data is online, stale data is offline', () {
      final int now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      expect(sensorsOnline(SensorData(updatedAt: now)), isTrue);
      expect(sensorsOnline(SensorData(updatedAt: now - 30)), isTrue);
      expect(sensorsOnline(SensorData(updatedAt: now - 120)), isFalse);
      expect(sensorsOnline(SensorData()), isFalse); // never updated
    });
  });

  group('Banana browning analysis', () {
    test('visual status thresholds', () {
      expect(BananaAnalysis.statusForPercentage(5), 'Fresh');
      expect(BananaAnalysis.statusForPercentage(15), 'Slight Browning');
      expect(BananaAnalysis.statusForPercentage(35), 'Browning Detected');
      expect(BananaAnalysis.statusForPercentage(60), 'Consume Soon');
    });

    test('a fully yellow image reports no browning', () {
      final img.Image im = img.Image(width: 80, height: 80);
      img.fill(im, color: img.ColorRgb8(240, 205, 50));
      final Uint8List bytes = img.encodePng(im);
      final BananaAnalysis r =
          BananaAnalysisService.analyzeBytes(bytes, 'banana_x');
      expect(r.totalBrowningPercentage, lessThan(5));
      expect(r.visualStatus, 'Fresh');
    });

    test('a yellow image with a brown strip reports browning', () {
      final img.Image im = img.Image(width: 100, height: 100);
      img.fill(im, color: img.ColorRgb8(240, 205, 50));      // yellow
      img.fillRect(im,
          x1: 0, y1: 0, x2: 29, y2: 99,
          color: img.ColorRgb8(120, 78, 30));                // 30% brown
      final Uint8List bytes = img.encodePng(im);
      final BananaAnalysis r =
          BananaAnalysisService.analyzeBytes(bytes, 'banana_x');
      expect(r.brownSpotPercentage, greaterThan(20));
      expect(r.totalBrowningPercentage, greaterThan(20));
      expect(r.visualStatus, isNot('Fresh'));
    });
  });
}
