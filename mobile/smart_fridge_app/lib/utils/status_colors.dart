import 'package:flutter/material.dart';

/// Green / amber / red status palette used across the UI.
class StatusColors {
  static const Color fresh = Color(0xFF2E7D32); // green
  static const Color warning = Color(0xFFF9A825); // amber
  static const Color danger = Color(0xFFC62828); // red
  static const Color neutral = Color(0xFF607D8B); // blue-grey

  /// Color for an expiry status (Fresh / Expiring Soon / Expired).
  static Color forExpiryStatus(String status) {
    switch (status) {
      case 'Expired':
        return danger;
      case 'Expiring Soon':
        return warning;
      case 'Fresh':
        return fresh;
      default:
        return neutral;
    }
  }

  /// Color for an online/offline boolean.
  static Color online(bool isOnline) => isOnline ? fresh : danger;

  /// Color for an alert severity (info / warning / danger).
  static Color forSeverity(String severity) {
    switch (severity) {
      case 'danger':
        return danger;
      case 'warning':
        return warning;
      default:
        return neutral;
    }
  }

  static IconData iconForSeverity(String severity) {
    switch (severity) {
      case 'danger':
        return Icons.error_outline;
      case 'warning':
        return Icons.warning_amber_rounded;
      default:
        return Icons.info_outline;
    }
  }
}
