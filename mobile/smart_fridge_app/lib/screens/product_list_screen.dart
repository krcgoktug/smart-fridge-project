import 'package:flutter/material.dart';

import '../models/product.dart';
import '../services/firebase_service.dart';
import '../widgets/product_card.dart';

/// Screen 2 - Products. Read-only list of QR-detected products.
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
            itemBuilder: (BuildContext context, int i) =>
                ProductCard(product: products[i]),
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
              'Products appear here when the backend detects their QR code '
              'on the camera.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }
}
