import 'package:flutter_test/flutter_test.dart';
import 'package:smart_fridge_app/models/product.dart';
import 'package:smart_fridge_app/models/sensor_data.dart';
import 'package:smart_fridge_app/services/risk_service.dart';

void main() {
  group('RiskService status bands', () {
    test('maps scores to the correct status', () {
      expect(RiskService.statusFromScore(10), 'Fresh');
      expect(RiskService.statusFromScore(39), 'Fresh');
      expect(RiskService.statusFromScore(40), 'Consume Soon');
      expect(RiskService.statusFromScore(69), 'Consume Soon');
      expect(RiskService.statusFromScore(70), 'Spoilage Risk');
      expect(RiskService.statusFromScore(100), 'Spoilage Risk');
    });
  });

  group('RiskService components', () {
    test('expiryRisk grows as expiry approaches', () {
      expect(RiskService.expiryRisk(200), 0);
      expect(RiskService.expiryRisk(60), 9);
      expect(RiskService.expiryRisk(0), 40);
      expect(RiskService.expiryRisk(-5), 40);
    });

    test('temperatureRisk is zero inside the ideal range', () {
      expect(RiskService.temperatureRisk(4), 0);
      expect(RiskService.temperatureRisk(10), greaterThan(0));
    });

    test('gasRisk is banded on the MQ135 reading', () {
      expect(RiskService.gasRisk(500), 0);
      expect(RiskService.gasRisk(1600), 16);
      expect(RiskService.gasRisk(3000), 25);
    });
  });

  group('RiskService per-product composition', () {
    test('fruit uses gas and visual risk', () {
      final Product banana = Product(
        productId: 'banana_001',
        name: 'Banana',
        category: 'Fruit',
        brand: 'Generic',
        expiryDate: '2099-01-01',
        addedDate: '2026-01-01',
        expectedWeight: 150,
        weightMin: 100,
        weightMax: 180,
        browningRatio: 0.7,
      );
      final SensorData sensors = SensorData(gasValue: 2600);
      final RiskBreakdown b =
          RiskService.computeForProduct(banana, sensors);
      expect(b.gasRisk, 25);
      expect(b.visualRisk, 25);
      expect(b.weightRisk, 0);
    });

    test('dairy uses weight risk, not gas or visual', () {
      final Product milk = Product(
        productId: 'milk_001',
        name: 'Milk',
        category: 'Dairy',
        brand: 'Brand',
        expiryDate: '2099-01-01',
        addedDate: '2026-01-01',
        expectedWeight: 1000,
        weightMin: 900,
        weightMax: 1100,
        currentWeight: 400,
      );
      final SensorData sensors = SensorData(gasValue: 2600);
      final RiskBreakdown b =
          RiskService.computeForProduct(milk, sensors);
      expect(b.gasRisk, 0);
      expect(b.visualRisk, 0);
      expect(b.weightRisk, greaterThan(0));
    });
  });
}
