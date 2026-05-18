import 'package:flutter/material.dart';

import '../models/product.dart';
import '../utils/status_colors.dart';
import 'status_badge.dart';

/// A read-only card representing one QR-detected product.
class ProductCard extends StatelessWidget {
  const ProductCard({super.key, required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    final String status = product.expiryStatus();
    final Color color = StatusColors.forExpiryStatus(status);
    return Card(
      elevation: 1.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: <Widget>[
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.qr_code_2, color: color, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Flexible(
                        child: Text(product.productName,
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600)),
                      ),
                      if (product.category.isNotEmpty) ...<Widget>[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(product.category,
                              style: const TextStyle(
                                  fontSize: 10, color: Colors.black54)),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    product.expiryDate.isEmpty
                        ? 'No expiry date'
                        : 'Expiry: ${product.expiryDate}',
                    style: const TextStyle(
                        fontSize: 12, color: Colors.black54),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: <Widget>[
                      const Icon(Icons.schedule,
                          size: 13, color: Colors.black45),
                      const SizedBox(width: 4),
                      Text(product.remainingLabel(),
                          style: const TextStyle(
                              fontSize: 12, color: Colors.black54)),
                    ],
                  ),
                ],
              ),
            ),
            StatusBadge(status: status, color: color, compact: true),
          ],
        ),
      ),
    );
  }
}
