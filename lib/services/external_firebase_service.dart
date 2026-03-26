// lib/services/external_firebase_service.dart
//
// Firebase service for external companies (non-BYU tenants).
// Mirrors the pattern established by CatalogFirebaseService.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart' as firebase_storage;
import 'package:flutter/foundation.dart' show debugPrint, kReleaseMode;

import '../firebase_external_options.dart';

/// Service providing access to the external companies Firebase project.
///
/// External companies (non-BYU) store their data in a separate Firebase project
/// to maintain data isolation and enable future codebase/project splitting.
///
/// Usage:
/// ```dart
/// await ExternalFirebaseService.instance.init();
/// final firestore = ExternalFirebaseService.instance.firestore;
/// ```
class ExternalFirebaseService {
  ExternalFirebaseService._();
  static final ExternalFirebaseService instance = ExternalFirebaseService._();

  static const String _appName = 'external';
  FirebaseApp? _app;
  bool _initialized = false;

  FirebaseApp get app {
    _ensureInitialized();
    return _app!;
  }

  /// Whether this service has been successfully initialized.
  bool get isInitialized => _initialized;

  /// Initializes the external Firebase app.
  ///
  /// Safe to call multiple times; subsequent calls return the existing app.
  /// Uses the same authentication state as the main app (shared Google OAuth).
  Future<FirebaseApp> init() async {
    if (_app != null) return _app!;

    try {
      _app = await Firebase.initializeApp(
        name: _appName,
        options: ExternalFirebaseOptions.currentPlatform,
      );
      _initialized = true;
      _debugLog('[ExternalFirebase] Initialized app: $_appName');
    } on FirebaseException catch (e) {
      if (e.code == 'duplicate-app') {
        _app = Firebase.app(_appName);
        _initialized = true;
        _debugLog('[ExternalFirebase] Reusing existing app: $_appName');
      } else {
        _debugLog('[ExternalFirebase] Init error: ${e.code} - ${e.message}');
        rethrow;
      }
    }

    return _app!;
  }

  /// The Firestore instance for external companies.
  ///
  /// Throws [StateError] if [init] has not been called.
  FirebaseFirestore get firestore {
    _ensureInitialized();
    return FirebaseFirestore.instanceFor(app: _app!);
  }

  /// The Auth instance for external companies.
  ///
  /// Note: For shared authentication, you typically use the main app's auth
  /// and just access this project's Firestore. This getter is provided for
  /// cases where separate auth is needed.
  FirebaseAuth get auth {
    _ensureInitialized();
    return FirebaseAuth.instanceFor(app: _app!);
  }

  /// The Storage instance for external companies.
  firebase_storage.FirebaseStorage get storage {
    _ensureInitialized();
    return firebase_storage.FirebaseStorage.instanceFor(app: _app!);
  }

  void _ensureInitialized() {
    if (_app == null) {
      throw StateError(
        'External Firebase not initialized. Call ExternalFirebaseService.instance.init() first.',
      );
    }
  }

  void _debugLog(String message) {
    if (!kReleaseMode) {
      debugPrint(message);
    }
  }
}
