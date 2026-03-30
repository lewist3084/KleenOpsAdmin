// lib/bootstrap/boot_service.dart
//
// Lightweight boot for the admin app.
// Initializes Firebase core + App Check. No FCM or video-call plumbing needed.

import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kReleaseMode, kIsWeb, debugPrint;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/material.dart';

import '../firebase_options.dart';
import '../services/catalog_firebase_service.dart';

class BootService {
  BootService._();
  static final instance = BootService._();

  Future<void> init() async {
    // 1. Firebase core
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } on FirebaseException catch (e) {
      if (e.code == 'duplicate-app') {
        debugPrint('[Boot] Firebase already initialized, reusing existing app');
      } else {
        rethrow;
      }
    }

    // 2. App Check
    await _activateAppCheck();

    // 3. Crashlytics
    if (!kIsWeb) {
      FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterError;
    }

    // 4. Catalog (uses default kleenops project — no separate init needed)
    await CatalogFirebaseService.instance.init();
  }

  Future<void> _activateAppCheck() async {
    if (kIsWeb) {
      const webSiteKey = String.fromEnvironment('APP_CHECK_WEB_SITE_KEY');
      if (webSiteKey.isNotEmpty) {
        await FirebaseAppCheck.instance.activate(
          providerWeb: ReCaptchaV3Provider(webSiteKey),
        );
      }
      return;
    }

    if (!kIsWeb && Platform.isAndroid) {
      final provider = kReleaseMode
          ? const AndroidPlayIntegrityProvider()
          : const AndroidDebugProvider();
      await FirebaseAppCheck.instance.activate(providerAndroid: provider);
    } else if (!kIsWeb && (Platform.isIOS || Platform.isMacOS)) {
      final provider = kReleaseMode
          ? const AppleDeviceCheckProvider()
          : const AppleDebugProvider();
      await FirebaseAppCheck.instance.activate(providerApple: provider);
    }
  }
}
