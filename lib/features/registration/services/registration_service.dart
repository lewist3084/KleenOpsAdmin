// lib/features/registration/services/registration_service.dart
//
// Creates the overlord entity in the `kleenops` collection along with
// the initial member document and memberByUid index for the current user.
//
// Used by the registration flow when a brand-new admin user signs in
// and chooses either "Internal Use" or "Cleaning Services Business".

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../constants/firestore_paths.dart';

class RegistrationService {
  RegistrationService._();
  static final instance = RegistrationService._();

  FirebaseFirestore get _fs => FirebaseFirestore.instance;
  FirebaseAuth get _auth => FirebaseAuth.instance;

  /// Creates a new kleenops overlord entity.
  ///
  /// - Internal use: pass [propertyTypeRef] (picked from the global
  ///   `propertyType` catalog) OR [propertyTypeName] for a custom value
  ///   the user typed in.
  /// - Cleaning services: passes [businessType] = 'cleaningServices'
  ///
  /// Returns the new kleenops doc reference.
  Future<DocumentReference<Map<String, dynamic>>> createKleenopsEntity({
    required String name,
    required String businessType, // 'internalUse' | 'cleaningServices'
    DocumentReference<Map<String, dynamic>>? propertyTypeRef,
    String? propertyTypeName,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('Cannot create kleenops entity: not authenticated');
    }

    final kleenopsRef = _fs.collection(colKleenops).doc();
    final memberRef = kleenopsRef.collection(colMember).doc();
    final memberByUidRef =
        kleenopsRef.collection(colMemberByUid).doc(user.uid);

    final now = FieldValue.serverTimestamp();

    final batch = _fs.batch();

    batch.set(kleenopsRef, {
      'name': name,
      'businessType': businessType,
      if (propertyTypeRef != null) 'propertyTypeId': propertyTypeRef,
      if (propertyTypeName != null && propertyTypeName.isNotEmpty)
        'propertyTypeName': propertyTypeName,
      'active': true,
      'createdAt': now,
      'updatedAt': now,
      'createdByUid': user.uid,
    });

    batch.set(memberRef, {
      'uid': user.uid,
      'name': user.displayName ?? user.email ?? 'Owner',
      'email': user.email,
      'role': 'owner',
      'active': true,
      'createdAt': now,
    });

    batch.set(memberByUidRef, {
      'uid': user.uid,
      'memberId': memberRef.id,
      'active': true,
      'createdAt': now,
    });

    // Attach kleenops doc reference to the user record so that downstream
    // providers can resolve it without an extra query.
    final userRef = _fs.collection(colUser).doc(user.uid);
    batch.set(
      userRef,
      {
        'kleenopsId': kleenopsRef,
        'updatedAt': now,
      },
      SetOptions(merge: true),
    );

    await batch.commit();

    /* Refresh ID token so any custom claims pick up. */
    await user.getIdToken(true);

    /* Silently seed example data from the matching template. We do not
       block the caller on failure — they can still proceed into the
       fresh entity, just without seed data. */
    try {
      await FirebaseFunctions.instance
          .httpsCallable('seedKleenopsFromTemplate')
          .call({
        'kleenopsId': kleenopsRef.id,
        'businessType': businessType,
      });
    } catch (_) {
      // Intentionally swallowed — seeding is best-effort.
    }

    return kleenopsRef;
  }

  /// Backfills `businessType` / `propertyTypeId` / `propertyTypeName` on
  /// an existing kleenops doc owned by the signed-in user. Used by the
  /// post-sign-in onboarding gate that catches owners whose entity
  /// pre-dates the fork-style registration flow. Only the owner
  /// (kleenops.ownerUid or kleenops.createdByUid) may call this.
  Future<void> updateKleenopsProfile({
    required String kleenopsId,
    required String businessType, // 'internalUse' | 'cleaningServices'
    DocumentReference<Map<String, dynamic>>? propertyTypeRef,
    String? propertyTypeName,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('Cannot update kleenops entity: not authenticated');
    }
    final kleenopsRef = _fs.collection(colKleenops).doc(kleenopsId);
    final snap = await kleenopsRef.get();
    if (!snap.exists) {
      throw StateError('kleenops entity not found');
    }
    final data = snap.data() ?? <String, dynamic>{};
    final ownerUid = data['ownerUid'];
    final createdByUid = data['createdByUid'];
    final isOwner = (ownerUid is String && ownerUid == user.uid) ||
        (createdByUid is String && createdByUid == user.uid);
    if (!isOwner) {
      throw StateError(
          'Only the kleenops owner may update the registration profile');
    }

    final updates = <String, dynamic>{
      'businessType': businessType,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (propertyTypeRef != null) {
      updates['propertyTypeId'] = propertyTypeRef;
      updates['propertyTypeName'] = FieldValue.delete();
    } else if (propertyTypeName != null && propertyTypeName.isNotEmpty) {
      updates['propertyTypeName'] = propertyTypeName;
      updates['propertyTypeId'] = FieldValue.delete();
    }
    await kleenopsRef.set(updates, SetOptions(merge: true));
  }

  /// Stream of available property types from the global `propertyType`
  /// collection. Used by the internal-use setup form.
  Stream<QuerySnapshot<Map<String, dynamic>>> propertyTypesStream() {
    return _fs.collection('propertyType').snapshots();
  }
}
