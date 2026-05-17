import 'package:flutter/material.dart';

import '../models/product.dart';
import '../models/sensor_data.dart';
import '../services/firebase_service.dart';
import '../services/risk_service.dart';
import '../widgets/firebase_notice.dart';
import '../widgets/product_card.dart';
import 'add_product_screen.dart';
import 'product_detail_screen.dart';

/// Screen 2 - Product List.
class ProductListScreen extends StatelessWidget {
  const ProductListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Products')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
              builder: (_) => const AddProductScreen()),
        ),
        child: const Icon(Icons.add),
      ),
      body: FirebaseService.ready
          ? const _ProductListBody()
          : const FirebaseNotice(),
    );
  }
}

class _ProductListBody extends StatelessWidget {
  const _ProductListBody();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<SensorData>(
      stream: FirebaseService.sensorStream(),
      builder: (BuildContext context, AsyncSnapshot<SensorData> sensorSnap) {
        final SensorData sensors = sensorSnap.data ?? SensorData();
        return StreamBuilder<List<Product>>(
          stream: FirebaseService.productsStream(),
          builder: (BuildContext context,
              AsyncSnapshot<List<Product>> snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final List<Product> products = snap.data ?? <Product>[];
            if (products.isEmpty) {
              return const _EmptyProducts();
            }
            for (final Product p in products) {
              RiskService.applyToProduct(p, sensors);
            }
            // Worst risk first.
            products.sort(
                (Product a, Product b) =>
                    b.riskScore.compareTo(a.riskScore));

            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 90),
              itemCount: products.length,
              itemBuilder: (BuildContext context, int i) {
                final Product p = products[i];
                return ProductCard(
                  product: p,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          ProductDetailScreen(productId: p.productId),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

class _EmptyProducts extends StatelessWidget {
  const _EmptyProducts();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(Icons.inventory_2_outlined,
              size: 60, color: Colors.black26),
          const SizedBox(height: 14),
          const Text('No products yet',
              style:
                  TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          const Text('Scan a product QR code to get started.',
              style: TextStyle(color: Colors.black54)),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                  builder: (_) => const AddProductScreen()),
            ),
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text('Scan QR code'),
          ),
        ],
      ),
    );
  }
}
