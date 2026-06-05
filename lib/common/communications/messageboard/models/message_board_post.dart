// lib/common/communications/messageboard/models/message_board_post.dart

import 'package:cloud_firestore/cloud_firestore.dart';

/// Types of content that can be posted to the message board.
enum MessageBoardPostType {
  note,      // Sticky note style text
  document,  // PDF, Excel, Word, etc.
  image,     // Image/flyer
  video,     // Video content
  link,      // External link
}

/// Represents a post on the message board.
class MessageBoardPost {
  final String id;
  final DocumentReference<Map<String, dynamic>> ref;
  final String title;
  final String? content;
  final MessageBoardPostType type;
  final bool isPinned;
  final int priority;
  final String? noteColor;
  final String? fileUrl;
  final String? thumbnailUrl;
  final String? fileName;
  final String? mimeType;
  final int? fileSizeBytes;
  final String? linkUrl;
  final DocumentReference<Map<String, dynamic>>? createdByRef;
  final String createdByName;
  final String? createdByAvatarUrl;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<DocumentReference<Map<String, dynamic>>> teamRefs;
  final List<String> teamNames;
  final List<String> tags;

  /// When the post should expire and drop off the active board.
  final DateTime? expiresAt;

  /// Whether the post has been archived (expired or manually removed).
  final bool isArchived;

  const MessageBoardPost({
    required this.id,
    required this.ref,
    required this.title,
    this.content,
    required this.type,
    this.isPinned = false,
    this.priority = 0,
    this.noteColor,
    this.fileUrl,
    this.thumbnailUrl,
    this.fileName,
    this.mimeType,
    this.fileSizeBytes,
    this.linkUrl,
    this.createdByRef,
    required this.createdByName,
    this.createdByAvatarUrl,
    required this.createdAt,
    required this.updatedAt,
    this.teamRefs = const [],
    this.teamNames = const [],
    this.tags = const [],
    this.expiresAt,
    this.isArchived = false,
  });

  factory MessageBoardPost.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final createdTs = data['createdAt'] as Timestamp?;
    final updatedTs = data['updatedAt'] as Timestamp?;
    final expiresTs = data['expiresAt'] as Timestamp?;

    final typeStr = (data['type'] as String?) ?? 'note';
    final type = MessageBoardPostType.values.firstWhere(
      (t) => t.name == typeStr,
      orElse: () => MessageBoardPostType.note,
    );

    final rawTeamRefs = data['teamRefs'] as List<dynamic>? ?? [];
    final teamRefs = rawTeamRefs
        .whereType<DocumentReference>()
        .map((r) => r.withConverter<Map<String, dynamic>>(
              fromFirestore: (s, _) => s.data() ?? {},
              toFirestore: (m, _) => m,
            ))
        .toList();

    final rawTeamNames = data['teamNames'] as List<dynamic>? ?? [];
    final teamNames = rawTeamNames.whereType<String>().toList();

    final rawTags = data['tags'] as List<dynamic>? ?? [];
    final tags = rawTags.whereType<String>().toList();

    return MessageBoardPost(
      id: doc.id,
      ref: doc.reference,
      title: (data['title'] as String?) ?? (data['name'] as String?) ?? '',
      content: data['content'] as String? ?? data['body'] as String?,
      type: type,
      isPinned: data['isPinned'] as bool? ?? false,
      priority: data['priority'] as int? ?? 0,
      noteColor: data['noteColor'] as String?,
      fileUrl: data['fileUrl'] as String? ?? data['url'] as String?,
      thumbnailUrl: data['thumbnailUrl'] as String?,
      fileName: data['fileName'] as String?,
      mimeType: data['mimeType'] as String?,
      fileSizeBytes: data['fileSizeBytes'] as int?,
      linkUrl: data['linkUrl'] as String?,
      createdByRef: data['createdByRef'] as DocumentReference<Map<String, dynamic>>?,
      createdByName: (data['createdByName'] as String?) ?? '',
      createdByAvatarUrl: data['createdByAvatarUrl'] as String?,
      createdAt: createdTs?.toDate() ?? DateTime.now(),
      updatedAt: updatedTs?.toDate() ?? DateTime.now(),
      teamRefs: teamRefs,
      teamNames: teamNames,
      tags: tags,
      expiresAt: expiresTs?.toDate(),
      isArchived: data['isArchived'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
        'title': title,
        if (content != null) 'content': content,
        'type': type.name,
        'isPinned': isPinned,
        'priority': priority,
        if (noteColor != null) 'noteColor': noteColor,
        if (fileUrl != null) 'fileUrl': fileUrl,
        if (thumbnailUrl != null) 'thumbnailUrl': thumbnailUrl,
        if (fileName != null) 'fileName': fileName,
        if (mimeType != null) 'mimeType': mimeType,
        if (fileSizeBytes != null) 'fileSizeBytes': fileSizeBytes,
        if (linkUrl != null) 'linkUrl': linkUrl,
        if (createdByRef != null) 'createdByRef': createdByRef,
        'createdByName': createdByName,
        if (createdByAvatarUrl != null) 'createdByAvatarUrl': createdByAvatarUrl,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'teamRefs': teamRefs,
        'teamNames': teamNames,
        'tags': tags,
        if (expiresAt != null) 'expiresAt': Timestamp.fromDate(expiresAt!),
        'isArchived': isArchived,
      };

  /// Get file type from mime type.
  String? get fileTypeLabel {
    if (mimeType == null) return null;
    if (mimeType!.contains('pdf')) return 'PDF';
    if (mimeType!.contains('excel') || mimeType!.contains('spreadsheet')) return 'Excel';
    if (mimeType!.contains('word') || mimeType!.contains('document')) return 'Word';
    if (mimeType!.contains('powerpoint') || mimeType!.contains('presentation')) return 'PowerPoint';
    if (mimeType!.contains('image')) return 'Image';
    if (mimeType!.contains('video')) return 'Video';
    return 'File';
  }

  /// Whether this post has passed its expiration date.
  bool get isExpired =>
      expiresAt != null && DateTime.now().isAfter(expiresAt!);

  /// Days remaining until expiration, or null if no expiry set.
  int? get daysRemaining {
    if (expiresAt == null) return null;
    final diff = expiresAt!.difference(DateTime.now()).inDays;
    return diff < 0 ? 0 : diff;
  }

  /// Available note colors.
  static const List<String> noteColors = [
    '#FFEB3B', // Yellow (default sticky note)
    '#FF9800', // Orange
    '#E91E63', // Pink
    '#9C27B0', // Purple
    '#2196F3', // Blue
    '#4CAF50', // Green
    '#00BCD4', // Cyan
    '#FFFFFF', // White
  ];
}

