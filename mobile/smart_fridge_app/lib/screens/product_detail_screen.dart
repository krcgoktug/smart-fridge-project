import 'package:flutter/material.dart';

import '../models/product.dart';
import '../models/sensor_data.dart';
import '../services/firebase_service.dart';
import '../services/risk_service.dart';
import '../utils/status_colors.dart';
import '../widgets/status_badge.dart';

/// Screen 4 - Product Detail.
class ProductDetailScreen extends StatelessWidget {
  const ProductDetailScreen({super.key, required this.productId});

  final String productId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Product Detail'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Delete product',
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _confirmDelete(context),
          ),
        ],
      ),
      body: StreamBuilder<SensorData>(
        stream: FirebaseService.sensorStream(),
        builder: (BuildContext context,
            AsyncSnapshot<SensorData> sensorSnap) {
          final SensorData sensors = sensorSnap.data ?? SensorData();
          return StreamBuilder<List<Product>>(
            stream: FirebaseService.productsStream(),
            builder: (BuildContext context,
                AsyncSnapshot<List<Product>> snap) {
              final List<Product> products = snap.data ?? <Product>[];
              Product? product;
              for (final Product p in products) {
                if (p.productId == productId) product = p;
              }
              if (product == null) {
                return const Center(
                  child: Text('Product not found.'),
                );
              }
              final RiskBreakdown breakdown =
                  RiskService.applyToProduct(product, sensors);
              return _DetailBody(product: product, breakdown: breakdown);
            },
          );
        },
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Delete product?'),
        content: const Text('This removes the product from the fridge.'),
        actions: <Widget>[
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (ok == true) {
      await FirebaseService.deleteProduct(productId);
      if (context.mounted) Navigator.of(context).pop();
    }
  }
}

class _DetailBody extends StatelessWidget {
  const _DetailBody({required this.product, required this.breakdown});

  final Product product;
  final RiskBreakdown breakdown;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        // Header.
        Row(
          children: <Widget>[
            RiskScoreCircle(score: breakdown.total, size: 90),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(product.name,
                      style: const TextStyle(
                          fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  StatusBadge(status: breakdown.status),
                  const SizedBox(height: 8),
                  Text(product.remainingTimeLabel(),
                      style: const TextStyle(color: Colors.black54)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),

        _Section(
          title: 'QR metadata',
          rows: <_KV>[
            _KV('Product ID', product.productId),
            _KV('Category', product.category),
            _KV('Brand', product.brand),
            _KV('Added date', product.addedDate),
            _KV('Expiry date', product.expiryDate),
            _KV('Storage type', product.storageType),
          ],
        ),

        _Section(
          title: 'Weight',
          rows: <_KV>[
            _KV('Expected weight', '${product.expectedWeight} g'),
            _KV('Acceptable range',
                '${product.weightMin} - ${product.weightMax} g'),
            _KV('Current weight',
                product.currentWeight == null
                    ? 'not measured'
                    : '${product.currentWeight} g'),
          ],
        ),

        if (product.isFruitOrVegetable)
          _Section(
            title: 'Visual analysis',
            rows: <_KV>[
              _KV('Browning ratio',
                  product.browningRatio == null
                      ? 'not analyzed'
                      : product.browningRatio!.toStringAsFixed(2)),
              _KV('Visual status', product.visualStatus ?? 'not analyzed'),
            ],
          ),

        _RiskBreakdownCard(
            breakdown: breakdown, isFruit: product.isFruitOrVegetable),
      ],
    );
  }
}

class _KV {
  const _KV(this.key, this.value);
  final String key;
  final String value;
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.rows});
  final String title;
  final List<_KV> rows;

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(title,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.bold)),
            const Divider(height: 18),
            ...rows.map((_KV kv) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      SizedBox(
                        width: 140,
                        child: Text(kv.key,
                            style: const TextStyle(
                                color: Colors.black54)),
                      ),
                      Expanded(
                        child: Text(kv.value,
                            style: const TextStyle(
                                fontWeight: FontWeight.w500)),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }
}

class _RiskBreakdownCard extends StatelessWidget {
  const _RiskBreakdownCard(
      {required this.breakdown, required this.isFruit});

  final RiskBreakdown breakdown;
  final bool isFruit;

  Widget _bar(String label, int value, int max) {
    final double frac = max == 0 ? 0 : (value / max).clamp(0, 1).toDouble();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(label, style: const TextStyle(fontSize: 13)),
              Text('$value / $max',
                  style: const TextStyle(
                      fontSize: 12, color: Colors.black54)),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: frac,
              minHeight: 8,
              backgroundColor: Colors.black12,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> bars = <Widget>[
      _bar('Expiry risk', breakdown.expiryRisk, 40),
      _bar('Temperature risk', breakdown.temperatureRisk, 20),
    ];
    if (isFruit) {
      bars.add(_bar('Humidity risk', breakdown.humidityRisk, 15));
      bars.add(_bar('Gas risk', breakdown.gasRisk, 25));
      bars.add(_bar('Visual risk', breakdown.visualRisk, 25));
    } else {
      bars.add(_bar('Weight risk', breakdown.weightRisk, 15));
    }

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text('Risk breakdown',
                style: TextStyle(
                    fontSize: 15, fontWeight: FontWeight.bold)),
            const Divider(height: 18),
            ...bars,
            const Divider(height: 22),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                const Text('Final risk score',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                Text(
                  '${breakdown.total} / 100',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: StatusColors.forScore(breakdown.total),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
