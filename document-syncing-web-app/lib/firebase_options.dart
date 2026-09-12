import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError('Platform not supported.');
    }
  }
  
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCJp-0KGVh2h9o8O91jmiJZRcfYCfEAYlY',
    appId: '1:1091443132360:web:7c7690e6f4ec37f94122fd',
    messagingSenderId: '1091443132360',
    projectId: 'document-tracking-system-61b9e',
    authDomain: 'document-tracking-system-61b9e.firebaseapp.com',
    storageBucket: 'document-tracking-system-61b9e.firebasestorage.app',
    measurementId: 'G-MEFK6GDF1G',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCp3DDGxysHcUNINM5AlmUbUpEUHLstMK8',
    appId: '1:1091443132360:android:03960e5ec3ba7cb34122fd',
    messagingSenderId: '1091443132360',
    projectId: 'document-tracking-system-61b9e',
    storageBucket: 'document-tracking-system-61b9e.firebasestorage.app',
  );
}