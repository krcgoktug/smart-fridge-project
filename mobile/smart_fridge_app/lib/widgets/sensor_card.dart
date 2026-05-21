import 'package:flutter/material.dart';

/// A compact card showing one sensor reading with an icon.
class SensorCard extends StatelessWidget {
  const SensorCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
    this.enabled = true,
    this.large = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final String unit;
  final Color color;

  /// When false the card is dimmed (e.g. the ESP32 is offline).
  final bool enabled;

  /// Bigger typography / spacing for the wide desktop layout.
  final bool large;

  @override
  Widget build(BuildContext context) {
    final Color c = enabled ? color : Colors.grey;
    return Card(
      elevation: 1.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: EdgeInsets.all(large ? 22 : 14),
        child: Column(
          mainAxisAlignment:
              large ? MainAxisAlignment.center : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  padding: EdgeInsets.all(large ? 12 : 8),
                  decoration: BoxDecoration(
                    color: c.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: c, size: large ? 30 : 20),
                ),
                SizedBox(width: large ? 14 : 10),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                        fontSize: large ? 18 : 13,
                        color: Colors.black54,
                        fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            SizedBox(height: large ? 20 : 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: <Widget>[
                Text(
                  enabled ? value : '--',
                  style: TextStyle(
                      fontSize: large ? 48 : 24,
                      fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 5),
                Text(unit,
                    style: TextStyle(
                        fontSize: large ? 18 : 13, color: Colors.black45)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
