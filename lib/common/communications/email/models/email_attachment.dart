// lib/common/communications/email/models/email_attachment.dart
// Ported from the kleenops app — kept field-for-field identical so the same
// Firestore email docs render in both apps.

/// Attachment types for email messages.
enum EmailAttachmentType { image, video, document, audio, other }

/// Represents an attachment on an email message.
class EmailAttachment {
  final String id;
  final String fileName;
  final String? mimeType;
  final int? sizeBytes;
  final String? url;
  final String? storagePath;
  final String? localPath;
  final EmailAttachmentType type;
  final bool isInline;
  final String? contentId;

  const EmailAttachment({
    required this.id,
    required this.fileName,
    this.mimeType,
    this.sizeBytes,
    this.url,
    this.storagePath,
    this.localPath,
    required this.type,
    this.isInline = false,
    this.contentId,
  });

  factory EmailAttachment.fromMap(Map<String, dynamic> map) {
    final typeStr = (map['type'] as String?) ?? 'other';
    final type = EmailAttachmentType.values.firstWhere(
      (t) => t.name == typeStr,
      orElse: () => EmailAttachmentType.other,
    );

    return EmailAttachment(
      id: (map['id'] as String?) ?? '',
      fileName: (map['fileName'] as String?) ?? 'attachment',
      mimeType: map['mimeType'] as String?,
      sizeBytes: map['sizeBytes'] as int?,
      url: map['url'] as String?,
      storagePath: map['storagePath'] as String?,
      localPath: map['localPath'] as String?,
      type: type,
      isInline: map['isInline'] as bool? ?? false,
      contentId: map['contentId'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'fileName': fileName,
        if (mimeType != null) 'mimeType': mimeType,
        if (sizeBytes != null) 'sizeBytes': sizeBytes,
        if (url != null) 'url': url,
        if (storagePath != null) 'storagePath': storagePath,
        if (localPath != null) 'localPath': localPath,
        'type': type.name,
        'isInline': isInline,
        if (contentId != null) 'contentId': contentId,
      };

  /// Determine attachment type from MIME type.
  static EmailAttachmentType typeFromMime(String? mimeType) {
    if (mimeType == null) return EmailAttachmentType.other;

    if (mimeType.startsWith('image/')) return EmailAttachmentType.image;
    if (mimeType.startsWith('video/')) return EmailAttachmentType.video;
    if (mimeType.startsWith('audio/')) return EmailAttachmentType.audio;
    if (mimeType.contains('pdf') ||
        mimeType.contains('document') ||
        mimeType.contains('text/') ||
        mimeType.contains('spreadsheet') ||
        mimeType.contains('presentation')) {
      return EmailAttachmentType.document;
    }
    return EmailAttachmentType.other;
  }

  /// Human-readable file size.
  String get humanReadableSize {
    if (sizeBytes == null) return '';
    final bytes = sizeBytes!;
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}
