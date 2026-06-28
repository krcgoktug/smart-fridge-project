// Smart Fridge — Flutter dashboard entry point.
//
// The full screen graph (Dashboard / Camera / Products / Alerts /
// Settings) lives in a private branch. This entry stub keeps the
// scaffolding compilable so contributors can build the shell.

import 'package:flutter/material.dart';

void main() {
  runApp(const SmartFridgeApp());
}

class SmartFridgeApp extends StatelessWidget {
  const SmartFridgeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Fridge',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const _HomeStub(),
    );
  }
}

class _HomeStub extends StatelessWidget {
  const _HomeStub();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Smart Fridge')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Dashboard, Camera, Products and Alerts screens load here.\n'
            'Full implementation lives in the team archive.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
