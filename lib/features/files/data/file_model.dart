import 'package:cloud_firestore/cloud_firestore.dart';

/// Unified model for items in `company/{id}/file/{fileId}`.
///
/// Folders are file documents with `isFolder: true` and no storage payload â€”
/// modelled after Google Drive's "everything is an item" approach. This lets
/// the same list query show files and folders together and makes move / copy /
/// rename logic uniform.
///
/// Two new structural fields on top of the legacy schema:
///
///   - `driveRef`        â€” the access boundary (see DriveModel). Nullable only
///                         for legacy file docs created before the Drive
///                         system; the migration backfill assigns one.
///   - `parentFolderRef` â€” null = drive root, otherwise points to a file doc
///                         with `isFolder: true`.
///   - `ancestorIds`     â€” denormalized list of folder ids from drive root
///                         down to the immediate parent. Used for "show
///                         everything under folder X" queries without walking
///                         the tree.
///   - `deletedAt`       â€” soft-delete tombstone. List queries should filter
///                         this out.
class FileModel {
  FileModel({
    required this.id,
    required this.ref,
    required this.name,
    required this.isFolder,
    this.driveRef,
    this.parentFolderRef,
    this.ancestorIds = const [],
    this.description,
    this.downloadUrl,
    this.storagePath,
    this.sourceFileName,
    this.sizeBytes,
    this.createdAt,
    this.createdBy,
    this.userRef,
    this.deletedAt,
  });

  final String id;
  final DocumentReference<Map<String, dynamic>> ref;
  final String name;
  final bool isFolder;
  final DocumentReference<Map<String, dynamic>>? driveRef;
  final DocumentReference<Map<String, dynamic>>? parentFolderRef;
  final List<String> ancestorIds;
  final String? description;
  final String? downloadUrl;
  final String? storagePath;
  final String? sourceFileName;
  final int? sizeBytes;
  final DateTime? createdAt;
  final DocumentReference<Map<String, dynamic>>? createdBy;
  final DocumentReference<Map<String, dynamic>>? userRef;
  final DateTime? deletedAt;

  factory FileModel.fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snap,
  ) {
    final d = snap.data() ?? {};
    return FileModel(
      id: snap.id,
      ref: snap.reference,
      name: (d['name'] as String?) ?? '',
      isFolder: (d['isFolder'] as bool?) ?? false,
      driveRef: d['driveRef'] as DocumentReference<Map<String, dynamic>>?,
      parentFolderRef:
          d['parentFolderRef'] as DocumentReference<Map<String, dynamic>>?,
      ancestorIds:
          List<String>.from(d['ancestorIds'] as List? ?? const []),
      description: d['description'] as String?,
      downloadUrl: d['downloadUrl'] as String?,
      storagePath: d['storagePath'] as String?,
      sourceFileName: d['sourceFileName'] as String?,
      sizeBytes: (d['sizeBytes'] as num?)?.toInt(),
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
      createdBy:
          d['createdBy'] as DocumentReference<Map<String, dynamic>>?,
      userRef: d['userRef'] as DocumentReference<Map<String, dynamic>>?,
      deletedAt: (d['deletedAt'] as Timestamp?)?.toDate(),
    );
  }
}

