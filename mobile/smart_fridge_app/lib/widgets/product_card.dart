import 'package:flutter/material.dart';

import '../models/product.dart';
import '../utils/status_colors.dart';
import 'status_badge.dart';

/// A card representing one product in the Products list.
class ProductCard extends StatelessWidget {
  const ProductCard({super.key, required this.product, this.onDelete});

  final Product product;

  /// When provided, a trash-can button is shown that removes the product
  /// from the system. Omitted on read-only summaries (e.g. the Dashboard).
  final VoidCallback? onDelete;

  IconData _categoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'fruit':
        return Icons.apple;
      case 'vegetable':
        return Icons.eco;
      case 'dairy':
        return Icons.egg_alt;
      case 'meat':
        return Icons.set_meal;
      default:
        return Icons.inventory_2;
    }
  }

  @override
  Widget build(BuildContext context) {
    final String status = product.expiryStatus();
    final Color color = StatusColors.forExpiryStatus(status);
    return Card(
      elevation: 1.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: <Widget>[
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(_categoryIcon(product.category),
                  color: color, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(product.name,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(
                    '${product.category}  ·  exp ${product.expiryDate}',
                    style: const TextStyle(
                        fontSize: 12, color: Colors.black54),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: <Widget>[
                      Icon(Icons.schedule, size: 13, color: color),
                      const SizedBox(width: 4),
                      Text(product.remainingLabel(),
                          style: TextStyle(
                              fontSize: 12,
                              color: color,
                              fontWeight: FontWeight.w500)),
                    ],
                  ),
                ],
              ),
            ),
            StatusBadge(label: status, color: color, compact: true),
            if (onDelete != null) ...<Widget>[
              const SizedBox(width: 4),
              IconButton(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline),
                color: StatusColors.danger,
                tooltip: 'Remove from fridge',
                visualDensity: VisualDensity.compact,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
