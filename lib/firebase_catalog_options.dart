// firebase_catalog_options.dart
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class CatalogFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        throw UnsupportedError(
          'CatalogFirebaseOptions have not been configured for macos - '
          'you can configure this by registering a macOS app in Firebase.',
        );
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        throw UnsupportedError(
          'CatalogFirebaseOptions have not been configured for linux - '
          'you can configure this by registering a Linux app in Firebase.',
        );
      default:
        throw UnsupportedError(
          'CatalogFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDyfO5XqvukJLwNtq_McF9p0A9BtKgMJl4',
    appId: '1:320833550293:android:98b2e05d8f6d26cbf0ef5c',
    messagingSenderId: '320833550293',
    projectId: 'kleenopscatalog',
    storageBucket: 'kleenopscatalog.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBG3Nhfpqhmca_IciPJ6eCU7NwXBBsK1VY',
    appId: '1:320833550293:ios:d3c85793012793acf0ef5c',
    messagingSenderId: '320833550293',
    projectId: 'kleenopscatalog',
    storageBucket: 'kleenopscatalog.firebasestorage.app',
    iosBundleId: 'com.kleenops.app',
  );

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAHOSipX3yeiSFXQSPcqXXMqwlIxvNbLRM',
    appId: '1:320833550293:web:ed212808bca1d00ef0ef5c',
    messagingSenderId: '320833550293',
    projectId: 'kleenopscatalog',
    authDomain: 'kleenopscatalog.firebaseapp.com',
    storageBucket: 'kleenopscatalog.firebasestorage.app',
    measurementId: 'G-YZBZT9731J',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyAHOSipX3yeiSFXQSPcqXXMqwlIxvNbLRM',
    appId: '1:320833550293:web:ed212808bca1d00ef0ef5c',
    messagingSenderId: '320833550293',
    projectId: 'kleenopscatalog',
    authDomain: 'kleenopscatalog.firebaseapp.com',
    storageBucket: 'kleenopscatalog.firebasestorage.app',
    measurementId: 'G-YZBZT9731J',
  );
}
