import 'package:flutter/material.dart';

import '../models/product.dart';
import '../services/firebase_service.dart';
import '../utils/status_colors.dart';
import '../widgets/product_card.dart';

/// Screen 3 - Products. QR-detected products with expiry status.
class ProductListScreen extends StatelessWidget {
  const ProductListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Products')),
      body: StreamBuilder<List<Product>>(
        stream: FirebaseService.productsStream(),
        builder: (BuildContext context, AsyncSnapshot<List<Product>> snap) {
          final List<Product> products = snap.data ?? <Product>[];
          if (products.isEmpty) {
            return const _Empty();
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
            itemCount: products.length,
            itemBuilder: (BuildContext context, int i) {
              final Product p = products[i];
              return Dismissible(
                key: ValueKey<String>(p.productId),
                direction: DismissDirection.endToStart,
                background: Container(
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  decoration: BoxDecoration(
                    color: StatusColors.danger,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                onDismissed: (_) =>
                    FirebaseService.deleteProduct(p.productId),
                child: ProductCard(product: p),
              );
            },
          );
        },
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.inventory_2_outlined, size: 60, color: Colors.black26),
            SizedBox(height: 14),
            Text('No products yet',
                style:
                    TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 6),
            Text(
              'Open the Camera tab and use "Scan QR" to register a product '
              'from its QR sticker.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }
}
