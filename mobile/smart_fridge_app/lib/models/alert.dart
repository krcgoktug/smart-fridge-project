/// A user-facing alert. Alerts are derived live on the device from the data
/// the app reads (sensors, products, camera) — they are not stored.
class Alert {
  const Alert({
    required this.message,
    required this.severity,
    required this.type,
  });

  final String message;
  final String severity; // info | warning | danger
  final String type; // expiry | esp32 | camera
}
