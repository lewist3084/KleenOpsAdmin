// lib/repositories/user_repository.dart
//
// Owns access to the top-level `user/{uid}` collection and the
// cross-company `memberByUid` index. Most features need one or both:
// - `user/{uid}` carries per-user profile data (name, timezone, clockedIn, …)
// - `collectionGroup('memberByUid')` is how a signed-in `uid` is mapped back
//   to a company + member.
//
// Consumers should depend on `userRepositoryProvider` rather than reaching
// into `FirebaseFirestore.instance` or `FirebaseAuth.instance` directly.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class UserRepository {
  UserRepository({FirebaseFirestore? firestore, FirebaseAuth? auth})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  // ─────────────── Auth conveniences ───────────────

  /// Returns the signed-in uid, or `null` if nobody is signed in.
  String? currentUid() => _auth.currentUser?.uid;

  // ─────────────── user/{uid} ───────────────

  CollectionReference<Map<String, dynamic>> userCollection() =>
      _firestore.collection('user');

  DocumentReference<Map<String, dynamic>> userDoc(String uid) =>
      userCollection().doc(uid);

  /// Convenience for the current user's doc. Returns `null` if not signed in.
  DocumentReference<Map<String, dynamic>>? currentUserDoc() {
    final uid = currentUid();
    return uid == null ? null : userDoc(uid);
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchUser(String uid) =>
      userDoc(uid).snapshots();

  // ─────────────── memberByUid index ───────────────

  /// Cross-company collection-group lookup for a `uid`. Use `.limit(1)` and
  /// `.get()` when you just need to resolve which company a user belongs to.
  Query<Map<String, dynamic>> memberByUidGroup(String uid) => _firestore
      .collectionGroup('memberByUid')
      .where('uid', isEqualTo: uid);

  /// Per-company variant (uses a doc keyed by uid under
  /// `company/{id}/memberByUid/{uid}`). Returned as-is untyped so callers that
  /// expect to read `{memberId, active}` keep working.
  DocumentReference<Map<String, dynamic>> memberByUidInCompany(
          DocumentReference<Map<String, dynamic>> companyRef, String uid) =>
      companyRef.collection('memberByUid').doc(uid);

  // ─────────────── Utility ───────────────

  /// Produce a typed `DocumentReference<Map<String, dynamic>>` from an
  /// arbitrary path. Matches the helper on the Task / Employee repositories.
  DocumentReference<Map<String, dynamic>> docFromPath(String path) =>
      _firestore.doc(path).withConverter<Map<String, dynamic>>(
            fromFirestore: (snap, _) => snap.data() ?? <String, dynamic>{},
            toFirestore: (value, _) => value,
          );
}

final userRepositoryProvider = Provider<UserRepository>((ref) {
  return UserRepository();
});
