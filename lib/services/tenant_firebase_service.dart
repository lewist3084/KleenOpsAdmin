// lib/services/tenant_firebase_service.dart
//
// Tenant-aware Firebase routing service.
// Routes Firestore/Storage/Auth calls to the appropriate Firebase project
// based on company affiliation.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart' as firebase_storage;
import 'package:flutter/foundation.dart' show debugPrint, kReleaseMode;

import 'catalog_firebase_service.dart';
import 'external_firebase_service.dart';

/// Identifies which Firebase project/tenant a company belongs to.
enum Tenant {
  /// Your company (BYU) - uses the default kleenops Firebase project.
  byu,

  /// External companies - uses the external Firebase project.
  external,

  /// Marketplace catalog - uses the default kleenops project.
  catalog,
}

/// Service for routing Firebase operations to the correct project based on tenant.
///
/// This enables a single codebase to serve multiple Firebase projects:
/// - BYU companies → kleenops (default Firebase app)
/// - External companies → cleanops-external
/// - Catalog/marketplace → kleenops (same as default)
///
/// ## Usage
///
/// ```dart
/// // Get Firestore for a specific company
/// final firestore = TenantFirebaseService.instance.firestoreFor(companyId);
/// await firestore.collection('company').doc(companyId).get();
///
/// // Check which tenant a company belongs to
/// final tenant = TenantFirebaseService.instance.tenantFor(companyId);
///
/// // Get storage for file uploads
/// final storage = TenantFirebaseService.instance.storageFor(companyId);
/// ```
///
/// ## Migration Pattern
///
/// Replace direct `FirebaseFirestore.instance` calls with tenant-aware calls:
///
/// ```dart
/// // BEFORE (hardcoded to default project)
/// FirebaseFirestore.instance.collection('company').doc(companyId)
///
/// // AFTER (routes to correct project)
/// TenantFirebaseService.instance.firestoreFor(companyId).collection('company').doc(companyId)
/// ```
class TenantFirebaseService {
  TenantFirebaseService._();
  static final TenantFirebaseService instance = TenantFirebaseService._();

  // ─────────────────────────────────────────────────────────────────────────
  // CONFIGURATION: Add your BYU company IDs here
  // ─────────────────────────────────────────────────────────────────────────

  /// Set of company IDs that belong to BYU (your company).
  ///
  /// All companies in this set will route to the default kleenops project.
  /// Companies NOT in this set will route to the external project.
  ///
  /// TODO: Add your BYU company IDs here.
  static final Set<String> _byuCompanyIds = <String>{
    // Example:
    // 'abc123-your-company-id',
    // 'xyz789-another-byu-company',
  };

  /// Adds a company ID to the BYU tenant list at runtime.
  ///
  /// Useful for dynamic configuration from a remote config or Firestore doc.
  void registerByuCompany(String companyId) {
    _byuCompanyIds.add(companyId);
    _debugLog('[Tenant] Registered BYU company: $companyId');
  }

  /// Registers multiple BYU company IDs at once.
  void registerByuCompanies(Iterable<String> companyIds) {
    _byuCompanyIds.addAll(companyIds);
    _debugLog('[Tenant] Registered ${companyIds.length} BYU companies');
  }

  /// Clears and replaces all BYU company IDs.
  ///
  /// Call this after fetching the authoritative list from your backend.
  void setByuCompanies(Iterable<String> companyIds) {
    _byuCompanyIds
      ..clear()
      ..addAll(companyIds);
    _debugLog('[Tenant] Set ${companyIds.length} BYU companies');
  }

  // ─────────────────────────────────────────────────────────────────────────
  // TENANT RESOLUTION
  // ─────────────────────────────────────────────────────────────────────────

  /// Determines which tenant a company belongs to.
  ///
  /// Returns [Tenant.byu] if the company ID is in [_byuCompanyIds],
  /// otherwise returns [Tenant.external].
  Tenant tenantFor(String companyId) {
    if (_byuCompanyIds.contains(companyId)) {
      return Tenant.byu;
    }
    return Tenant.external;
  }

  /// Whether the given company belongs to BYU (your company).
  bool isByuCompany(String companyId) => tenantFor(companyId) == Tenant.byu;

  /// Whether the given company is an external tenant.
  bool isExternalCompany(String companyId) =>
      tenantFor(companyId) == Tenant.external;

  // ─────────────────────────────────────────────────────────────────────────
  // FIRESTORE ACCESS
  // ─────────────────────────────────────────────────────────────────────────

  /// Returns the Firestore instance for the given company's tenant.
  ///
  /// - BYU companies → default Firestore (kleenops)
  /// - External companies → external Firestore (cleanops-external)
  FirebaseFirestore firestoreFor(String companyId) {
    return firestoreForTenant(tenantFor(companyId));
  }

  /// Returns the Firestore instance for a specific tenant.
  FirebaseFirestore firestoreForTenant(Tenant tenant) {
    switch (tenant) {
      case Tenant.byu:
        return FirebaseFirestore.instance;
      case Tenant.external:
        return ExternalFirebaseService.instance.firestore;
      case Tenant.catalog:
        return CatalogFirebaseService.instance.firestore;
    }
  }

  /// Convenience getter for the default (BYU) Firestore.
  FirebaseFirestore get byuFirestore => FirebaseFirestore.instance;

  /// Convenience getter for the external companies Firestore.
  FirebaseFirestore get externalFirestore =>
      ExternalFirebaseService.instance.firestore;

  /// Convenience getter for the catalog Firestore.
  FirebaseFirestore get catalogFirestore =>
      CatalogFirebaseService.instance.firestore;

  // ─────────────────────────────────────────────────────────────────────────
  // STORAGE ACCESS
  // ─────────────────────────────────────────────────────────────────────────

  /// Returns the Storage instance for the given company's tenant.
  firebase_storage.FirebaseStorage storageFor(String companyId) {
    return storageForTenant(tenantFor(companyId));
  }

  /// Returns the Storage instance for a specific tenant.
  firebase_storage.FirebaseStorage storageForTenant(Tenant tenant) {
    switch (tenant) {
      case Tenant.byu:
        return firebase_storage.FirebaseStorage.instance;
      case Tenant.external:
        return ExternalFirebaseService.instance.storage;
      case Tenant.catalog:
        return CatalogFirebaseService.instance.storage;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // AUTH ACCESS
  // ─────────────────────────────────────────────────────────────────────────

  /// Returns the primary Auth instance (shared across all tenants).
  ///
  /// For most use cases, you'll use shared authentication where users
  /// authenticate once via the main app and access other projects' Firestore
  /// using the same identity.
  FirebaseAuth get auth => FirebaseAuth.instance;

  /// Returns the Auth instance for a specific tenant.
  ///
  /// Use this only if you need separate authentication per project.
  /// Most apps should use the shared [auth] getter instead.
  FirebaseAuth authForTenant(Tenant tenant) {
    switch (tenant) {
      case Tenant.byu:
        return FirebaseAuth.instance;
      case Tenant.external:
        return ExternalFirebaseService.instance.auth;
      case Tenant.catalog:
        return CatalogFirebaseService.instance.auth;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // COLLECTION HELPERS
  // ─────────────────────────────────────────────────────────────────────────

  /// Gets a company document reference routed to the correct project.
  DocumentReference<Map<String, dynamic>> companyDoc(String companyId) {
    return firestoreFor(companyId).collection('company').doc(companyId);
  }

  /// Gets a collection reference under a company, routed to the correct project.
  CollectionReference<Map<String, dynamic>> companyCollection(
    String companyId,
    String collectionPath,
  ) {
    return companyDoc(companyId).collection(collectionPath);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // DEBUGGING
  // ─────────────────────────────────────────────────────────────────────────

  void _debugLog(String message) {
    if (!kReleaseMode) {
      debugPrint(message);
    }
  }

  /// Prints current tenant configuration (debug builds only).
  void debugPrintConfig() {
    if (!kReleaseMode) {
      debugPrint('[Tenant] Configuration:');
      debugPrint('[Tenant]   BYU companies: ${_byuCompanyIds.length}');
      for (final id in _byuCompanyIds) {
        debugPrint('[Tenant]     - $id');
      }
    }
  }
}
