import '../models/alert.dart';
import '../models/banana_analysis.dart';
import '../models/product.dart';
import '../models/sensor_data.dart';

/// Derives the alert list live on the device from the data the app reads.
class AlertService {
  static List<Alert> derive({
    required SensorData sensors,
    required List<Product> products,
    bool cameraConfigured = false,
    bool cameraOnline = true,
    BananaAnalysis? banana,
  }) {
    final List<Alert> alerts = <Alert>[];

    // Banana browning alert when >= 50 %.
    if (banana != null && banana.detected && banana.spotPercent >= 50) {
      final bool spoiled = banana.spotPercent >= 80;
      alerts.add(Alert(
        message: spoiled
            ? 'Banana is spoiled — '
                '${banana.spotPercent.toStringAsFixed(0)} % browning, discard.'
            : 'Banana is spoiling — '
                '${banana.spotPercent.toStringAsFixed(0)} % browning, consume soon.',
        severity: spoiled ? 'danger' : 'warning',
        type: 'banana',
      ));
    }

    if (!sensors.isOnline) {
      alerts.add(const Alert(
        message: 'ESP32 Sensor Board Offline — no live sensor data.',
        severity: 'warning',
        type: 'esp32',
      ));
    }

    if (cameraConfigured && !cameraOnline) {
      alerts.add(const Alert(
        message: 'Camera offline — ESP32-CAM unreachable. Check the Wi-Fi.',
        severity: 'warning',
        type: 'camera',
      ));
    }

    for (final Product p in products) {
      final String status = p.expiryStatus();
      if (status == 'Expired') {
        alerts.add(Alert(
          message: '${p.name} has expired.',
          severity: 'danger',
          type: 'expiry',
        ));
      } else if (status == 'Expiring Soon') {
        alerts.add(Alert(
          message: '${p.name} is expiring soon (${p.remainingLabel()}).',
          severity: 'warning',
          type: 'expiry',
        ));
      }
    }

    return alerts;
  }
}
