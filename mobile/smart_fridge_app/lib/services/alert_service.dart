import '../models/alert.dart';
import '../models/banana_analysis.dart';
import '../models/product.dart';
import '../models/sensor_data.dart';

/// Derives the alert list from the data the app reads. The app is a
/// visualization layer, so alerts are computed here rather than stored.
class AlertService {
  static List<Alert> derive({
    required SensorData sensors,
    required List<Product> products,
    required BananaAnalysis banana,
  }) {
    final List<Alert> alerts = <Alert>[];

    if (!sensors.isOnline) {
      alerts.add(const Alert(
        'ESP32 sensor board is offline — no live sensor data.',
        'warning',
      ));
    }

    for (final Product p in products) {
      final String status = p.expiryStatus();
      if (status == 'Expired') {
        alerts.add(Alert('${p.productName} has expired.', 'danger'));
      } else if (status == 'Expiring Soon') {
        alerts.add(Alert(
          '${p.productName} is expiring soon (${p.remainingLabel()}).',
          'warning',
        ));
      }
    }

    if (banana.hasData && banana.needsWarning) {
      alerts.add(Alert(
        banana.warningMessage,
        banana.status == 'Rotten' ? 'danger' : 'warning',
      ));
    }

    return alerts;
  }
}
