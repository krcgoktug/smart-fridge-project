/// A user-facing alert. Alerts are derived on the device from the data the
/// app reads (sensors, products, banana analysis) — they are not stored in
/// Firebase.
class Alert {
  const Alert(this.message, this.severity);

  final String message;
  final String severity; // info | warning | danger
}
