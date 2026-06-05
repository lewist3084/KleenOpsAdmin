// Picker + upload flows that produce a [TextMessageAttachment] for the text
// composer. Three of the four flows (Photo, Video, Document) push the picked
// bytes into the sender's My Drive under an auto-created "Texted attachments"
// folder, so every shared file is discoverable later from the Files section.
// The fourth (From my files) reuses an existing drive file's downloadUrl with
// no re-upload.
//
// All picker results are kept as cross-platform [XFile]s and uploaded through
// [StorageService.uploadXFile], which uses `putData` (bytes) on web and
// `putFile` on mobile. This avoids the `dart:io` File operations that throw
// `Unsupported operation: _Namespace` in the browser.

import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart' as fp;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;

import 'package:kleenops_admin/common/utils/snackbar_service.dart';
import 'package:kleenops_admin/features/auth/providers/auth_provider.dart';
import 'package:kleenops_admin/features/files/data/file_model.dart';
import 'package:kleenops_admin/features/files/utils/file_kinds.dart';
import 'package:kleenops_admin/repositories/file_repository.dart';
import 'package:kleenops_admin/services/storage_service.dart';

import '../models/text_message.dart';
import '../screens/drive_file_picker_sheet.dart';

class TextAttachmentActions {
  const TextAttachmentActions._();

  static const String _textedFolderName = 'Texted attachments';

  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ Photo â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  static Future<TextMessageAttachment?> pickPhoto(
    BuildContext context,
    WidgetRef ref, {
    required String companyId,
    required DocumentReference<Map<String, dynamic>> memberRef,
    required String memberName,
  }) async {
    final source = await _pickImageSource(context);
    if (source == null || !context.mounted) return null;

    final file = await StorageService().pickAndCompressImageX(source);
    if (file == null || !context.mounted) return null;

    return _uploadAndRecord(
      context,
      ref,
      companyId: companyId,
      memberRef: memberRef,
      memberName: memberName,
      localFile: file,
      originalFileName: _xfileName(file, fallbackExt: '.jpg'),
      type: TextMessageAttachmentType.image,
    );
  }

  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ Video â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  static Future<TextMessageAttachment?> pickVideo(
    BuildContext context,
    WidgetRef ref, {
    required String companyId,
    required DocumentReference<Map<String, dynamic>> memberRef,
    required String memberName,
  }) async {
    final source = await _pickImageSource(context);
    if (source == null || !context.mounted) return null;

    final picked = await ImagePicker().pickVideo(source: source);
    if (picked == null || !context.mounted) return null;

    return _uploadAndRecord(
      context,
      ref,
      companyId: companyId,
      memberRef: memberRef,
      memberName: memberName,
      localFile: picked,
      originalFileName: _xfileName(picked, fallbackExt: '.mp4'),
      // On mobile StorageService.uploadVideo compresses to mp4 â€” force the
      // extension so the file doc + storage path reflect the output bytes. On
      // web there is no compression, so keep the original extension.
      storageExtensionOverride: kIsWeb ? null : '.mp4',
      type: TextMessageAttachmentType.video,
    );
  }

  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ Document â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  static Future<TextMessageAttachment?> pickDocument(
    BuildContext context,
    WidgetRef ref, {
    required String companyId,
    required DocumentReference<Map<String, dynamic>> memberRef,
    required String memberName,
  }) async {
    // On web there is no path â€” request the bytes so we can upload them.
    final picked =
        await fp.FilePicker.platform.pickFiles(withData: kIsWeb);
    if (picked == null || picked.files.isEmpty) return null;
    final pf = picked.files.single;
    if (!context.mounted) return null;

    final XFile xfile;
    if (kIsWeb) {
      final bytes = pf.bytes;
      if (bytes == null) return null;
      xfile = XFile.fromData(bytes, name: pf.name);
    } else {
      if (pf.path == null) return null;
      xfile = XFile(pf.path!);
    }

    return _uploadAndRecord(
      context,
      ref,
      companyId: companyId,
      memberRef: memberRef,
      memberName: memberName,
      localFile: xfile,
      originalFileName: pf.name,
      sizeBytesOverride: pf.size,
      type: _attachmentTypeForFileName(pf.name),
    );
  }

  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ From an existing drive file â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  static Future<TextMessageAttachment?> pickFromDrive(
    BuildContext context,
  ) async {
    final picked = await showDriveFilePickerSheet(context);
    if (picked == null) return null;
    final url = picked.downloadUrl;
    if (url == null || url.isEmpty) {
      SnackbarService.instance.showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 4),
          content: Text('"${picked.name}" has no content to share.'),
        ),
      );
      return null;
    }
    return TextMessageAttachment(
      url: url,
      fileName: picked.name,
      sizeBytes: picked.sizeBytes,
      type: _attachmentTypeForFileKind(fileKindOf(picked)),
    );
  }

  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ Internals â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  /// Upload [localFile] to Storage, write a `file` doc under the sender's
  /// "Texted attachments" folder, and return the matching attachment. Shows
  /// a blocking spinner while the upload runs.
  static Future<TextMessageAttachment?> _uploadAndRecord(
    BuildContext context,
    WidgetRef ref, {
    required String companyId,
    required DocumentReference<Map<String, dynamic>> memberRef,
    required String memberName,
    required XFile localFile,
    required String originalFileName,
    required TextMessageAttachmentType type,
    String? storageExtensionOverride,
    int? sizeBytesOverride,
  }) async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final repo = ref.read(fileRepositoryProvider);
      final docRef = repo.fileCollection(companyId).doc();
      final ext = storageExtensionOverride ??
          (p.extension(originalFileName).isNotEmpty
              ? p.extension(originalFileName)
              : p.extension(localFile.name));
      final storagePath = 'file/${docRef.id}$ext';
      final contentType = _contentTypeForExt(ext);

      // Web: putData(bytes). Mobile: putFile, with video compression preserved.
      final String downloadUrl;
      if (kIsWeb) {
        downloadUrl = await StorageService()
            .uploadXFile(localFile, storagePath, contentType: contentType);
      } else {
        final ioFile = File(localFile.path);
        downloadUrl = type == TextMessageAttachmentType.video
            ? await StorageService().uploadVideo(ioFile, storagePath)
            : await StorageService()
                .uploadFile(ioFile, storagePath, contentType: contentType);
      }

      final folder = await _ensureTextedAttachmentsFolder(
        ref,
        companyId: companyId,
        memberRef: memberRef,
        memberName: memberName,
      );

      final size = sizeBytesOverride ?? await _safeLength(localFile);

      final displayName = storageExtensionOverride == null
          ? originalFileName
          : p.setExtension(
              p.basenameWithoutExtension(originalFileName),
              storageExtensionOverride,
            );

      final userRef = ref.read(userDocRefProvider);

      await repo.createFile(
        companyId: companyId,
        driveRef: folder.driveRef!,
        name: displayName,
        storagePath: storagePath,
        downloadUrl: downloadUrl,
        parentFolderRef: folder.ref,
        parentAncestorIds: folder.ancestorIds,
        sourceFileName: originalFileName,
        sizeBytes: size,
        createdBy: memberRef,
        userRef: userRef,
        newDocId: docRef.id,
      );

      return TextMessageAttachment(
        url: downloadUrl,
        fileName: displayName,
        sizeBytes: size,
        mimeType: contentType,
        type: type,
      );
    } catch (e) {
      SnackbarService.instance.showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 5),
          content: Text('Attachment failed: $e'),
        ),
      );
      return null;
    } finally {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
    }
  }

  /// Resolve (or create) the "Texted attachments" folder at the root of the
  /// sender's My Drive. Auto-creates the personal drive itself if missing so
  /// the flow works for members who have never opened the Files section.
  static Future<FileModel> _ensureTextedAttachmentsFolder(
    WidgetRef ref, {
    required String companyId,
    required DocumentReference<Map<String, dynamic>> memberRef,
    required String memberName,
  }) async {
    final repo = ref.read(fileRepositoryProvider);
    final userRef = ref.read(userDocRefProvider);
    final drive = await repo.ensurePersonalDrive(
      companyId: companyId,
      memberId: memberRef.id,
      displayName: memberName.isEmpty ? 'My' : memberName,
      createdBy: userRef,
    );

    final existing = await repo
        .fileCollection(companyId)
        .where('driveRef', isEqualTo: drive.ref)
        .where('parentFolderRef', isNull: true)
        .where('isFolder', isEqualTo: true)
        .where('name', isEqualTo: _textedFolderName)
        .limit(1)
        .get();
    if (existing.docs.isNotEmpty) {
      return FileModel.fromSnapshot(existing.docs.first);
    }

    final folderRef = await repo.createFolder(
      companyId: companyId,
      driveRef: drive.ref,
      name: _textedFolderName,
      createdBy: memberRef,
      userRef: userRef,
    );
    final snap = await folderRef.get();
    return FileModel.fromSnapshot(snap);
  }

  /// XFile.length() works on every platform (bytes length on web). Returns
  /// null if it can't be read rather than throwing.
  static Future<int?> _safeLength(XFile file) async {
    try {
      return await file.length();
    } catch (_) {
      return null;
    }
  }

  /// Filename for an [XFile], guaranteeing an extension so the storage path
  /// and display name stay sensible even when the picker hands back a blob.
  static String _xfileName(XFile file, {required String fallbackExt}) {
    final name = file.name;
    if (name.isNotEmpty && p.extension(name).isNotEmpty) return name;
    final base = name.isNotEmpty ? p.basenameWithoutExtension(name) : 'attachment';
    return '$base$fallbackExt';
  }

  static String? _contentTypeForExt(String extWithDot) {
    final ext = extWithDot.replaceFirst('.', '').toLowerCase();
    if (ext.isEmpty) return null;
    const map = <String, String>{
      'jpg': 'image/jpeg',
      'jpeg': 'image/jpeg',
      'png': 'image/png',
      'gif': 'image/gif',
      'webp': 'image/webp',
      'heic': 'image/heic',
      'bmp': 'image/bmp',
      'svg': 'image/svg+xml',
      'mp4': 'video/mp4',
      'mov': 'video/quicktime',
      'webm': 'video/webm',
      'pdf': 'application/pdf',
    };
    return map[ext];
  }

  static TextMessageAttachmentType _attachmentTypeForFileName(String name) {
    final dot = name.lastIndexOf('.');
    final ext = dot < 0 ? '' : name.substring(dot + 1).toLowerCase();
    if (_imageExt.contains(ext)) return TextMessageAttachmentType.image;
    if (_videoExt.contains(ext)) return TextMessageAttachmentType.video;
    if (_audioExt.contains(ext)) return TextMessageAttachmentType.audio;
    return TextMessageAttachmentType.document;
  }

  static TextMessageAttachmentType _attachmentTypeForFileKind(FileKind kind) {
    switch (kind) {
      case FileKind.image:
        return TextMessageAttachmentType.image;
      case FileKind.video:
        return TextMessageAttachmentType.video;
      case FileKind.audio:
        return TextMessageAttachmentType.audio;
      default:
        return TextMessageAttachmentType.document;
    }
  }

  static Future<ImageSource?> _pickImageSource(BuildContext context) {
    return showModalBottomSheet<ImageSource>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Camera'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
  }
}

// Match file_kinds.dart â€” duplicated here so we can classify a filename
// without constructing a placeholder FileModel.
const Set<String> _imageExt = {
  'jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp', 'heic', 'heif', 'svg', 'tif', 'tiff',
};
const Set<String> _videoExt = {
  'mp4', 'mov', 'avi', 'mkv', 'wmv', 'webm', 'm4v', 'flv',
};
const Set<String> _audioExt = {
  'mp3', 'wav', 'm4a', 'aac', 'ogg', 'flac', 'wma',
};

