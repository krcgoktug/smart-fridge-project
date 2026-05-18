import 'package:flutter_test/flutter_test.dart';
import 'package:smart_fridge_app/models/camera_info.dart';
import 'package:smart_fridge_app/models/detection_event.dart';
import 'package:smart_fridge_app/models/product.dart';
import 'package:smart_fridge_app/models/sensor_data.dart';
import 'package:smart_fridge_app/services/auto_registration_service.dart';
import 'package:smart_fridge_app/services/demo_data.dart';
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

  group('Automatic product registration (demo flow)', () {
    test('simulateProductPlaced raises an addition detection event',
        () async {
      final DemoRepository repo = DemoRepository.instance;
      repo.simulateProductPlaced();
      final DetectionEvent event = await repo.detectionStream().first;
      expect(event.newProductDetected, isTrue);
      expect(event.isAddition, isTrue);
      expect(event.weightDelta, greaterThan(0));
    });

    test('AutoRegistrationService registers the detected product', () async {
      final DemoRepository repo = DemoRepository.instance;
      final int before = (await repo.productsStream().first).length;

      repo.simulateProductPlaced();
      final DetectionEvent event = await repo.detectionStream().first;

      final AutoRegistrationResult result =
          await AutoRegistrationService.register(
        event: event,
        camera: CameraInfo(),
      );

      expect(result.status, AutoRegStatus.success);
      expect(result.product, isNotNull);

      final int after = (await repo.productsStream().first).length;
      expect(after, before + 1);

      // The detection flag must be cleared after registration.
      final DetectionEvent cleared = await repo.detectionStream().first;
      expect(cleared.newProductDetected, isFalse);
    });

    test('non-addition events are ignored', () async {
      final AutoRegistrationResult result =
          await AutoRegistrationService.register(
        event: DetectionEvent(eventType: 'removed', weightDelta: -120),
        camera: CameraInfo(),
      );
      expect(result.status, AutoRegStatus.ignored);
    });
  });
}
