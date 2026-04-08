// lib/features/auth/providers/auth_provider.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../constants/firestore_paths.dart';

/// Stream of Firebase Auth state changes.
final authStateChangesProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

/// Whether the current user is authenticated.
final isAuthenticatedProvider = Provider<bool>((ref) {
  final authAsync = ref.watch(authStateChangesProvider);
  return authAsync.maybeWhen(data: (user) => user != null, orElse: () => false);
});

/// Current user UID (null if not authenticated).
final currentUidProvider = Provider<String?>((ref) {
  final authAsync = ref.watch(authStateChangesProvider);
  return authAsync.maybeWhen(data: (user) => user?.uid, orElse: () => null);
});

/// ───────────── user document ─────────────
final userDocumentProvider = StreamProvider.autoDispose<Map<String, dynamic>>(
  (ref) {
    final user = ref.watch(authStateChangesProvider).value;
    if (user == null) throw Exception('User not logged-in');
    final uid = user.uid;

    final userRef = FirebaseFirestore.instance.collection('user').doc(uid);

    final userStream = userRef.snapshots().handleError((e, _) {
      if (e is FirebaseException && e.code == 'permission-denied') {
        // swallow to allow retry
      } else {
        throw e;
      }
    });

    return userStream.asyncExpand((uSnap) {
      if (!uSnap.exists) {
        return Stream.error(Exception('User document missing'));
      }
      final base = uSnap.data()!;

      final memberIndexQuery = FirebaseFirestore.instance
          .collectionGroup('memberByUid')
          .where('uid', isEqualTo: uid)
          .snapshots(includeMetadataChanges: true)
          .handleError((e, _) {});

      return memberIndexQuery.asyncExpand((mSnap) {
        if (mSnap.docs.isEmpty) {
          return Stream.value(base);
        }

        // Prefer the match under the kleenops collection.
        final indexDoc = mSnap.docs.cast<QueryDocumentSnapshot<Map<String, dynamic>>?>().firstWhere(
              (d) =>
                  d!.data()['active'] == true &&
                  d.reference.parent.parent?.parent.id == colKleenops,
              orElse: () => null,
            ) ??
            mSnap.docs.first;
        final indexData = indexDoc.data();
        if (indexData['active'] != true) {
          return Stream.value(base);
        }
        final memberId = indexData['memberId'] as String?;
        if (memberId == null || memberId.isEmpty) {
          return Stream.value(base);
        }

        final companyRef = indexDoc.reference.parent.parent!
            .withConverter<Map<String, dynamic>>(
          fromFirestore: (s, _) => s.data()!,
          toFirestore: (m, _) => m,
        );
        final memberRef = companyRef.collection('member').doc(memberId)
            .withConverter<Map<String, dynamic>>(
          fromFirestore: (s, _) => s.data()!,
          toFirestore: (m, _) => m,
        );

        final memberStream = memberRef.snapshots().handleError((e, _) {
          if (e is FirebaseException && e.code == 'permission-denied') {
            // swallow
          } else {
            throw e;
          }
        });

        return memberStream.map((memberSnap) {
          if (!memberSnap.exists) {
            return base;
          }
          final memberData = memberSnap.data()!;
          return {
            ...base,
            ...memberData,
            'memberRef': memberRef,
            'companyId': companyRef,
          };
        });
      });
    });
  },
);

/// ───────────── companyId (DocumentReference?) ─────────────
/// Resolves to the overlord entity under the `kleenops` collection.
/// Falls back to any active memberByUid if no kleenops match is found.
final companyIdProvider =
    StreamProvider.autoDispose<DocumentReference<Map<String, dynamic>>?>(
  (ref) {
    final user = ref.watch(authStateChangesProvider).value;
    if (user == null) {
      return Stream.value(null)
          .cast<DocumentReference<Map<String, dynamic>>?>();
    }

    final uid = user.uid;

    return FirebaseFirestore.instance
        .collectionGroup('memberByUid')
        .where('uid', isEqualTo: uid)
        .snapshots(includeMetadataChanges: true)
        .map((q) {
      if (q.docs.isEmpty) return null;

      // Prefer the match under the kleenops collection.
      final kleenopsDoc = q.docs.cast<QueryDocumentSnapshot<Map<String, dynamic>>?>().firstWhere(
        (d) =>
            d!.data()['active'] == true &&
            d.reference.parent.parent?.parent.id == colKleenops,
        orElse: () => null,
      );

      final indexDoc = kleenopsDoc ??
          q.docs.cast<QueryDocumentSnapshot<Map<String, dynamic>>?>().firstWhere(
            (d) => d!.data()['active'] == true,
            orElse: () => null,
          );

      if (indexDoc == null) return null;

      final comp = indexDoc.reference.parent.parent!;
      return comp.withConverter<Map<String, dynamic>>(
        fromFirestore: (s, _) => s.data()!,
        toFirestore: (m, _) => m,
      );
    });
  },
);

/// User document reference (e.g. /user/{uid}).
final userDocRefProvider =
    Provider<DocumentReference<Map<String, dynamic>>?>((ref) {
  final user = ref.watch(authStateChangesProvider).value;
  if (user == null) return null;
  return FirebaseFirestore.instance
      .collection('user')
      .doc(user.uid)
      .withConverter<Map<String, dynamic>>(
        fromFirestore: (s, _) => s.data()!,
        toFirestore: (m, _) => m,
      );
});

/// ───────────── kleenops profile gate ─────────────
/// Snapshot of whether the signed-in user is the kleenops-entity owner
/// and whether their kleenops doc is missing the registration metadata
/// (`businessType` + `propertyType*`). The router redirect uses this
/// to send owners with incomplete entities back through the
/// registration fork screens to backfill the missing fields.
class KleenopsProfileGate {
  const KleenopsProfileGate({
    required this.isOwner,
    required this.profileComplete,
    required this.kleenopsId,
    required this.businessType,
  });

  /// True when the signed-in user owns the kleenops entity (member.role
  /// == 'owner', kleenops.ownerUid == auth.uid, or kleenops.createdByUid
  /// == auth.uid for legacy entities).
  final bool isOwner;

  /// True when the kleenops doc has both `businessType` and a property
  /// type (either `propertyTypeId` ref or non-empty `propertyTypeName`).
  final bool profileComplete;

  /// The kleenops doc id (if known).
  final String? kleenopsId;

  /// Existing businessType on the kleenops doc, or null. Lets the
  /// redirect jump straight to the matching property-type form.
  final String? businessType;

  static const empty = KleenopsProfileGate(
    isOwner: false,
    profileComplete: true,
    kleenopsId: null,
    businessType: null,
  );
}

final kleenopsProfileGateProvider =
    StreamProvider.autoDispose<KleenopsProfileGate>((ref) {
  final user = ref.watch(authStateChangesProvider).value;
  if (user == null) return Stream.value(KleenopsProfileGate.empty);

  final uid = user.uid;
  return FirebaseFirestore.instance
      .collectionGroup('memberByUid')
      .where('uid', isEqualTo: uid)
      .snapshots(includeMetadataChanges: true)
      .asyncExpand((q) {
    if (q.docs.isEmpty) return Stream.value(KleenopsProfileGate.empty);

    // Only consider memberships under the kleenops collection.
    final indexDoc = q.docs
        .cast<QueryDocumentSnapshot<Map<String, dynamic>>?>()
        .firstWhere(
          (d) =>
              d!.data()['active'] == true &&
              d.reference.parent.parent?.parent.id == colKleenops,
          orElse: () => null,
        );
    if (indexDoc == null) return Stream.value(KleenopsProfileGate.empty);

    final indexData = indexDoc.data();
    final indexRole = (indexData['role'] as String?)?.toLowerCase();
    final kleenopsRef = indexDoc.reference.parent.parent!;
    return kleenopsRef.snapshots().map((snap) {
      if (!snap.exists) return KleenopsProfileGate.empty;
      final data = snap.data() ?? <String, dynamic>{};
      final ownerUid = data['ownerUid'];
      final createdByUid = data['createdByUid'];
      final isOwner = indexRole == 'owner' ||
          indexRole == 'admin' ||
          (ownerUid is String && ownerUid == uid) ||
          (createdByUid is String && createdByUid == uid);
      final businessType = data['businessType'] as String?;
      final hasBusinessType =
          businessType != null && businessType.trim().isNotEmpty;
      final propertyTypeId = data['propertyTypeId'];
      final propertyTypeName = data['propertyTypeName'] as String?;
      final hasPropertyType = propertyTypeId is DocumentReference ||
          (propertyTypeName != null && propertyTypeName.trim().isNotEmpty);
      return KleenopsProfileGate(
        isOwner: isOwner,
        profileComplete: hasBusinessType && hasPropertyType,
        kleenopsId: kleenopsRef.id,
        businessType: hasBusinessType ? businessType : null,
      );
    });
  }).distinct((a, b) =>
      a.isOwner == b.isOwner &&
      a.profileComplete == b.profileComplete &&
      a.kleenopsId == b.kleenopsId &&
      a.businessType == b.businessType);
});

/// Active member document reference for the current user (if any).
final memberDocRefProvider =
    StreamProvider.autoDispose<DocumentReference<Map<String, dynamic>>?>(
  (ref) {
    final user = ref.watch(authStateChangesProvider).value;
    if (user == null) {
      return Stream.value(null)
          .cast<DocumentReference<Map<String, dynamic>>?>();
    }

    final uid = user.uid;

    return FirebaseFirestore.instance
        .collectionGroup('memberByUid')
        .where('uid', isEqualTo: uid)
        .snapshots(includeMetadataChanges: true)
        .map((q) {
          if (q.docs.isEmpty) return null;

          // Prefer the match under the kleenops collection.
          final indexDoc = q.docs.cast<QueryDocumentSnapshot<Map<String, dynamic>>?>().firstWhere(
                (d) =>
                    d!.data()['active'] == true &&
                    d.reference.parent.parent?.parent.id == colKleenops,
                orElse: () => null,
              ) ??
              q.docs.first;
          final indexData = indexDoc.data();
          if (indexData['active'] != true) return null;
          final memberId = indexData['memberId'] as String?;
          if (memberId == null || memberId.isEmpty) return null;
          final companyRef = indexDoc.reference.parent.parent!;
          return companyRef.collection('member').doc(memberId)
              .withConverter<Map<String, dynamic>>(
            fromFirestore: (s, _) => s.data()!,
            toFirestore: (m, _) => m,
          );
        });
  },
);
