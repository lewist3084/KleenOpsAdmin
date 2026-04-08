// lib/features/registration/providers/registration_provider.dart
//
// Tracks whether the current user has an active membership inside the
// `kleenops` collection. If not, the router redirects them through the
// registration flow.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../constants/firestore_paths.dart';
import '../../auth/providers/auth_provider.dart';

/// Stream of `bool` indicating whether the current user still needs to
/// register/join a kleenops overlord entity.
///
/// - `true`  → no active memberByUid under `kleenops/{docId}`
/// - `false` → user has an active membership and can use the app
/// - `null`  → still loading
final needsRegistrationProvider = StreamProvider.autoDispose<bool?>((ref) {
  final user = ref.watch(authStateChangesProvider).value;
  if (user == null) {
    return Stream.value(null);
  }

  return FirebaseFirestore.instance
      .collectionGroup('memberByUid')
      .where('uid', isEqualTo: user.uid)
      .snapshots(includeMetadataChanges: true)
      .map<bool?>((snap) {
    if (snap.docs.isEmpty) return true;

    // Look for an active membership under the kleenops collection.
    final hasKleenopsMembership = snap.docs.any((d) {
      final data = d.data();
      final isActive = data['active'] == true;
      final parentCollection = d.reference.parent.parent?.parent.id;
      return isActive && parentCollection == colKleenops;
    });

    return !hasKleenopsMembership;
  });
});
