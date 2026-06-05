import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kleenops_admin/features/auth/providers/auth_provider.dart';
import 'package:kleenops_admin/features/notes/data/folder_model.dart';
import 'package:kleenops_admin/features/notes/data/content_model.dart';

/// Stream of top-level folders (no parent) owned by the current member.
final topLevelFoldersProvider =
    StreamProvider.autoDispose<List<FolderModel>>((ref) {
  final companyAsync = ref.watch(companyIdProvider);
  final userAsync = ref.watch(userDocumentProvider);

  final companyRef = companyAsync.value;
  final userData = userAsync.value;
  if (companyRef == null || userData == null) return const Stream.empty();

  final memberRef =
      userData['memberRef'] as DocumentReference<Map<String, dynamic>>?;
  if (memberRef == null) return const Stream.empty();

  return companyRef
      .collection('folder')
      .where('memberId', isEqualTo: memberRef.id)
      .where('parentFolderRef', isNull: true)
      .orderBy('position')
      .snapshots()
      .map((snap) =>
          snap.docs.map((d) => FolderModel.fromSnapshot(d)).toList());
});

/// Stream of child folders for a given parent folder reference.
final childFoldersProvider = StreamProvider.autoDispose
    .family<List<FolderModel>, DocumentReference<Map<String, dynamic>>>(
  (ref, parentRef) {
    final companyAsync = ref.watch(companyIdProvider);
    final companyRef = companyAsync.value;
    if (companyRef == null) return const Stream.empty();

    return companyRef
        .collection('folder')
        .where('parentFolderRef', isEqualTo: parentRef)
        .orderBy('position')
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => FolderModel.fromSnapshot(d)).toList());
  },
);

/// Stream of content docs for a given folder, ordered by position.
final folderContentProvider = StreamProvider.autoDispose
    .family<List<ContentModel>, DocumentReference<Map<String, dynamic>>>(
  (ref, folderRef) {
    final companyAsync = ref.watch(companyIdProvider);
    final companyRef = companyAsync.value;
    if (companyRef == null) return const Stream.empty();

    return companyRef
        .collection('content')
        .where('folderRef', isEqualTo: folderRef)
        .orderBy('position')
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => ContentModel.fromSnapshot(d)).toList());
  },
);
