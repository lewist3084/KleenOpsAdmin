// lib/features/auth/providers/auth_provider.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
          .limit(1)
          .snapshots(includeMetadataChanges: true)
          .handleError((e, _) {});

      return memberIndexQuery.asyncExpand((mSnap) {
        if (mSnap.docs.isEmpty) {
          return Stream.value(base);
        }

        final indexDoc = mSnap.docs.first;
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
        .limit(1)
        .snapshots(includeMetadataChanges: true)
        .map((q) {
      if (q.docs.isEmpty) return null;
      final indexDoc = q.docs.first;
      if (indexDoc.data()['active'] != true) return null;
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
        .limit(1)
        .snapshots(includeMetadataChanges: true)
        .map((q) {
          if (q.docs.isEmpty) return null;
          final indexDoc = q.docs.first;
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
