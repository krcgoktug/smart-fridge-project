import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../app_config.dart';
import '../models/product.dart';
import '../services/firebase_service.dart';
import '../utils/status_colors.dart';

/// Screen 3 - Add Product / QR Scan.
///
/// Scans a product QR code, parses the JSON payload, lets the user confirm,
/// then writes the product to Firebase. A manual-entry form is offered as a
/// fallback for demos without a working camera.
class AddProductScreen extends StatefulWidget {
  const AddProductScreen({super.key});

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final MobileScannerController _controller = MobileScannerController();
  bool _handling = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_handling) return;
    final List<Barcode> codes = capture.barcodes;
    if (codes.isEmpty) return;
    final String? raw = codes.first.rawValue;
    if (raw == null || raw.isEmpty) return;

    setState(() => _handling = true);
    await _controller.stop();
    _processPayload(raw);
  }

  void _processPayload(String raw) {
    Product? product;
    String? error;
    try {
      final dynamic decoded = jsonDecode(raw);
      if (decoded is! Map) {
        error = 'QR content is not a product object.';
      } else {
        final Map<String, dynamic> map =
            decoded.map((k, v) => MapEntry(k.toString(), v));
        if ((map['productId'] ?? '').toString().isEmpty) {
          error = 'QR code is missing "productId".';
        } else if (!AppConfig.categories
            .contains((map['category'] ?? '').toString())) {
          error = 'Unknown category "${map['category']}".';
        } else {
          product = Product.fromQrJson(map);
        }
      }
    } catch (_) {
      error = 'QR code does not contain valid JSON.';
    }

    if (product != null) {
      _showConfirmSheet(product);
    } else {
      _showError(error ?? 'Could not read the QR code.');
    }
  }

  void _showError(String message) {
    showDialog<void>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Scan failed'),
        content: Text(message),
        actions: <Widget>[
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _resumeScanning();
            },
            child: const Text('Try again'),
          ),
        ],
      ),
    );
  }

  Future<void> _resumeScanning() async {
    setState(() => _handling = false);
    await _controller.start();
  }

  void _showConfirmSheet(Product product) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext ctx) => _ConfirmSheet(
        product: product,
        onCancel: () {
          Navigator.of(ctx).pop();
          _resumeScanning();
        },
        onConfirm: () async {
          await FirebaseService.saveProduct(product);
          await FirebaseService.addAlert(
            '${product.name} added to the fridge.',
            'info',
            productId: product.productId,
          );
          if (!ctx.mounted) return;
          Navigator.of(ctx).pop(); // close sheet
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${product.name} saved.')),
          );
          Navigator.of(context).pop(); // close add screen
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Product'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Enter manually',
            icon: const Icon(Icons.edit_note),
            onPressed: () async {
              await _controller.stop();
              if (!mounted) return;
              final Product? p = await Navigator.of(context).push(
                MaterialPageRoute<Product>(
                    builder: (_) => const _ManualEntryForm()),
              );
              if (p != null) {
                _showConfirmSheet(p);
              } else {
                _resumeScanning();
              }
            },
          ),
        ],
      ),
      body: FirebaseService.ready
          ? Column(
              children: <Widget>[
                Expanded(
                  child: Stack(
                    alignment: Alignment.center,
                    children: <Widget>[
                      MobileScanner(
                        controller: _controller,
                        onDetect: _onDetect,
                      ),
                      // Simple aiming frame.
                      Container(
                        width: 220,
                        height: 220,
                        decoration: BoxDecoration(
                          border: Border.all(
                              color: Colors.white, width: 3),
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ],
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Point the camera at a product QR code.',
                    style: TextStyle(color: Colors.black54),
                  ),
                ),
              ],
            )
          : const _NoFirebaseFallback(),
    );
  }
}

/// Confirmation sheet shown after a successful scan / manual entry.
class _ConfirmSheet extends StatelessWidget {
  const _ConfirmSheet({
    required this.product,
    required this.onConfirm,
    required this.onCancel,
  });

  final Product product;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 130,
            child: Text(label,
                style: const TextStyle(color: Colors.black54)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(Icons.qr_code_2, color: StatusColors.fresh),
              const SizedBox(width: 8),
              Text(product.name,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold)),
            ],
          ),
          const Divider(height: 24),
          _row('Product ID', product.productId),
          _row('Category', product.category),
          _row('Brand', product.brand),
          _row('Expiry date', product.expiryDate),
          _row('Added date', product.addedDate),
          _row('Expected weight', '${product.expectedWeight} g'),
          _row('Weight range',
              '${product.weightMin} - ${product.weightMax} g'),
          _row('Storage', product.storageType),
          const SizedBox(height: 18),
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton(
                  onPressed: onCancel,
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: onConfirm,
                  icon: const Icon(Icons.save),
                  label: const Text('Save product'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NoFirebaseFallback extends StatelessWidget {
  const _NoFirebaseFallback();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(28),
        child: Text(
          'Firebase is not configured, so scanned products cannot be '
          'saved. Run "flutterfire configure" first.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.black54),
        ),
      ),
    );
  }
}

/// Manual product entry form (fallback when no camera is available).
class _ManualEntryForm extends StatefulWidget {
  const _ManualEntryForm();

  @override
  State<_ManualEntryForm> createState() => _ManualEntryFormState();
}

class _ManualEntryFormState extends State<_ManualEntryForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _id = TextEditingController();
  final TextEditingController _name = TextEditingController();
  final TextEditingController _brand =
      TextEditingController(text: 'Generic');
  final TextEditingController _expiry = TextEditingController();
  final TextEditingController _expected = TextEditingController(text: '150');
  final TextEditingController _wMin = TextEditingController(text: '100');
  final TextEditingController _wMax = TextEditingController(text: '200');
  String _category = AppConfig.categories.first;

  @override
  void dispose() {
    for (final TextEditingController c in <TextEditingController>[
      _id, _name, _brand, _expiry, _expected, _wMin, _wMax
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  String _today() => DateTime.now().toIso8601String().split('T').first;

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final Product product = Product(
      productId: _id.text.trim(),
      name: _name.text.trim(),
      category: _category,
      brand: _brand.text.trim(),
      expiryDate: _expiry.text.trim(),
      addedDate: _today(),
      expectedWeight: num.tryParse(_expected.text) ?? 0,
      weightMin: num.tryParse(_wMin.text) ?? 0,
      weightMax: num.tryParse(_wMax.text) ?? 0,
    );
    Navigator.of(context).pop(product);
  }

  Widget _field(TextEditingController c, String label,
      {TextInputType? type, String? hint}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: c,
        keyboardType: type,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: const OutlineInputBorder(),
        ),
        validator: (String? v) =>
            (v == null || v.trim().isEmpty) ? 'Required' : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manual entry')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            _field(_id, 'Product ID', hint: 'e.g. banana_001'),
            _field(_name, 'Name'),
            DropdownButtonFormField<String>(
              value: _category,
              decoration: const InputDecoration(
                labelText: 'Category',
                border: OutlineInputBorder(),
              ),
              items: AppConfig.categories
                  .map((String c) =>
                      DropdownMenuItem<String>(value: c, child: Text(c)))
                  .toList(),
              onChanged: (String? v) =>
                  setState(() => _category = v ?? _category),
            ),
            const SizedBox(height: 12),
            _field(_brand, 'Brand'),
            _field(_expiry, 'Expiry date (YYYY-MM-DD)',
                hint: '2026-05-25'),
            _field(_expected, 'Expected weight (g)',
                type: TextInputType.number),
            _field(_wMin, 'Weight min (g)', type: TextInputType.number),
            _field(_wMax, 'Weight max (g)', type: TextInputType.number),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _submit,
              child: const Text('Continue'),
            ),
          ],
        ),
      ),
    );
  }
}
