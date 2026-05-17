import 'package:flutter/material.dart';

/// Maps risk scores / statuses to the green / yellow / red palette used
/// across the whole UI.
class StatusColors {
  static const Color fresh = Color(0xFF2E7D32); // green
  static const Color consumeSoon = Color(0xFFF9A825); // amber
  static const Color spoilage = Color(0xFFC62828); // red
  static const Color neutral = Color(0xFF607D8B); // blue-grey

  /// Color for a 0..100 risk score.
  static Color forScore(num score) {
    if (score >= 70) return spoilage;
    if (score >= 40) return consumeSoon;
    return fresh;
  }

  /// Color for a status string.
  static Color forStatus(String status) {
    switch (status) {
      case 'Spoilage Risk':
        return spoilage;
      case 'Consume Soon':
        return consumeSoon;
      case 'Fresh':
        return fresh;
      default:
        return neutral;
    }
  }

  /// Soft background tint of a status color.
  static Color tintFor(num score) => forScore(score).withValues(alpha: 0.12);

  /// Color for an alert severity.
  static Color forSeverity(String severity) {
    switch (severity) {
      case 'danger':
        return spoilage;
      case 'warning':
        return consumeSoon;
      default:
        return neutral;
    }
  }

  /// Icon for an alert severity.
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
