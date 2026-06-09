// lib/bootstrap/boot_service.dart
//
// Boot for the admin app: Firebase core + App Check + (since the calling port)
// the FCM/incoming-call bridge for voice/video calls.

import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kReleaseMode, kIsWeb, debugPrint;
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/material.dart';

import '../firebase_options.dart';
import '../services/call_messaging_service.dart';
import 'package:shared_widgets/services/catalog_firebase_service.dart';

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

    // 3b. Firebase Analytics — touching the singleton ensures first_open /
    // session_start auto-events fire on cold launch. Custom funnel events go
    // through AnalyticsService.
    await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(true);

    // 4. Catalog (uses default kleenops project — no separate init needed)
    await CatalogFirebaseService.instance.init();

    // 5. FCM + CallKit bridge for the ported voice/video calling. Best-effort:
    // a failure here (e.g. no notification permission yet) must not block boot.
    try {
      await CallMessagingService.instance.init();
    } catch (e) {
      debugPrint('[Boot] CallMessagingService init failed: $e');
    }
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
