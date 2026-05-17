import 'package:flutter/material.dart';

import '../utils/status_colors.dart';

/// A small colored pill showing a status word.
class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.status, this.compact = false});

  final String status;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final Color color = StatusColors.forStatus(status);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 12,
        vertical: compact ? 3 : 6,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: compact ? 11 : 13,
        ),
      ),
    );
  }
}

/// A circular score indicator (0..100) tinted by risk band.
class RiskScoreCircle extends StatelessWidget {
  const RiskScoreCircle({super.key, required this.score, this.size = 72});

  final num score;
  final double size;

  @override
  Widget build(BuildContext context) {
    final Color color = StatusColors.forScore(score);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.15),
        border: Border.all(color: color, width: 3),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Text(
            '${score.toInt()}',
            style: TextStyle(
              fontSize: size * 0.32,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            'risk',
            style: TextStyle(fontSize: size * 0.14, color: color),
          ),
        ],
      ),
    );
  }
}
