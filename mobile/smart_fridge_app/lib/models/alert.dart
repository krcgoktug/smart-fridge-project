/// A user-facing alert, read from `devices/<id>/alerts/<key>`.
///
/// Alerts are produced by the image analysis service (from sensor, product
/// and banana data) and stored in Firebase. The app only displays them.
class Alert {
  Alert({
    required this.message,
    required this.severity,
    this.type = '',
    this.createdAt = 0,
  });

  final String message;
  final String severity; // info | warning | danger
  final String type; // sensor | expiry | banana
  final num createdAt; // Unix seconds

  /// Sort weight — danger first, then warning, then info.
  int get severityRank {
    switch (severity) {
      case 'danger':
        return 0;
      case 'warning':
        return 1;
      default:
        return 2;
    }
  }

  factory Alert.fromMap(Map<dynamic, dynamic> map) {
    num n(dynamic v) {
      if (v == null) return 0;
      if (v is num) return v;
      return num.tryParse(v.toString()) ?? 0;
    }

    return Alert(
      message: (map['message'] ?? '').toString(),
      severity: (map['severity'] ?? 'info').toString(),
      type: (map['type'] ?? '').toString(),
      createdAt: n(map['createdAt']),
    );
  }
}
