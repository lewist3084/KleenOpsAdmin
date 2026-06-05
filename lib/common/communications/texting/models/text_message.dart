// lib/common/communications/texting/models/text_message.dart

import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents an individual text message within a conversation.
class TextMessage {
  final String id;
  final DocumentReference<Map<String, dynamic>> ref;
  final String text;
  final DocumentReference<Map<String, dynamic>>? senderRef;
  final String senderName;
  final String? senderAvatarUrl;
  final DateTime createdAt;
  final DateTime? readAt;
  final List<String> readByMemberIds;
  final List<TextMessageAttachment> attachments;
  final bool isDeleted;

  /// When non-null, restricts visibility to the listed member IDs (used by
  /// direct-response replies in group threads). Null means visible to all
  /// conversation participants.
  final List<String>? visibleToMemberIds;

  /// Set when the sender has edited the message text after sending.
  final DateTime? editedAt;

  const TextMessage({
    required this.id,
    required this.ref,
    required this.text,
    this.senderRef,
    required this.senderName,
    this.senderAvatarUrl,
    required this.createdAt,
    this.readAt,
    this.readByMemberIds = const [],
    this.attachments = const [],
    this.isDeleted = false,
    this.visibleToMemberIds,
    this.editedAt,
  });

  factory TextMessage.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    final createdTs = data['createdAt'] as Timestamp?;
    final readTs = data['readAt'] as Timestamp?;
    final editedTs = data['editedAt'] as Timestamp?;

    final rawAttachments = data['attachments'] as List<dynamic>? ?? [];
    final attachments = rawAttachments
        .whereType<Map<String, dynamic>>()
        .map((e) => TextMessageAttachment.fromMap(e))
        .toList();

    final rawReadBy = data['readByMemberIds'] as List<dynamic>? ?? [];
    final readByIds = rawReadBy.map((e) {
      if (e is DocumentReference) return e.id;
      if (e is String) return e;
      return '';
    }).where((e) => e.isNotEmpty).toList();

    final rawVisible = data['visibleToMemberIds'];
    final visibleToIds = rawVisible is List
        ? rawVisible.whereType<String>().toList()
        : null;

    return TextMessage(
      id: doc.id,
      ref: doc.reference,
      text: (data['text'] as String?) ?? (data['message'] as String?) ?? '',
      senderRef: data['senderRef'] as DocumentReference<Map<String, dynamic>>?,
      senderName: (data['senderName'] as String?) ?? '',
      senderAvatarUrl: data['senderAvatarUrl'] as String?,
      createdAt: createdTs?.toDate() ?? DateTime.now(),
      readAt: readTs?.toDate(),
      readByMemberIds: readByIds,
      attachments: attachments,
      isDeleted: data['isDeleted'] as bool? ?? false,
      visibleToMemberIds: visibleToIds,
      editedAt: editedTs?.toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
        'text': text,
        'senderRef': senderRef,
        'senderName': senderName,
        if (senderAvatarUrl != null) 'senderAvatarUrl': senderAvatarUrl,
        'createdAt': FieldValue.serverTimestamp(),
        'readByMemberIds': readByMemberIds,
        'attachments': attachments.map((a) => a.toMap()).toList(),
        'isDeleted': isDeleted,
      };

  bool isReadBy(String memberId) => readByMemberIds.contains(memberId);
}

/// Attachment types for text messages.
enum TextMessageAttachmentType { image, video, document, audio }

/// Represents an attachment on a text message.
class TextMessageAttachment {
  final String url;
  final String? thumbnailUrl;
  final String? fileName;
  final String? mimeType;
  final int? sizeBytes;
  final TextMessageAttachmentType type;

  const TextMessageAttachment({
    required this.url,
    this.thumbnailUrl,
    this.fileName,
    this.mimeType,
    this.sizeBytes,
    required this.type,
  });

  factory TextMessageAttachment.fromMap(Map<String, dynamic> map) {
    final typeStr = (map['type'] as String?) ?? 'document';
    final type = TextMessageAttachmentType.values.firstWhere(
      (t) => t.name == typeStr,
      orElse: () => TextMessageAttachmentType.document,
    );

    return TextMessageAttachment(
      url: (map['url'] as String?) ?? '',
      thumbnailUrl: map['thumbnailUrl'] as String?,
      fileName: map['fileName'] as String?,
      mimeType: map['mimeType'] as String?,
      sizeBytes: map['sizeBytes'] as int?,
      type: type,
    );
  }

  Map<String, dynamic> toMap() => {
        'url': url,
        if (thumbnailUrl != null) 'thumbnailUrl': thumbnailUrl,
        if (fileName != null) 'fileName': fileName,
        if (mimeType != null) 'mimeType': mimeType,
        if (sizeBytes != null) 'sizeBytes': sizeBytes,
        'type': type.name,
      };
}

