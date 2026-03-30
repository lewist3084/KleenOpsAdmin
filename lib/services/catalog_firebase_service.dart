// lib/services/catalog_firebase_service.dart
//
// Catalog data now lives in the default kleenops Firebase project.
// This service delegates to the default Firebase instances so that
// existing code using CatalogFirebaseService.instance.firestore
// continues to work without changes.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart' as firebase_storage;

class CatalogFirebaseService {
  CatalogFirebaseService._();
  static final CatalogFirebaseService instance = CatalogFirebaseService._();

  /// No-op init — catalog uses the default Firebase app (kleenops).
  Future<FirebaseApp> init() async => Firebase.app();

  FirebaseApp get app => Firebase.app();

  FirebaseFirestore get firestore => FirebaseFirestore.instance;

  FirebaseAuth get auth => FirebaseAuth.instance;

  firebase_storage.FirebaseStorage get storage =>
      firebase_storage.FirebaseStorage.instance;

  FirebaseFunctions functions({String region = 'us-central1'}) =>
      FirebaseFunctions.instanceFor(region: region);
}
