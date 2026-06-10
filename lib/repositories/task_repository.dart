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

  // ───────────────────── Timeline helpers (admin: TOP-LEVEL) ─────────────
  //
  // The admin app is the cross-company SaaS overlord, so its task data is
  // global. `tasks_timeline_provider.dart` reads the top-level `timeline`
  // collection (ignoring companyId); these write/reference helpers mirror that
  // so swipe-complete punch-outs land where the list reads them. The
  // `companyId` arg is kept for API parity with the kleenops UI code.

  CollectionReference<Map<String, dynamic>> timelineCollection(
          String companyId) =>
      _firestore.collection('timeline');

  DocumentReference<Map<String, dynamic>> timelineDoc(
          String companyId, String taskId) =>
      timelineCollection(companyId).doc(taskId);

  /// Create a fresh timeline document reference with a generated ID.
  DocumentReference<Map<String, dynamic>> newTimelineDoc(String companyId) =>
      timelineCollection(companyId).doc();

  CollectionReference<Map<String, dynamic>> objectProcessTaskCollection(
          String companyId) =>
      _firestore.collection('objectProcessTask');

  /// Top-level shared collection of task/timeline category definitions.
  CollectionReference<Map<String, dynamic>> timelineCategoryCollection() =>
      _firestore.collection('timelineCategory');

  DocumentReference<Map<String, dynamic>> timelineCategoryDoc(
          String categoryId) =>
      timelineCategoryCollection().doc(categoryId);

  /// Produce a typed `DocumentReference<Map<String, dynamic>>` from an
  /// arbitrary path. Useful when widgets receive an untyped DocumentReference
  /// and need a typed one.
  DocumentReference<Map<String, dynamic>> docFromPath(String path) =>
      _firestore.doc(path).withConverter<Map<String, dynamic>>(
            fromFirestore: (snap, _) => snap.data() ?? <String, dynamic>{},
            toFirestore: (value, _) => value,
          );

  /// Generate a unique Firestore ID without creating a real document.
  String newId() => _firestore.collection('_ids').doc().id;

  /// Wraps `FirebaseFirestore.batch()` so all batch writes in the tasks feature
  /// can be observed/mocked in one place.
  WriteBatch batch() => _firestore.batch();
}

final taskRepositoryProvider = Provider<TaskRepository>((ref) {
  return TaskRepository();
});
