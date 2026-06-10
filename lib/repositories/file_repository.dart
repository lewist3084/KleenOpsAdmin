// lib/repositories/file_repository.dart
//
// File + Drive access for the admin (overlord) file system. Owns:
//
//   kleenops/{id}/drive/{driveId}         (access boundary â€” personal/shared/public)
//   kleenops/{id}/file/{fileId}           (files AND folders; folders have isFolder:true)
//
// The overlord's own org lives under the top-level `kleenops` collection — NOT
// under `company/` — so these collections are overlord-scoped, never nested in
// a company doc.
//
// The legacy flat file collection (without driveRef) is left in place until
// the migration script runs â€” see migration notes below.
//
// â”€â”€â”€ proposed Firestore rules â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
//
// The existing generic rule at `match /company/{companyId}/{subcollection}`
// already permits all company members to read/write every subcollection
// including `drive` and `file`. To enforce drive-level access server-side,
// these subcollections need to be carved out of the generic match and
// granted their own rules. Drop-in sketch:
//
//   function getDrive(companyId, driveId) {
//     return get(/databases/$(database)/documents/company/$(companyId)/drive/$(driveId)).data;
//   }
//   function memberId(companyId) {
//     // memberByUid/{uid} maps the auth uid â†’ memberId
//     return get(/databases/$(database)/documents/company/$(companyId)/memberByUid/$(request.auth.uid)).data.memberId;
//   }
//   function userTeamIds(companyId) {
//     // teamAccess on the member doc; cached field, normalize to ids.
//     return get(/databases/$(database)/documents/company/$(companyId)/member/$(memberId(companyId))).data.teamAccess;
//   }
//   function canAccessDrive(d, companyId) {
//     return d.type == 'public'
//         || (d.type == 'personal' && d.ownerMemberId == memberId(companyId))
//         || (d.type == 'shared' && (
//              memberId(companyId) in d.memberIds
//              || d.teamIds.hasAny(userTeamIds(companyId))
//            ));
//   }
//
//   match /company/{companyId}/drive/{driveId} {
//     allow read:   if isCompanyMember(companyId) && canAccessDrive(resource.data, companyId);
//     allow create: if isCompanyMember(companyId)
//                   && request.resource.data.type in ['shared','public'];   // personal created via repo path with admin claim or callable
//     allow update, delete: if isCompanyMember(companyId)
//                   && canAccessDrive(resource.data, companyId);
//   }
//
//   match /company/{companyId}/file/{fileId} {
//     allow read:   if isCompanyMember(companyId)
//                   && canAccessDrive(getDrive(companyId, resource.data.driveRef.id), companyId);
//     allow write:  if isCompanyMember(companyId)
//                   && canAccessDrive(getDrive(companyId, request.resource.data.driveRef.id), companyId);
//   }
//
// Cost note: each rule evaluation does up to 2 cross-doc `get()`s (drive +
// member). Firestore caches `get()` results within a single rules evaluation,
// so a `list` query over many files still costs O(driveCount + 1) reads, not
// O(fileCount). For "simple teams" this is fine. If drive listings get hot,
// denormalize a `driveAccessSnapshot` map onto each file via a Cloud Function
// trigger and check that field instead â€” eliminates the cross-doc reads.
//
// Adding these requires REMOVING `drive` and `file` from the catch-all
// `match /company/{companyId}/{subcollection}/{docId}` block, or the generic
// allow will still grant access.
//
// â”€â”€â”€ migration notes â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
//
// Existing docs in `company/{id}/file/` have no `driveRef` and live in a
// flat collection with the legacy `publicInternal` / `teamAccess` /
// `createdBy` flags. One-off migration steps:
//
//   1. Create one "Company Documents" public drive per company.
//   2. For each legacy file doc:
//        - If `publicInternal == true`: assign driveRef = public drive.
//        - Else if `createdBy` is set: assign to that member's personal
//          drive (ensure-create if missing).
//        - Else: assign to the public drive as a fallback.
//      Backfill `isFolder: false`, `parentFolderRef: null`, `ancestorIds: []`.
//   3. Keep the legacy flags on docs for one release as a fallback; the
//      DrivesScreen ignores them. The old FilesScreen continues to work
//      against the same collection.
//
// Recommended runner: a Cloud Function callable invoked from the admin app,
// per-company. Sketch lives in `functions/scripts/` â€” not built yet.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kleenops_admin/features/files/data/drive_model.dart';
import 'package:kleenops_admin/features/files/data/file_model.dart';

class FileRepository {
  FileRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ Refs â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  // Admin (overlord) scope: the admin app's own org lives under the top-level
  // `kleenops` collection, NOT under `company/`. `companyId` here is the
  // overlord doc id (from `companyIdProvider`, which resolves `kleenops/{id}`),
  // so drives/files land at `kleenops/{id}/drive` and `kleenops/{id}/file`.
  DocumentReference<Map<String, dynamic>> companyDoc(String companyId) =>
      _firestore.collection('kleenops').doc(companyId);

  CollectionReference<Map<String, dynamic>> driveCollection(String companyId) =>
      companyDoc(companyId).collection('drive');

  DocumentReference<Map<String, dynamic>> driveDoc(
          String companyId, String driveId) =>
      driveCollection(companyId).doc(driveId);

  CollectionReference<Map<String, dynamic>> fileCollection(String companyId) =>
      companyDoc(companyId).collection('file');

  DocumentReference<Map<String, dynamic>> fileDoc(
          String companyId, String fileId) =>
      fileCollection(companyId).doc(fileId);

  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ Drive queries â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  // Drive listing is split into three scoped queries â€” public, the caller's
  // own personal drive, and shared drives the caller belongs to. Each query
  // returns only docs the caller is allowed to read, so it stays valid once
  // the per-drive security rules are enforced. (A single unfiltered
  // `orderBy('name')` query would try to read everyone's personal drives and
  // fail.) Callers merge the three and sort client-side.

  /// Public drives â€” every company member can access these.
  Stream<List<DriveModel>> watchPublicDrives(String companyId) {
    return driveCollection(companyId)
        .where('type', isEqualTo: 'public')
        .snapshots()
        .map((s) => s.docs.map(DriveModel.fromSnapshot).toList());
  }

  /// The caller's own personal drive(s) â€” normally exactly one.
  Stream<List<DriveModel>> watchPersonalDrives(
    String companyId,
    String memberId,
  ) {
    return driveCollection(companyId)
        .where('type', isEqualTo: 'personal')
        .where('ownerMemberId', isEqualTo: memberId)
        .snapshots()
        .map((s) => s.docs.map(DriveModel.fromSnapshot).toList());
  }

  /// Shared drives the caller is a member of.
  Stream<List<DriveModel>> watchSharedDrives(
    String companyId,
    String memberId,
  ) {
    return driveCollection(companyId)
        .where('memberIds', arrayContains: memberId)
        .snapshots()
        .map((s) => s.docs.map(DriveModel.fromSnapshot).toList());
  }

  /// Stream the personal drive for `memberId` in `companyId`. Auto-creates the
  /// drive doc on first call if missing.
  Future<DriveModel> ensurePersonalDrive({
    required String companyId,
    required String memberId,
    required String displayName,
    DocumentReference<Map<String, dynamic>>? createdBy,
  }) async {
    final query = await driveCollection(companyId)
        .where('type', isEqualTo: 'personal')
        .where('ownerMemberId', isEqualTo: memberId)
        .limit(1)
        .get();

    if (query.docs.isNotEmpty) {
      return DriveModel.fromSnapshot(query.docs.first);
    }

    final ref = driveCollection(companyId).doc();
    final model = DriveModel(
      id: ref.id,
      ref: ref,
      type: DriveType.personal,
      name: '$displayName â€” My Drive',
      description: 'Your private files. Only you can see what you keep here.',
      ownerMemberId: memberId,
      createdBy: createdBy,
    );
    await ref.set(model.toCreateMap());
    final snap = await ref.get();
    return DriveModel.fromSnapshot(snap);
  }

  /// Ensure the company-wide public drive ("Company Drive") exists. Exactly
  /// one per company, flagged `isCompanyDrive: true`. Auto-creates on first
  /// call. Every company member can read and write it.
  Future<DriveModel> ensureCompanyDrive({
    required String companyId,
    DocumentReference<Map<String, dynamic>>? createdBy,
  }) async {
    final query = await driveCollection(companyId)
        .where('isCompanyDrive', isEqualTo: true)
        .limit(1)
        .get();

    if (query.docs.isNotEmpty) {
      return DriveModel.fromSnapshot(query.docs.first);
    }

    final ref = driveCollection(companyId).doc();
    final model = DriveModel(
      id: ref.id,
      ref: ref,
      type: DriveType.public,
      name: 'Company Drive',
      description:
          'Files shared across the whole company. Everyone can view and add.',
      isCompanyDrive: true,
      createdBy: createdBy,
    );
    await ref.set(model.toCreateMap());
    final snap = await ref.get();
    return DriveModel.fromSnapshot(snap);
  }

  Future<DocumentReference<Map<String, dynamic>>> createSharedDrive({
    required String companyId,
    required String name,
    String? description,
    List<String> memberIds = const [],
    List<String> teamIds = const [],
    DocumentReference<Map<String, dynamic>>? createdBy,
  }) async {
    final ref = driveCollection(companyId).doc();
    final model = DriveModel(
      id: ref.id,
      ref: ref,
      type: DriveType.shared,
      name: name,
      description: description,
      memberIds: memberIds,
      teamIds: teamIds,
      createdBy: createdBy,
    );
    await ref.set(model.toCreateMap());
    return ref;
  }

  Future<void> updateDriveAccess({
    required DocumentReference<Map<String, dynamic>> driveRef,
    List<String>? memberIds,
    List<String>? teamIds,
  }) {
    final patch = <String, dynamic>{};
    if (memberIds != null) patch['memberIds'] = memberIds;
    if (teamIds != null) patch['teamIds'] = teamIds;
    if (patch.isEmpty) return Future.value();
    return driveRef.update(patch);
  }

  Future<void> renameDrive(
    DocumentReference<Map<String, dynamic>> driveRef,
    String newName,
  ) {
    return driveRef.update({'name': newName});
  }

  /// Update a drive's editable details (name and/or description). Passing only
  /// the fields that changed keeps system-drive names untouched while still
  /// letting their description be edited.
  Future<void> updateDriveDetails(
    DocumentReference<Map<String, dynamic>> driveRef, {
    String? name,
    String? description,
  }) {
    final patch = <String, dynamic>{};
    if (name != null) patch['name'] = name;
    if (description != null) patch['description'] = description;
    if (patch.isEmpty) return Future.value();
    return driveRef.update(patch);
  }

  /// Hard-delete a drive doc. Callers must guard: only non-system drives with
  /// no remaining files/folders should be passed here.
  Future<void> deleteDrive(DocumentReference<Map<String, dynamic>> driveRef) {
    return driveRef.delete();
  }

  /// True if the drive has at least one non-deleted file or folder.
  Future<bool> driveHasItems({
    required String companyId,
    required DocumentReference<Map<String, dynamic>> driveRef,
  }) async {
    final snap = await fileCollection(companyId)
        .where('driveRef', isEqualTo: driveRef)
        .limit(20)
        .get();
    return snap.docs
        .map(FileModel.fromSnapshot)
        .any((f) => f.deletedAt == null);
  }

  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ File / folder queries â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  /// Files (and folders) directly inside `parentFolderRef` of `driveRef`.
  /// Pass `parentFolderRef = null` for the drive root.
  Stream<List<FileModel>> watchFolderContents({
    required String companyId,
    required DocumentReference<Map<String, dynamic>> driveRef,
    DocumentReference<Map<String, dynamic>>? parentFolderRef,
  }) {
    Query<Map<String, dynamic>> q = fileCollection(companyId)
        .where('driveRef', isEqualTo: driveRef)
        .where('parentFolderRef', isEqualTo: parentFolderRef);
    return q.snapshots().map((s) {
      final items = s.docs
          .map(FileModel.fromSnapshot)
          .where((f) => f.deletedAt == null)
          .toList();
      items.sort((a, b) {
        // Folders first, then by name.
        if (a.isFolder != b.isFolder) return a.isFolder ? -1 : 1;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
      return items;
    });
  }

  /// Every non-deleted file and folder inside [driveRefs] â€” the caller's
  /// accessible drives. Backs both the Recent row and global search; callers
  /// sort/filter client-side. Scoped by `driveRef` so the query only reads
  /// docs the caller is allowed to see (Firestore `whereIn` caps at 30).
  Stream<List<FileModel>> watchDriveItems(
    String companyId,
    List<DocumentReference<Map<String, dynamic>>> driveRefs,
  ) {
    if (driveRefs.isEmpty) {
      return Stream<List<FileModel>>.value(const <FileModel>[]);
    }
    final refs =
        driveRefs.length > 30 ? driveRefs.sublist(0, 30) : driveRefs;
    return fileCollection(companyId)
        .where('driveRef', whereIn: refs)
        .snapshots()
        .map((s) => s.docs
            .map(FileModel.fromSnapshot)
            .where((f) => f.deletedAt == null)
            .toList());
  }

  /// All folders in a single drive (one-shot). Used by the move-item picker.
  Future<List<FileModel>> fetchDriveFolders({
    required String companyId,
    required DocumentReference<Map<String, dynamic>> driveRef,
  }) async {
    final snap = await fileCollection(companyId)
        .where('driveRef', isEqualTo: driveRef)
        .get();
    return snap.docs
        .map(FileModel.fromSnapshot)
        .where((f) => f.isFolder && f.deletedAt == null)
        .toList();
  }

  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ Folder writes â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Future<DocumentReference<Map<String, dynamic>>> createFolder({
    required String companyId,
    required DocumentReference<Map<String, dynamic>> driveRef,
    required String name,
    DocumentReference<Map<String, dynamic>>? parentFolderRef,
    List<String> parentAncestorIds = const [],
    DocumentReference<Map<String, dynamic>>? createdBy,
    DocumentReference<Map<String, dynamic>>? userRef,
  }) async {
    final ref = fileCollection(companyId).doc();
    final ancestorIds = [
      ...parentAncestorIds,
      if (parentFolderRef != null) parentFolderRef.id,
    ];
    await ref.set({
      'name': name,
      'isFolder': true,
      'driveRef': driveRef,
      'parentFolderRef': parentFolderRef,
      'ancestorIds': ancestorIds,
      'createdAt': FieldValue.serverTimestamp(),
      if (createdBy != null) 'createdBy': createdBy,
      if (userRef != null) 'userRef': userRef,
    });
    return ref;
  }

  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ File writes â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  /// Create a new file doc for an uploaded blob. Caller is responsible for
  /// uploading to Firebase Storage and providing the download URL.
  Future<DocumentReference<Map<String, dynamic>>> createFile({
    required String companyId,
    required DocumentReference<Map<String, dynamic>> driveRef,
    required String name,
    required String storagePath,
    required String downloadUrl,
    DocumentReference<Map<String, dynamic>>? parentFolderRef,
    List<String> parentAncestorIds = const [],
    String? description,
    String? sourceFileName,
    int? sizeBytes,
    DocumentReference<Map<String, dynamic>>? createdBy,
    DocumentReference<Map<String, dynamic>>? userRef,
    String? newDocId,
  }) async {
    final ref = newDocId == null
        ? fileCollection(companyId).doc()
        : fileCollection(companyId).doc(newDocId);
    final ancestorIds = [
      ...parentAncestorIds,
      if (parentFolderRef != null) parentFolderRef.id,
    ];
    await ref.set({
      'name': name,
      'isFolder': false,
      'driveRef': driveRef,
      'parentFolderRef': parentFolderRef,
      'ancestorIds': ancestorIds,
      'storagePath': storagePath,
      'downloadUrl': downloadUrl,
      'firestorePath': ref.path,
      if (description != null && description.isNotEmpty)
        'description': description,
      if (sourceFileName != null) 'sourceFileName': sourceFileName,
      if (sizeBytes != null) 'sizeBytes': sizeBytes,
      'createdAt': FieldValue.serverTimestamp(),
      if (createdBy != null) 'createdBy': createdBy,
      if (userRef != null) 'userRef': userRef,
    });
    return ref;
  }

  /// Soft-delete a file or empty folder. Caller should check folder is empty
  /// before calling for `isFolder:true` docs.
  Future<void> softDelete(DocumentReference<Map<String, dynamic>> ref) {
    return ref.update({'deletedAt': FieldValue.serverTimestamp()});
  }

  /// Restore a soft-deleted item back into its drive (clears `deletedAt`).
  Future<void> restore(DocumentReference<Map<String, dynamic>> ref) {
    return ref.update({'deletedAt': FieldValue.delete()});
  }

  /// Permanently remove a file/folder doc (Trash "purge"). The Storage blob is
  /// left for a separate sweep â€” Firestore rules can't reach into Storage.
  Future<void> hardDelete(DocumentReference<Map<String, dynamic>> ref) {
    return ref.delete();
  }

  /// Trashed (soft-deleted) files/folders in a drive â€” backs the Trash view.
  /// Queries by `driveRef` (rule-safe) and keeps only tombstoned docs.
  Stream<List<FileModel>> watchTrashedItems({
    required String companyId,
    required DocumentReference<Map<String, dynamic>> driveRef,
  }) {
    return fileCollection(companyId)
        .where('driveRef', isEqualTo: driveRef)
        .snapshots()
        .map((s) {
      final items = s.docs
          .map(FileModel.fromSnapshot)
          .where((f) => f.deletedAt != null)
          .toList();
      items.sort((a, b) {
        final at = a.deletedAt;
        final bt = b.deletedAt;
        if (at == null && bt == null) return 0;
        if (at == null) return 1;
        if (bt == null) return -1;
        return bt.compareTo(at); // most-recently-trashed first
      });
      return items;
    });
  }

  /// Move an item to a DIFFERENT drive (offboarding cleanup). Lands it at the
  /// target drive's root and optionally transfers ownership to a new member /
  /// user. Unlike [moveItem] this rewrites `driveRef`; only a file manager is
  /// allowed to do it by the security rules.
  Future<void> reassignToDrive({
    required DocumentReference<Map<String, dynamic>> ref,
    required DocumentReference<Map<String, dynamic>> newDriveRef,
    DocumentReference<Map<String, dynamic>>? newOwnerMemberRef,
    DocumentReference<Map<String, dynamic>>? newOwnerUserRef,
  }) {
    return ref.update({
      'driveRef': newDriveRef,
      'parentFolderRef': null,
      'ancestorIds': <String>[],
      if (newOwnerMemberRef != null) 'createdBy': newOwnerMemberRef,
      if (newOwnerUserRef != null) 'userRef': newOwnerUserRef,
    });
  }

  /// Move an item (file or folder) to a new parent folder within the SAME
  /// drive. Cross-drive moves are deliberately not supported in v1 â€” they
  /// would require permission re-validation and ancestor rewrites on every
  /// descendant.
  Future<void> moveItem({
    required DocumentReference<Map<String, dynamic>> ref,
    required DocumentReference<Map<String, dynamic>>? newParentFolderRef,
    required List<String> newParentAncestorIds,
  }) {
    final ancestorIds = [
      ...newParentAncestorIds,
      if (newParentFolderRef != null) newParentFolderRef.id,
    ];
    return ref.update({
      'parentFolderRef': newParentFolderRef,
      'ancestorIds': ancestorIds,
    });
  }

  Future<void> rename(
    DocumentReference<Map<String, dynamic>> ref,
    String newName,
  ) {
    return ref.update({'name': newName});
  }
}

final fileRepositoryProvider = Provider<FileRepository>((ref) {
  return FileRepository();
});

