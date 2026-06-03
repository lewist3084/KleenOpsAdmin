import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kleenops_admin/features/auth/providers/auth_provider.dart';
import 'package:kleenops_admin/features/files/data/drive_model.dart';
import 'package:kleenops_admin/features/files/data/file_model.dart';
import 'package:kleenops_admin/repositories/file_repository.dart';

/// The signed-in member's id, or null before the user doc resolves.
String? _callerMemberId(Ref ref) {
  final userData = ref.watch(userDocumentProvider).maybeWhen(
        data: (d) => d,
        orElse: () => const <String, dynamic>{},
      );
  final m = userData['memberRef'];
  return m is DocumentReference ? m.id : null;
}

// Drives are listed with three scoped queries instead of one unfiltered
// read â€” each returns only docs the caller may read, so they stay valid
// under the per-drive security rules.

final publicDrivesProvider =
    StreamProvider.autoDispose<List<DriveModel>>((ref) {
  final companyRef = ref.watch(companyIdProvider).value;
  if (companyRef == null) return const Stream.empty();
  return ref.read(fileRepositoryProvider).watchPublicDrives(companyRef.id);
});

final personalDrivesProvider =
    StreamProvider.autoDispose<List<DriveModel>>((ref) {
  final companyRef = ref.watch(companyIdProvider).value;
  final memberId = _callerMemberId(ref);
  if (companyRef == null || memberId == null) return const Stream.empty();
  return ref
      .read(fileRepositoryProvider)
      .watchPersonalDrives(companyRef.id, memberId);
});

final sharedDrivesProvider =
    StreamProvider.autoDispose<List<DriveModel>>((ref) {
  final companyRef = ref.watch(companyIdProvider).value;
  final memberId = _callerMemberId(ref);
  if (companyRef == null || memberId == null) return const Stream.empty();
  return ref
      .read(fileRepositoryProvider)
      .watchSharedDrives(companyRef.id, memberId);
});

/// Whether the signed-in member is a "file manager" (`canManageFiles` on their
/// member doc) â€” may delete/move/rename any drive file, browse every drive, and
/// run offboarding cleanup.
final fileManagerProvider = StreamProvider.autoDispose<bool>((ref) {
  final companyRef = ref.watch(companyIdProvider).value;
  final memberId = _callerMemberId(ref);
  if (companyRef == null || memberId == null) {
    return Stream<bool>.value(false);
  }
  return companyRef
      .collection('member')
      .doc(memberId)
      .snapshots()
      .map((s) => (s.data()?['canManageFiles'] as bool?) ?? false);
});

/// Synchronous convenience read of [fileManagerProvider].
final isFileManagerProvider = Provider.autoDispose<bool>((ref) {
  return ref.watch(fileManagerProvider).maybeWhen(
        data: (v) => v,
        orElse: () => false,
      );
});

/// Every personal drive in the company â€” manager-only (the security rules let
/// `canManageFiles` members read any drive). Backs the offboarding "Member
/// drives" section so a manager can open a departed member's My Drive.
final allPersonalDrivesProvider =
    StreamProvider.autoDispose<List<DriveModel>>((ref) {
  final companyRef = ref.watch(companyIdProvider).value;
  if (companyRef == null || !ref.watch(isFileManagerProvider)) {
    return const Stream.empty();
  }
  return companyRef
      .collection('drive')
      .where('type', isEqualTo: 'personal')
      .snapshots()
      .map((s) => s.docs.map(DriveModel.fromSnapshot).toList());
});

/// All drives the current user can access â€” the merge of the three scoped
/// queries above, de-duplicated by id.
final accessibleDrivesProvider =
    Provider.autoDispose<List<DriveModel>>((ref) {
  const empty = <DriveModel>[];
  final personal = ref.watch(personalDrivesProvider).maybeWhen(
        data: (d) => d,
        orElse: () => empty,
      );
  final public = ref.watch(publicDrivesProvider).maybeWhen(
        data: (d) => d,
        orElse: () => empty,
      );
  final shared = ref.watch(sharedDrivesProvider).maybeWhen(
        data: (d) => d,
        orElse: () => empty,
      );

  final byId = <String, DriveModel>{};
  for (final d in [...personal, ...public, ...shared]) {
    byId[d.id] = d;
  }
  return byId.values.toList();
});

/// `driveRef`s of every accessible drive â€” used to scope file queries.
final accessibleDriveRefsProvider = Provider.autoDispose<
    List<DocumentReference<Map<String, dynamic>>>>((ref) {
  return ref.watch(accessibleDrivesProvider).map((d) => d.ref).toList();
});

/// Every file/folder across the drives the user can access. One scoped
/// listener feeds both Recent and search.
final driveItemsProvider =
    StreamProvider.autoDispose<List<FileModel>>((ref) {
  final companyRef = ref.watch(companyIdProvider).value;
  final refs = ref.watch(accessibleDriveRefsProvider);
  if (companyRef == null || refs.isEmpty) {
    return Stream<List<FileModel>>.value(const <FileModel>[]);
  }
  return ref.read(fileRepositoryProvider).watchDriveItems(companyRef.id, refs);
});

/// Recently created files (folders excluded), newest first. Drives the
/// "Recent" row on the Files dashboard.
final recentFilesProvider =
    Provider.autoDispose<AsyncValue<List<FileModel>>>((ref) {
  return ref.watch(driveItemsProvider).whenData((items) {
    final files = items.where((f) => !f.isFolder).toList()
      ..sort((a, b) {
        final at = a.createdAt;
        final bt = b.createdAt;
        if (at == null && bt == null) return 0;
        if (at == null) return 1;
        if (bt == null) return -1;
        return bt.compareTo(at);
      });
    return files;
  });
});

/// Every accessible file and folder â€” backs the global Drive search box.
final driveSearchItemsProvider =
    Provider.autoDispose<AsyncValue<List<FileModel>>>((ref) {
  return ref.watch(driveItemsProvider);
});

