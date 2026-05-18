import 'package:flutter/material.dart';

import '../models/product.dart';
import '../utils/status_colors.dart';
import 'status_badge.dart';

/// A card row representing one product in the product list.
class ProductCard extends StatelessWidget {
  const ProductCard({super.key, required this.product, this.onTap});

  final Product product;
  final VoidCallback? onTap;

  IconData _categoryIcon(String category) {
    switch (category) {
      case 'Fruit':
        return Icons.apple;
      case 'Vegetable':
        return Icons.eco;
      case 'Dairy':
        return Icons.local_drink;
      case 'Egg':
        return Icons.egg;
      default:
        return Icons.inventory_2;
    }
  }

  @override
  Widget build(BuildContext context) {
    final String expiryStatus = product.expiryStatus();
    final Color expiryColor = StatusColors.forExpiryStatus(expiryStatus);
    final Color riskColor = StatusColors.forScore(product.riskScore);
    return Card(
      elevation: 1.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: <Widget>[
              // Expiry-status color tile + category icon.
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: expiryColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(_categoryIcon(product.category),
                    color: expiryColor, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      product.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${product.category}  -  exp ${product.expiryDate}',
                      style: const TextStyle(
                          fontSize: 12, color: Colors.black54),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: <Widget>[
                        const Icon(Icons.schedule,
                            size: 13, color: Colors.black45),
                        const SizedBox(width: 4),
                        Text(
                          product.remainingTimeLabel(),
                          style: const TextStyle(
                              fontSize: 12, color: Colors.black54),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  StatusBadge(
                    status: expiryStatus,
                    compact: true,
                    color: expiryColor,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'risk ${product.riskScore.toInt()}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: riskColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
