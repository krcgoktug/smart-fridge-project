import '../models/product.dart';
import '../models/sensor_data.dart';

/// The result of a risk computation: each component plus the total.
class RiskBreakdown {
  RiskBreakdown({
    required this.expiryRisk,
    required this.temperatureRisk,
    required this.humidityRisk,
    required this.gasRisk,
    required this.visualRisk,
    required this.weightRisk,
  });

  final int expiryRisk;
  final int temperatureRisk;
  final int humidityRisk;
  final int gasRisk;
  final int visualRisk;
  final int weightRisk;

  /// Total score, clamped to 0..100.
  int get total {
    final int sum = expiryRisk +
        temperatureRisk +
        humidityRisk +
        gasRisk +
        visualRisk +
        weightRisk;
    return sum.clamp(0, 100);
  }

  String get status => RiskService.statusFromScore(total);
}

/// Estimates a *relative* spoilage risk score (0..100).
///
/// This is a transparent heuristic, not a calibrated spoilage model:
///   riskScore = expiryRisk + temperatureRisk + humidityRisk
///             + gasRisk + visualRisk + weightRisk
///
/// Different product categories use different components — see
/// docs/architecture.md.
class RiskService {
  // Ideal cold-storage ranges.
  static const double tempIdealMin = 2;
  static const double tempIdealMax = 6;
  static const double humIdealMin = 50;
  static const double humIdealMax = 80;

  /// Map a numeric score to one of the three status bands.
  static String statusFromScore(int score) {
    if (score >= 70) return 'Spoilage Risk';
    if (score >= 40) return 'Consume Soon';
    return 'Fresh';
  }

  // --- Individual components -------------------------------------------------

  /// expiryRisk: 0..40, driven by hours remaining to the expiry date.
  static int expiryRisk(int hoursLeft) {
    if (hoursLeft <= 0) return 40;
    if (hoursLeft <= 12) return 34;
    if (hoursLeft <= 24) return 26;
    if (hoursLeft <= 48) return 16;
    if (hoursLeft <= 72) return 9;
    if (hoursLeft <= 120) return 4;
    return 0;
  }

  /// temperatureRisk: 0..20, +4 per degree outside the ideal cold range.
  static int temperatureRisk(num temperature) {
    double dev = 0;
    if (temperature < tempIdealMin) {
      dev = tempIdealMin - temperature;
    } else if (temperature > tempIdealMax) {
      dev = temperature - tempIdealMax;
    }
    return (dev * 4).round().clamp(0, 20);
  }

  /// humidityRisk: 0..15, +1 per percent outside the ideal band.
  static int humidityRisk(num humidity) {
    double dev = 0;
    if (humidity < humIdealMin) {
      dev = humIdealMin - humidity;
    } else if (humidity > humIdealMax) {
      dev = humidity - humIdealMax;
    }
    return dev.round().clamp(0, 15);
  }

  /// gasRisk: 0..25, banded on the MQ135 raw 12-bit ADC reading.
  static int gasRisk(num gasValue) {
    if (gasValue >= 2500) return 25;
    if (gasValue >= 2000) return 21;
    if (gasValue >= 1500) return 16;
    if (gasValue >= 1000) return 9;
    return 0;
  }

  /// visualRisk: 0..25, banded on the measured banana browning ratio.
  static int visualRisk(double? browningRatio) {
    if (browningRatio == null) return 0;
    if (browningRatio >= 0.65) return 25;
    if (browningRatio >= 0.45) return 21;
    if (browningRatio >= 0.25) return 16;
    if (browningRatio >= 0.10) return 9;
    return 0;
  }

  /// weightRisk: 0..15, based on deviation from the expected weight range.
  static int weightRisk(num? currentWeight, num weightMin, num weightMax) {
    if (currentWeight == null) return 0;
    double dev = 0;
    if (currentWeight < weightMin) {
      dev = (weightMin - currentWeight).toDouble();
    } else if (currentWeight > weightMax) {
      dev = (currentWeight - weightMax).toDouble();
    } else {
      return 0; // inside the acceptable range
    }
    // Scale: the full band width maps to the full 15-point penalty.
    final double band = (weightMax - weightMin).toDouble();
    if (band <= 0) return dev > 0 ? 8 : 0;
    return ((dev / band) * 15).round().clamp(0, 15);
  }

  // --- Composition by category ----------------------------------------------

  /// Compute the full risk breakdown for a product given the current sensors.
  ///
  /// Component selection by category:
  ///   Fruit/Vegetable : expiry + temperature + humidity + gas + visual
  ///   Dairy/Egg/Packaged Food : expiry + temperature + weight
  static RiskBreakdown computeForProduct(Product product, SensorData sensors) {
    final int hoursLeft = product.remainingHours?.toInt() ??
        product.hoursUntilExpiry();

    final int eRisk = expiryRisk(hoursLeft);
    final int tRisk = temperatureRisk(sensors.temperature);

    if (product.isFruitOrVegetable) {
      return RiskBreakdown(
        expiryRisk: eRisk,
        temperatureRisk: tRisk,
        humidityRisk: humidityRisk(sensors.humidity),
        gasRisk: gasRisk(sensors.gasValue),
        visualRisk: visualRisk(product.browningRatio),
        weightRisk: 0,
      );
    }

    // Dairy, Egg, Packaged Food.
    return RiskBreakdown(
      expiryRisk: eRisk,
      temperatureRisk: tRisk,
      humidityRisk: 0,
      gasRisk: 0,
      visualRisk: 0,
      weightRisk: weightRisk(
        product.currentWeight,
        product.weightMin,
        product.weightMax,
      ),
    );
  }

  /// Apply a freshly computed risk to the product (mutates riskScore/status).
  static RiskBreakdown applyToProduct(Product product, SensorData sensors) {
    final RiskBreakdown breakdown = computeForProduct(product, sensors);
    product.riskScore = breakdown.total;
    product.status = breakdown.status;
    product.remainingHours ??= product.hoursUntilExpiry();
    return breakdown;
  }

  /// Global score for the dashboard: the worst (highest) product score.
  /// Falls back to the firmware sensor-side score when there are no products.
  static int globalScore(List<Product> products, SensorData sensors) {
    if (products.isEmpty) return sensors.riskScore.toInt().clamp(0, 100);
    int worst = 0;
    for (final Product p in products) {
      if (p.riskScore > worst) worst = p.riskScore.toInt();
    }
    return worst.clamp(0, 100);
  }
}
