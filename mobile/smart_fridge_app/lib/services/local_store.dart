import 'dart:async';

import '../models/product.dart';

/// In-memory store used when Firebase is not configured.
///
/// Holds ONLY the products the user actually scans -- there is no preloaded
/// fake data. The user sees their real scans immediately in the Products
/// tab; once Firebase is connected, scans persist + sync to teammates.
class LocalStore {
  LocalStore._();
  static final LocalStore instance = LocalStore._();

  final List<Product> _products = <Product>[];
  final StreamController<List<Product>> _ctrl =
      StreamController<List<Product>>.broadcast();

  Stream<List<Product>> productsStream() async* {
    yield List<Product>.of(_products);
    yield* _ctrl.stream;
  }

  void saveProduct(Product p) {
    _products.removeWhere((Product x) => x.productId == p.productId);
    _products.add(p);
    _emit();
  }

  void deleteProduct(String productId) {
    _products.removeWhere((Product x) => x.productId == productId);
    _emit();
  }

  void _emit() {
    final List<Product> sorted = List<Product>.of(_products)
      ..sort((Product a, Product b) =>
          a.daysUntilExpiry().compareTo(b.daysUntilExpiry()));
    _ctrl.add(sorted);
  }
}
