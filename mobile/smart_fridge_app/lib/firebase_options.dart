// ===========================================================================
//  PLACEHOLDER Firebase configuration.
//
//  This file is committed with FAKE values so the project always compiles.
//  Before running against a real Firebase project, REPLACE it by running:
//
//      flutterfire configure
//
//  (Install the CLI first:  dart pub global activate flutterfire_cli)
//
//  Firebase *client* config is not a server secret, but do not commit a
//  config bound to a production project. Until this file is replaced, the
//  app builds and opens, but Firebase reads/writes will fail and the screens
//  show a "Firebase not configured" hint.
// ===========================================================================

import 'package:firebase_core/firebase_core.dart'
    show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        return android;
    }
  }

  // --- All values below are PLACEHOLDERS. Replace with your own. ---

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'PLACEHOLDER_API_KEY',
    appId: '1:000000000000:android:0000000000000000000000',
    messagingSenderId: '000000000000',
    projectId: 'your-project-id',
    databaseURL: 'https://your-project-id-default-rtdb.firebaseio.com',
    storageBucket: 'your-project-id.appspot.com',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'PLACEHOLDER_API_KEY',
    appId: '1:000000000000:ios:0000000000000000000000',
    messagingSenderId: '000000000000',
    projectId: 'your-project-id',
    databaseURL: 'https://your-project-id-default-rtdb.firebaseio.com',
    storageBucket: 'your-project-id.appspot.com',
    iosBundleId: 'com.example.smartFridgeApp',
  );

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'PLACEHOLDER_API_KEY',
    appId: '1:000000000000:web:0000000000000000000000',
    messagingSenderId: '000000000000',
    projectId: 'your-project-id',
    databaseURL: 'https://your-project-id-default-rtdb.firebaseio.com',
    storageBucket: 'your-project-id.appspot.com',
    authDomain: 'your-project-id.firebaseapp.com',
  );
}
