// lib/services/tenant_firebase_service.dart
//
// Admin-app stub for the kleenops TenantFirebaseService. In the kleenops
// (per-company) app this routes Firestore access through a multi-tenant
// shim. In kleenops_admin everything lives in flat top-level collections,
// so each accessor simply returns the default Firebase project. The class
// is kept so source files that were ported verbatim continue to compile.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart' as firebase_storage;

enum Tenant { byu, external, catalog }

class TenantFirebaseService {
  TenantFirebaseService._();
  static final TenantFirebaseService instance = TenantFirebaseService._();

  // No-op registry hooks.
  void registerByuCompany(String companyId) {}
  void registerByuCompanies(Iterable<String> companyIds) {}
  void setByuCompanies(Iterable<String> companyIds) {}

  Tenant tenantFor(String companyId) => Tenant.byu;
  bool isByuCompany(String companyId) => true;
  bool isExternalCompany(String companyId) => false;

  FirebaseFirestore firestoreFor(String companyId) =>
      FirebaseFirestore.instance;
  FirebaseAuth authFor(String companyId) => FirebaseAuth.instance;
  firebase_storage.FirebaseStorage storageFor(String companyId) =>
      firebase_storage.FirebaseStorage.instance;

  /// In admin, "company doc" maps to a top-level `company/{id}` doc.
  DocumentReference<Map<String, dynamic>> companyDoc(String companyId) =>
      FirebaseFirestore.instance.collection('company').doc(companyId);
}
