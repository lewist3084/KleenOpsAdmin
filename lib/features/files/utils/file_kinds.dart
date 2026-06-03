// Classifies a FileModel into a coarse "kind" used for icons, type labels,
// and the Drive filter chips. Extension is sniffed from the display name,
// the original source filename, or the storage path â€” in that order.

import 'package:flutter/material.dart';

import 'package:kleenops_admin/features/files/data/file_model.dart';

enum FileKind {
  folder,
  image,
  pdf,
  document,
  spreadsheet,
  presentation,
  video,
  audio,
  archive,
  other,
}

const Set<String> _imageExt = {
  'jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp', 'heic', 'heif', 'svg', 'tif', 'tiff',
};
const Set<String> _videoExt = {
  'mp4', 'mov', 'avi', 'mkv', 'wmv', 'webm', 'm4v', 'flv',
};
const Set<String> _audioExt = {
  'mp3', 'wav', 'm4a', 'aac', 'ogg', 'flac', 'wma',
};
const Set<String> _docExt = {
  'doc', 'docx', 'txt', 'rtf', 'odt', 'pages', 'md',
};
const Set<String> _sheetExt = {
  'xls', 'xlsx', 'csv', 'ods', 'numbers', 'tsv',
};
const Set<String> _slideExt = {
  'ppt', 'pptx', 'odp', 'key',
};
const Set<String> _archiveExt = {
  'zip', 'rar', '7z', 'tar', 'gz', 'bz2',
};

/// Lower-cased extension without the leading dot, or '' if none.
String fileExtensionOf(FileModel f) {
  for (final candidate in <String?>[f.name, f.sourceFileName, f.storagePath]) {
    if (candidate == null || candidate.isEmpty) continue;
    final clean = candidate.split('?').first;
    final dot = clean.lastIndexOf('.');
    if (dot >= 0 && dot < clean.length - 1) {
      return clean.substring(dot + 1).toLowerCase().trim();
    }
  }
  return '';
}

FileKind fileKindOf(FileModel f) {
  if (f.isFolder) return FileKind.folder;
  final ext = fileExtensionOf(f);
  if (ext == 'pdf') return FileKind.pdf;
  if (_imageExt.contains(ext)) return FileKind.image;
  if (_videoExt.contains(ext)) return FileKind.video;
  if (_audioExt.contains(ext)) return FileKind.audio;
  if (_sheetExt.contains(ext)) return FileKind.spreadsheet;
  if (_slideExt.contains(ext)) return FileKind.presentation;
  if (_docExt.contains(ext)) return FileKind.document;
  if (_archiveExt.contains(ext)) return FileKind.archive;
  return FileKind.other;
}

/// Outlined (passive/informational) icon for a file kind.
IconData iconForKind(FileKind kind) {
  switch (kind) {
    case FileKind.folder:
      return Icons.folder_outlined;
    case FileKind.image:
      return Icons.image_outlined;
    case FileKind.pdf:
      return Icons.picture_as_pdf_outlined;
    case FileKind.document:
      return Icons.description_outlined;
    case FileKind.spreadsheet:
      return Icons.table_chart_outlined;
    case FileKind.presentation:
      return Icons.slideshow_outlined;
    case FileKind.video:
      return Icons.movie_outlined;
    case FileKind.audio:
      return Icons.audiotrack_outlined;
    case FileKind.archive:
      return Icons.folder_zip_outlined;
    case FileKind.other:
      return Icons.insert_drive_file_outlined;
  }
}

String labelForKind(FileKind kind) {
  switch (kind) {
    case FileKind.folder:
      return 'Folder';
    case FileKind.image:
      return 'Image';
    case FileKind.pdf:
      return 'PDF';
    case FileKind.document:
      return 'Document';
    case FileKind.spreadsheet:
      return 'Spreadsheet';
    case FileKind.presentation:
      return 'Presentation';
    case FileKind.video:
      return 'Video';
    case FileKind.audio:
      return 'Audio';
    case FileKind.archive:
      return 'Archive';
    case FileKind.other:
      return 'File';
  }
}

/// The kinds exposed as filter chips, in display order. `null` = "All".
const List<FileKind?> kDriveFilterKinds = <FileKind?>[
  null,
  FileKind.folder,
  FileKind.document,
  FileKind.spreadsheet,
  FileKind.image,
  FileKind.pdf,
  FileKind.video,
];

String driveFilterLabel(FileKind? kind) {
  if (kind == null) return 'All';
  switch (kind) {
    case FileKind.folder:
      return 'Folders';
    case FileKind.document:
      return 'Docs';
    case FileKind.spreadsheet:
      return 'Sheets';
    case FileKind.image:
      return 'Images';
    case FileKind.pdf:
      return 'PDFs';
    case FileKind.video:
      return 'Videos';
    default:
      return labelForKind(kind);
  }
}

/// Human-readable file size, e.g. "2.4 MB". Empty string when unknown.
String formatBytes(int? bytes) {
  if (bytes == null || bytes <= 0) return '';
  const units = <String>['B', 'KB', 'MB', 'GB', 'TB'];
  var size = bytes.toDouble();
  var unit = 0;
  while (size >= 1024 && unit < units.length - 1) {
    size /= 1024;
    unit += 1;
  }
  final fixed = (size >= 10 || unit == 0) ? 0 : 1;
  return '${size.toStringAsFixed(fixed)} ${units[unit]}';
}

