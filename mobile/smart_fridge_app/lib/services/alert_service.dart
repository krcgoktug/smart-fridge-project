import '../models/alert.dart';
import '../models/product.dart';
import '../models/sensor_data.dart';

/// Derives the alert list live on the device from the data the app reads.
class AlertService {
  static List<Alert> derive({
    required SensorData sensors,
    required List<Product> products,
    bool cameraConfigured = false,
    bool cameraOnline = true,
  }) {
    final List<Alert> alerts = <Alert>[];

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
