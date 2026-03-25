// firebase_options.dart
//
// Uses the same Firebase project as Kleenops (kleenops).
// Run `flutterfire configure` to generate admin-specific app IDs later.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
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
      case TargetPlatform.windows:
        return windows;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBUXyYoeCPLMc6JhpptzQ0qmv5R1fIcKZA',
    appId: '1:129855314963:android:61d446c9a695c031fcf3e6',
    messagingSenderId: '129855314963',
    projectId: 'kleenops',
    storageBucket: 'kleenops.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyC7oh95zlm2jCbrzB28LcgEpTGia4mmSL0',
    appId: '1:129855314963:ios:eb46d99b2fdf77b0fcf3e6',
    messagingSenderId: '129855314963',
    projectId: 'kleenops',
    storageBucket: 'kleenops.firebasestorage.app',
    iosClientId: '129855314963-9not07jfs1r0u5806s5ecvrafnqq0u8s.apps.googleusercontent.com',
    iosBundleId: 'com.kleenops.admin',
  );

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCtSTULakEwgfIt5i8Bogr6J6agJKpS8Ss',
    appId: '1:129855314963:web:6c970192581bbd1afcf3e6',
    messagingSenderId: '129855314963',
    projectId: 'kleenops',
    authDomain: 'kleenops.firebaseapp.com',
    storageBucket: 'kleenops.firebasestorage.app',
    measurementId: 'G-31PGTDEDHB',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyCtSTULakEwgfIt5i8Bogr6J6agJKpS8Ss',
    appId: '1:129855314963:web:43b5e769c40fd004fcf3e6',
    messagingSenderId: '129855314963',
    projectId: 'kleenops',
    authDomain: 'kleenops.firebaseapp.com',
    storageBucket: 'kleenops.firebasestorage.app',
    measurementId: 'G-8Z0NC51C5D',
  );
}
