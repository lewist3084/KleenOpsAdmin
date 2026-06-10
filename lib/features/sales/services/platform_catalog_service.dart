// lib/features/sales/services/platform_catalog_service.dart
//
// Seeds the top-level `platformProduct` catalog from the canonical
// [kPlatformProductCatalog] and hardwires those products onto companies as
// `company/{id}/service/{productKey}` docs so per-company costs can accrue.
//
// The catalog seed is idempotent and version-gated (a `meta/platformCatalog`
// doc records the seeded version), so it can be safely called every time the
// Products tab opens — it only writes when the catalog version changes.

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../constants/firestore_paths.dart';
import '../data/platform_products_catalog.dart';

class PlatformCatalogService {
  PlatformCatalogService._();
  static final instance = PlatformCatalogService._();

  FirebaseFirestore get _fs => FirebaseFirestore.instance;

  static const _metaDocPath = 'meta';
  static const _metaDocId = 'platformCatalog';

  /// Seed/refresh the `platformProduct` catalog if the stored seed version is
  /// behind [kPlatformCatalogSeedVersion]. Merges (never clobbers) so any
  /// price/label edits an admin made through the dialog survive — except the
  /// structural `group` field, which we always (re)write so grouping is
  /// guaranteed even on previously hand-added docs.
  Future<void> seedCatalogIfNeeded() async {
    final metaRef = _fs.collection(_metaDocPath).doc(_metaDocId);
    final meta = await metaRef.get();
    final seededVersion = (meta.data()?['catalogSeedVersion'] as num?)?.toInt();
    if (seededVersion != null && seededVersion >= kPlatformCatalogSeedVersion) {
      return;
    }

    final batch = _fs.batch();
    final col = _fs.collection('platformProduct');
    for (final product in kPlatformProductCatalog) {
      batch.set(
        col.doc(product.key),
        {
          ...product.toCatalogPayload(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    }
    // Drop catalog docs that earlier seeds created but we've since retired, so
    // they stop lingering under an "Other" group.
    for (final retiredKey in kRetiredPlatformProductKeys) {
      batch.delete(col.doc(retiredKey));
    }
    batch.set(
      metaRef,
      {
        'catalogSeedVersion': kPlatformCatalogSeedVersion,
        'seededAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
    await batch.commit();
  }

  /// Hardwire the catalog onto a single company: writes a `service/{key}` doc
  /// for every active catalog product. Merge-only, so re-running never resets
  /// a service's accrued cost or status once it exists.
  Future<void> provisionCompany(String companyId) async {
    final batch = _fs.batch();
    final servicesCol =
        _fs.collection(colCompany).doc(companyId).collection('service');
    for (final product in kPlatformProductCatalog) {
      if (!product.active) continue;
      // Only CONNECTED products are auto-attached to every company. À-la-carte
      // products (Business Services) reach a company through invoices instead.
      if (!product.hardwired) continue;
      batch.set(
        servicesCol.doc(product.key),
        {
          ...product.toCompanyServicePayload(),
          'companyId': companyId,
          'provisionedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    }
    await batch.commit();
  }

  /// Record that a company has purchased/activated a service. Reads the live
  /// price/label off the `platformProduct` catalog doc, flips the company's
  /// `service/{key}` to active, and writes a `platformPurchase` entry (which
  /// the company detail screen surfaces under "Purchased products").
  ///
  /// This records the company-side cost + activation. It does NOT charge a
  /// card or post platform revenue — that runs server-side through the
  /// metered-billing / setup-provisioning ledger (`recordPlatformSale`).
  Future<void> recordServicePurchase(
    String companyId,
    String productKey,
  ) async {
    final prodSnap =
        await _fs.collection('platformProduct').doc(productKey).get();
    final p = prodSnap.data() ?? const <String, dynamic>{};
    final priceCents = (p['priceCents'] as num?)?.toInt() ?? 0;
    final label = p['label'] as String? ?? productKey;

    final companyDoc = _fs.collection(colCompany).doc(companyId);
    final batch = _fs.batch();
    batch.set(
      companyDoc.collection('service').doc(productKey),
      {
        'status': 'active',
        'priceCents': priceCents,
        'purchasedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
    batch.set(
      companyDoc.collection('platformPurchase').doc(),
      {
        'productKey': productKey,
        'productLabel': label,
        'amountCents': priceCents,
        'status': 'purchased',
        'createdAt': FieldValue.serverTimestamp(),
      },
    );
    await batch.commit();
  }

  /// Backfill: hardwire the catalog onto every existing company. Returns the
  /// number of companies provisioned.
  Future<int> provisionAllCompanies() async {
    final companies = await _fs.collection(colCompany).get();
    for (final company in companies.docs) {
      await provisionCompany(company.id);
    }
    return companies.docs.length;
  }
}
