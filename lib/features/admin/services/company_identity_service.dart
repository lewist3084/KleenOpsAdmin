// company_identity_service.dart
//
// Resolves the overlord company document for the signed-in admin (mirroring
// `companyIdProvider`) and owns small "business identity" side effects that the
// setup wizard triggers but can't easily reach through Riverpod — most notably
// auto-generating the company tagline when the business name is entered.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:kleenops_admin/constants/firestore_paths.dart';
import 'package:kleenops_admin/services/firebase_ai/gemini_tagline_service.dart';

class CompanyIdentityService {
  CompanyIdentityService._();
  static final instance = CompanyIdentityService._();

  /// Resolves the overlord company document for the signed-in user, mirroring
  /// the resolution in `companyIdProvider`. Returns null if unresolved.
  Future<DocumentReference<Map<String, dynamic>>?> resolveCompanyRef() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;

    final q = await FirebaseFirestore.instance
        .collectionGroup('memberByUid')
        .where('uid', isEqualTo: uid)
        .get();
    if (q.docs.isEmpty) return null;

    // Prefer the active match under the `kleenops` collection.
    QueryDocumentSnapshot<Map<String, dynamic>>? pick;
    for (final d in q.docs) {
      if (d.data()['active'] == true &&
          d.reference.parent.parent?.parent.id == colKleenops) {
        pick = d;
        break;
      }
    }
    // Fall back to any active membership.
    pick ??= q.docs
        .cast<QueryDocumentSnapshot<Map<String, dynamic>>?>()
        .firstWhere((d) => d!.data()['active'] == true, orElse: () => null);

    return pick?.reference.parent.parent;
  }

  /// Auto-generates and saves a company tagline when one isn't already set.
  /// Safe to call repeatedly — it won't overwrite an existing tagline unless
  /// [force] is true. All failures are swallowed so onboarding is never
  /// blocked by AI/network issues.
  Future<void> ensureAutoTagline({
    required String businessName,
    bool force = false,
    GeminiTaglineService? taglineService,
  }) async {
    try {
      final companyRef = await resolveCompanyRef();
      if (companyRef == null) return;

      final snap = await companyRef.get();
      final data = snap.data() ?? <String, dynamic>{};
      final existing = (data['tagline'] as String? ?? '').trim();
      if (existing.isNotEmpty && !force) return;

      final tagline =
          await (taglineService ?? GeminiTaglineService()).generateTagline(
        businessName: businessName,
        businessType: data['businessType'] as String?,
      );
      if (tagline.isEmpty) return;

      await companyRef.update({'tagline': tagline});
    } catch (_) {
      // Non-fatal: onboarding continues without an auto-generated tagline.
    }
  }
}
