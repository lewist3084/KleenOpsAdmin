// lib/repositories/task_repository.dart
//
// Minimal admin port: the calling subsystem (VideoCallService / VideoChatPanel)
// only needs these three tenant-company path helpers from the kleenops
// TaskRepository. The full task data layer is not part of the admin app, so
// this stub exposes just `companyDoc`, `memberDoc`, and `memberByUidDoc` plus
// the `taskRepositoryProvider` the calling code reads.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class TaskRepository {
  TaskRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> companyDoc(String companyId) =>
      _firestore.collection('company').doc(companyId);

  DocumentReference<Map<String, dynamic>> memberDoc(
          String companyId, String memberId) =>
      companyDoc(companyId).collection('member').doc(memberId);

  /// Per-company index keyed by auth uid. Resolves uid → member doc without a
  /// collection-group query.
  DocumentReference<Map<String, dynamic>> memberByUidDoc(
          String companyId, String uid) =>
      companyDoc(companyId).collection('memberByUid').doc(uid);
}

final taskRepositoryProvider = Provider<TaskRepository>((ref) {
  return TaskRepository();
});
