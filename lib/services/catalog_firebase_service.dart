// lib/services/catalog_firebase_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart' as firebase_storage;
import 'package:flutter/foundation.dart' show debugPrint, kReleaseMode;

import '../firebase_catalog_options.dart';

class CatalogFirebaseService {
  CatalogFirebaseService._();
  static final CatalogFirebaseService instance = CatalogFirebaseService._();

  static const String _appName = 'catalog';
  FirebaseApp? _app;

  FirebaseApp get app {
    final app = _app;
    if (app == null) {
      throw StateError('Catalog Firebase not initialized. Call init() first.');
    }
    return app;
  }

  Future<FirebaseApp> init() async {
    if (_app != null) return _app!;
    try {
      _app = await Firebase.initializeApp(
        name: _appName,
        options: CatalogFirebaseOptions.currentPlatform,
      );
    } on FirebaseException catch (e) {
      if (e.code == 'duplicate-app') {
        _app = Firebase.app(_appName);
      } else {
        rethrow;
      }
    }

    await _ensureAnonymousAuth();
    return _app!;
  }

  FirebaseFirestore get firestore {
    final app = _app;
    if (app == null) {
      throw StateError('Catalog Firebase not initialized. Call init() first.');
    }
    return FirebaseFirestore.instanceFor(app: app);
  }

  FirebaseAuth get auth {
    final app = _app;
    if (app == null) {
      throw StateError('Catalog Firebase not initialized. Call init() first.');
    }
    return FirebaseAuth.instanceFor(app: app);
  }

  firebase_storage.FirebaseStorage get storage {
    final app = _app;
    if (app == null) {
      throw StateError('Catalog Firebase not initialized. Call init() first.');
    }
    return firebase_storage.FirebaseStorage.instanceFor(app: app);
  }

  FirebaseFunctions functions({String region = 'us-central1'}) {
    final app = _app;
    if (app == null) {
      throw StateError('Catalog Firebase not initialized. Call init() first.');
    }
    return FirebaseFunctions.instanceFor(app: app, region: region);
  }

  Future<void> _ensureAnonymousAuth() async {
    final auth = FirebaseAuth.instanceFor(app: _app!);
    if (auth.currentUser != null) return;
    await auth.signInAnonymously();
    _debugLog('[CatalogFirebase] Anonymous auth signed in.');
  }

  void _debugLog(String message) {
    if (!kReleaseMode) {
      debugPrint(message);
    }
  }
}
