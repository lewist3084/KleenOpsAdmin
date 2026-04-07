// Mirrors kleenops MessageBoardPost model for admin app.
import 'package:cloud_firestore/cloud_firestore.dart';

enum MessageBoardPostType { note, document, image, video, link }

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
  final String createdByName;
  final DateTime createdAt;
  final List<DocumentReference<Map<String, dynamic>>> teamRefs;
  final List<String> teamNames;
  final DateTime? expiresAt;
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
    required this.createdByName,
    required this.createdAt,
    this.teamRefs = const [],
    this.teamNames = const [],
    this.expiresAt,
    this.isArchived = false,
  });

  factory MessageBoardPost.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final d = doc.data() ?? {};
    final typeStr = (d['type'] as String?) ?? 'note';
    final type = MessageBoardPostType.values.firstWhere(
      (t) => t.name == typeStr,
      orElse: () => MessageBoardPostType.note,
    );
    return MessageBoardPost(
      id: doc.id,
      ref: doc.reference,
      title: (d['title'] as String?) ?? '',
      content: d['content'] as String?,
      type: type,
      isPinned: d['isPinned'] as bool? ?? false,
      priority: (d['priority'] as num?)?.toInt() ?? 0,
      noteColor: d['noteColor'] as String?,
      fileUrl: d['fileUrl'] as String?,
      thumbnailUrl: d['thumbnailUrl'] as String?,
      fileName: d['fileName'] as String?,
      mimeType: d['mimeType'] as String?,
      createdByName: (d['createdByName'] as String?) ?? '',
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      teamRefs: (d['teamRefs'] as List<dynamic>? ?? [])
          .whereType<DocumentReference>()
          .map((r) => r.withConverter<Map<String, dynamic>>(
                fromFirestore: (s, _) => s.data() ?? {},
                toFirestore: (m, _) => m,
              ))
          .toList(),
      teamNames: (d['teamNames'] as List<dynamic>? ?? []).whereType<String>().toList(),
      expiresAt: (d['expiresAt'] as Timestamp?)?.toDate(),
      isArchived: d['isArchived'] as bool? ?? false,
    );
  }

  bool get isExpired => expiresAt != null && DateTime.now().isAfter(expiresAt!);
}
