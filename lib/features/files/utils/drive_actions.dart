// Shared file/folder/drive operations used by both the Files dashboard and
// the drive folder browser. Kept here so the screens stay thin and the
// create / upload / rename / move / delete / open flows behave identically
// wherever they are triggered.

import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:url_launcher/url_launcher.dart';

import 'package:kleenops_admin/common/utils/snackbar_service.dart';
import 'package:kleenops_admin/features/auth/providers/auth_provider.dart';
import 'package:kleenops_admin/features/files/data/drive_model.dart';
import 'package:kleenops_admin/features/files/data/file_model.dart';
import 'package:kleenops_admin/features/files/providers/drive_providers.dart';
import 'package:kleenops_admin/features/files/utils/file_kinds.dart';
import 'package:kleenops_admin/repositories/file_repository.dart';
import 'package:kleenops_admin/services/storage_service.dart';
import 'package:shared_widgets/dialogs/dialog_action.dart';
import 'package:shared_widgets/viewers/image_viewer.dart';
import 'package:shared_widgets/viewers/pdf_viewer.dart';

class DriveActions {
  const DriveActions._();

  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ Folder + file creation â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  /// Create a folder inside the current location of [drive].
  static Future<void> createFolder(
    BuildContext context,
    WidgetRef ref, {
    required String companyId,
    required DriveModel drive,
    DocumentReference<Map<String, dynamic>>? parentFolderRef,
    List<String> parentAncestorIds = const [],
  }) async {
    final name = await promptName(
      context,
      title: 'New Folder',
      hint: 'Folder name',
    );
    if (name == null || name.trim().isEmpty) return;
    final repo = ref.read(fileRepositoryProvider);
    final principal = _refs(ref);
    try {
      await repo.createFolder(
        companyId: companyId,
        driveRef: drive.ref,
        name: name.trim(),
        parentFolderRef: parentFolderRef,
        parentAncestorIds: parentAncestorIds,
        createdBy: principal.memberRef,
        userRef: principal.userRef,
      );
    } catch (e) {
      _snack('Failed to create folder: $e');
    }
  }

  /// Pick a file from the device and upload it into the current location of
  /// [drive]. Shows a blocking progress spinner while the upload runs.
  static Future<void> uploadFile(
    BuildContext context,
    WidgetRef ref, {
    required String companyId,
    required DriveModel drive,
    DocumentReference<Map<String, dynamic>>? parentFolderRef,
    List<String> parentAncestorIds = const [],
  }) async {
    // On web request the bytes (no filesystem path); on mobile a path is fine.
    final picked = await FilePicker.platform.pickFiles(withData: kIsWeb);
    if (picked == null || picked.files.isEmpty) return;
    final pf = picked.files.single;
    if (kIsWeb ? pf.bytes == null : pf.path == null) return;
    if (!context.mounted) return;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final repo = ref.read(fileRepositoryProvider);
      final docRef = repo.fileCollection(companyId).doc();
      final ext = p.extension(pf.name);
      final storagePath = 'file/${docRef.id}$ext';
      // Web uses putData(bytes); mobile streams the file with putFile. Avoids
      // the `dart:io` File ops that throw `_Namespace` in the browser.
      final downloadUrl = kIsWeb
          ? await StorageService().uploadData(pf.bytes!, storagePath)
          : await StorageService().uploadFile(File(pf.path!), storagePath);
      final principal = _refs(ref);
      await repo.createFile(
        companyId: companyId,
        driveRef: drive.ref,
        name: pf.name,
        storagePath: storagePath,
        downloadUrl: downloadUrl,
        parentFolderRef: parentFolderRef,
        parentAncestorIds: parentAncestorIds,
        sourceFileName: pf.name,
        sizeBytes: pf.size,
        createdBy: principal.memberRef,
        userRef: principal.userRef,
        newDocId: docRef.id,
      );
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      _snack('Upload failed: $e');
      return;
    }
    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();
    }
  }

  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ Per-item menu â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  /// Bottom sheet of actions for a file or folder.
  static Future<void> showItemMenu(
    BuildContext context,
    WidgetRef ref, {
    required String companyId,
    required DriveModel drive,
    required FileModel item,
  }) async {
    // File managers can move a file out to a different drive (the offboarding /
    // cleanup path); everyone else only sees same-drive folder moves.
    final canReassign = ref.read(isFileManagerProvider);
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!item.isFolder)
              ListTile(
                leading: const Icon(Icons.open_in_new),
                title: const Text('Open'),
                onTap: () => Navigator.pop(context, 'open'),
              ),
            ListTile(
              leading: const Icon(Icons.drive_file_rename_outline),
              title: const Text('Rename'),
              onTap: () => Navigator.pop(context, 'rename'),
            ),
            ListTile(
              leading: const Icon(Icons.drive_file_move_outline),
              title: const Text('Move'),
              onTap: () => Navigator.pop(context, 'move'),
            ),
            if (canReassign)
              ListTile(
                leading: const Icon(Icons.swap_horiz),
                title: const Text('Move to another driveâ€¦'),
                onTap: () => Navigator.pop(context, 'reassign'),
              ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Delete'),
              onTap: () => Navigator.pop(context, 'delete'),
            ),
          ],
        ),
      ),
    );
    if (choice == null || !context.mounted) return;

    switch (choice) {
      case 'open':
        await openFile(context, item);
        break;
      case 'rename':
        await rename(context, ref, item);
        break;
      case 'move':
        await move(context, ref, companyId: companyId, drive: drive, item: item);
        break;
      case 'reassign':
        await reassignDrive(context, ref, currentDrive: drive, item: item);
        break;
      case 'delete':
        await confirmDelete(context, ref, item);
        break;
    }
  }

  /// Trash-view menu for a soft-deleted item: Restore or permanently Purge.
  static Future<void> showTrashItemMenu(
    BuildContext context,
    WidgetRef ref, {
    required FileModel item,
  }) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.restore_from_trash_outlined),
              title: const Text('Restore'),
              onTap: () => Navigator.pop(context, 'restore'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_forever_outlined),
              title: const Text('Delete forever'),
              onTap: () => Navigator.pop(context, 'purge'),
            ),
          ],
        ),
      ),
    );
    if (choice == null || !context.mounted) return;
    if (choice == 'restore') {
      await restore(ref, item);
    } else if (choice == 'purge') {
      await confirmPurge(context, ref, item);
    }
  }

  /// Restore a trashed item back into its drive.
  static Future<void> restore(WidgetRef ref, FileModel item) async {
    try {
      await ref.read(fileRepositoryProvider).restore(item.ref);
      _snack('Restored "${item.name}".');
    } catch (e) {
      _snack('Restore failed: $e');
    }
  }

  /// Permanently delete a trashed item (no undo).
  static Future<void> confirmPurge(
    BuildContext context,
    WidgetRef ref,
    FileModel item,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => DialogAction(
        title: 'Delete forever?',
        content: Text(
          'Permanently delete "${item.name}". This cannot be undone.',
        ),
        cancelText: 'Cancel',
        onCancel: () => Navigator.of(ctx).pop(false),
        actionText: 'Delete forever',
        onAction: () => Navigator.of(ctx).pop(true),
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(fileRepositoryProvider).hardDelete(item.ref);
    } catch (e) {
      _snack('Delete failed: $e');
    }
  }

  /// Move an item to a DIFFERENT drive (manager-only offboarding / cleanup).
  /// Picking a member's personal drive transfers ownership to that member;
  /// picking the Company Drive / a shared drive just relocates the file.
  static Future<void> reassignDrive(
    BuildContext context,
    WidgetRef ref, {
    required DriveModel currentDrive,
    required FileModel item,
  }) async {
    final companyRef = ref.read(companyIdProvider).value;
    if (companyRef == null) return;

    // Candidate targets: everything the manager can see, minus the current
    // drive and the caller's-only personal duplicates.
    final byId = <String, DriveModel>{};
    for (final d in [
      ...ref.read(accessibleDrivesProvider),
      ...ref.read(allPersonalDrivesProvider).maybeWhen(
            data: (v) => v,
            orElse: () => const <DriveModel>[],
          ),
    ]) {
      if (d.id != currentDrive.id) byId[d.id] = d;
    }
    final targets = byId.values.toList()
      ..sort((a, b) {
        int rank(DriveModel d) => d.isCompanyDrive
            ? 0
            : d.type == DriveType.shared
                ? 1
                : 2;
        final r = rank(a).compareTo(rank(b));
        return r != 0
            ? r
            : a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
    if (targets.isEmpty) {
      _snack('No other drive to move to.');
      return;
    }

    final target = await showModalBottomSheet<DriveModel>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ReassignDriveSheet(drives: targets),
    );
    if (target == null) return;

    // Moving into a personal drive transfers ownership to its member.
    DocumentReference<Map<String, dynamic>>? newOwner;
    if (target.type == DriveType.personal && target.ownerMemberId != null) {
      newOwner =
          companyRef.collection('member').doc(target.ownerMemberId!);
    }
    try {
      await ref.read(fileRepositoryProvider).reassignToDrive(
            ref: item.ref,
            newDriveRef: target.ref,
            newOwnerMemberRef: newOwner,
          );
      _snack('Moved "${item.name}" to ${target.name}.');
    } catch (e) {
      _snack('Move failed: $e');
    }
  }

  static Future<void> rename(
    BuildContext context,
    WidgetRef ref,
    FileModel item,
  ) async {
    final name = await promptName(
      context,
      title: item.isFolder ? 'Rename Folder' : 'Rename File',
      hint: 'New name',
      initial: item.name,
    );
    if (name == null || name.trim().isEmpty || name.trim() == item.name) return;
    try {
      await ref.read(fileRepositoryProvider).rename(item.ref, name.trim());
    } catch (e) {
      _snack('Rename failed: $e');
    }
  }

  static Future<void> confirmDelete(
    BuildContext context,
    WidgetRef ref,
    FileModel item,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => DialogAction(
        title: item.isFolder ? 'Delete folder?' : 'Delete file?',
        content: Text(
          item.isFolder
              ? 'Move "${item.name}" to the trash. Items inside it stay '
                  'until they are deleted too.'
              : 'Move "${item.name}" to the trash.',
        ),
        cancelText: 'Cancel',
        onCancel: () => Navigator.of(ctx).pop(false),
        actionText: 'Delete',
        onAction: () => Navigator.of(ctx).pop(true),
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(fileRepositoryProvider).softDelete(item.ref);
    } catch (e) {
      _snack('Delete failed: $e');
    }
  }

  /// Move [item] to another folder within the same drive (or its root).
  static Future<void> move(
    BuildContext context,
    WidgetRef ref, {
    required String companyId,
    required DriveModel drive,
    required FileModel item,
  }) async {
    final repo = ref.read(fileRepositoryProvider);
    List<FileModel> folders;
    try {
      folders = await repo.fetchDriveFolders(
        companyId: companyId,
        driveRef: drive.ref,
      );
    } catch (e) {
      _snack('Could not load folders: $e');
      return;
    }
    if (!context.mounted) return;

    // A folder cannot be moved into itself or any of its descendants.
    final blocked = <String>{item.id};
    if (item.isFolder) {
      for (final f in folders) {
        if (f.ancestorIds.contains(item.id)) blocked.add(f.id);
      }
    }
    final targets = folders.where((f) => !blocked.contains(f.id)).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    final selection = await showModalBottomSheet<(bool, FileModel?)>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _MoveTargetSheet(driveName: drive.name, folders: targets),
    );
    if (selection == null || !context.mounted) return;

    final target = selection.$2;
    try {
      await repo.moveItem(
        ref: item.ref,
        newParentFolderRef: target?.ref,
        newParentAncestorIds: target == null ? const [] : target.ancestorIds,
      );
      _snack('Moved "${item.name}".');
    } catch (e) {
      _snack('Move failed: $e');
    }
  }

  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ Open / preview â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  /// Open a file: PDFs and images preview in-app, everything else opens in the
  /// device's default handler.
  static Future<void> openFile(BuildContext context, FileModel file) async {
    final url = file.downloadUrl;
    if (url == null || url.isEmpty) {
      _snack('This file has no content to open.');
      return;
    }
    final kind = fileKindOf(file);
    if (kind == FileKind.pdf) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => PdfViewer(pdfUrl: url)),
      );
      return;
    }
    if (kind == FileKind.image) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => Scaffold(
            backgroundColor: Colors.black,
            appBar: AppBar(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              title: Text(file.name),
            ),
            body: ImageViewer(imageUrl: url),
          ),
        ),
      );
      return;
    }
    final uri = Uri.tryParse(url);
    if (uri == null || !await canLaunchUrl(uri)) {
      _snack('Could not open "${file.name}".');
      return;
    }
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ Drives â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  /// Create a new shared drive. Returns the new [DriveModel], or null if the
  /// user cancelled or creation failed.
  static Future<DriveModel?> createSharedDrive(
    BuildContext context,
    WidgetRef ref, {
    required String companyId,
  }) async {
    final name = await promptName(
      context,
      title: 'New Drive',
      hint: 'e.g. HR, Operations, Marketing',
    );
    if (name == null || name.trim().isEmpty) return null;
    final principal = _refs(ref);
    final memberIds =
        principal.memberRef == null ? <String>[] : [principal.memberRef!.id];
    try {
      final driveRef =
          await ref.read(fileRepositoryProvider).createSharedDrive(
                companyId: companyId,
                name: name.trim(),
                memberIds: memberIds,
                createdBy: principal.userRef,
              );
      return DriveModel(
        id: driveRef.id,
        ref: driveRef,
        type: DriveType.shared,
        name: name.trim(),
        memberIds: memberIds,
      );
    } catch (e) {
      _snack('Failed to create drive: $e');
      return null;
    }
  }

  static Future<void> renameDrive(
    BuildContext context,
    WidgetRef ref,
    DriveModel drive,
  ) async {
    if (drive.isSystem) {
      _snack('System drives cannot be renamed.');
      return;
    }
    final name = await promptName(
      context,
      title: 'Rename Drive',
      hint: 'Drive name',
      initial: drive.name,
    );
    if (name == null || name.trim().isEmpty || name.trim() == drive.name) {
      return;
    }
    try {
      await ref.read(fileRepositoryProvider).renameDrive(drive.ref, name.trim());
    } catch (e) {
      _snack('Rename failed: $e');
    }
  }

  /// Delete a (non-system, empty) drive. Returns true if it was deleted.
  static Future<bool> confirmDeleteDrive(
    BuildContext context,
    WidgetRef ref, {
    required String companyId,
    required DriveModel drive,
  }) async {
    if (drive.isSystem) {
      _snack('My Drive and the Company Drive cannot be deleted.');
      return false;
    }
    final repo = ref.read(fileRepositoryProvider);
    final hasItems = await repo.driveHasItems(
      companyId: companyId,
      driveRef: drive.ref,
    );
    if (!context.mounted) return false;
    if (hasItems) {
      _snack('Empty "${drive.name}" before deleting it.');
      return false;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => DialogAction(
        title: 'Delete drive?',
        content: Text('Delete the empty drive "${drive.name}".'),
        cancelText: 'Cancel',
        onCancel: () => Navigator.of(ctx).pop(false),
        actionText: 'Delete',
        onAction: () => Navigator.of(ctx).pop(true),
      ),
    );
    if (confirmed != true) return false;
    try {
      await repo.deleteDrive(drive.ref);
      return true;
    } catch (e) {
      _snack('Delete failed: $e');
      return false;
    }
  }

  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ Helpers â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  static Future<String?> promptName(
    BuildContext context, {
    required String title,
    required String hint,
    String? initial,
  }) {
    final controller = TextEditingController(text: initial ?? '');
    return showDialog<String>(
      context: context,
      builder: (ctx) => DialogAction(
        title: title,
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(hintText: hint),
          onSubmitted: (v) => Navigator.of(ctx).pop(v),
          textInputAction: TextInputAction.done,
          onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
        ),
        cancelText: 'Cancel',
        actionText: 'OK',
        onCancel: () => Navigator.of(ctx).pop(),
        onAction: () => Navigator.of(ctx).pop(controller.text),
      ),
    );
  }

  static ({
    DocumentReference<Map<String, dynamic>>? memberRef,
    DocumentReference<Map<String, dynamic>>? userRef,
  }) _refs(WidgetRef ref) {
    final userData = ref.read(userDocumentProvider).maybeWhen(
          data: (d) => d,
          orElse: () => const <String, dynamic>{},
        );
    return (
      memberRef: _asMapRef(userData['memberRef']),
      userRef: ref.read(userDocRefProvider),
    );
  }

  static DocumentReference<Map<String, dynamic>>? _asMapRef(dynamic value) {
    if (value is DocumentReference<Map<String, dynamic>>) return value;
    if (value is DocumentReference) {
      return value.withConverter<Map<String, dynamic>>(
        fromFirestore: (snap, _) => snap.data() ?? <String, dynamic>{},
        toFirestore: (data, _) => data,
      );
    }
    return null;
  }

  static void _snack(String message) {
    SnackbarService.instance.showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 4),
        content: Text(message),
      ),
    );
  }
}

/// Bottom sheet listing target drives for a cross-drive reassign. Company Drive
/// first, then shared, then members' personal drives. Pops the chosen
/// [DriveModel].
class _ReassignDriveSheet extends StatelessWidget {
  const _ReassignDriveSheet({required this.drives});

  final List<DriveModel> drives;

  IconData _icon(DriveModel d) {
    if (d.isCompanyDrive) return Icons.business_rounded;
    switch (d.type) {
      case DriveType.personal:
        return Icons.person_rounded;
      case DriveType.shared:
        return Icons.group_rounded;
      case DriveType.public:
        return Icons.public_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.6,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Move to another drive',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                ),
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final d in drives)
                    ListTile(
                      leading: Icon(_icon(d)),
                      title: Text(d.name),
                      subtitle: Text(
                        d.type == DriveType.personal
                            ? 'Transfers ownership to this member'
                            : d.typeLabel,
                      ),
                      onTap: () => Navigator.pop(context, d),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet that lists every folder in a drive (indented by depth) plus a
/// "Drive root" option. Pops `(true, folder)` â€” a null folder means the root.
class _MoveTargetSheet extends StatelessWidget {
  const _MoveTargetSheet({required this.driveName, required this.folders});

  final String driveName;
  final List<FileModel> folders;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.6,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Move to',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                ),
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  ListTile(
                    leading: const Icon(Icons.home_outlined),
                    title: Text('$driveName (root)'),
                    onTap: () => Navigator.pop(context, (true, null)),
                  ),
                  for (final f in folders)
                    ListTile(
                      contentPadding: EdgeInsets.only(
                        left: 16.0 + 20.0 * f.ancestorIds.length,
                        right: 16,
                      ),
                      leading: const Icon(Icons.folder_outlined),
                      title: Text(f.name),
                      onTap: () => Navigator.pop(context, (true, f)),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

