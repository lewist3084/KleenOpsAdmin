// Mirrors kleenops TextConversation model for admin app.
import 'package:cloud_firestore/cloud_firestore.dart';

class TextConversation {
  final String id;
  final DocumentReference<Map<String, dynamic>> ref;
  final String title;
  final List<DocumentReference<Map<String, dynamic>>> participantRefs;
  final List<String> participantNames;
  final DocumentReference<Map<String, dynamic>>? teamRef;
  final String? teamName;
  final String? lastMessageText;
  final String? lastMessageSenderName;
  final DateTime? lastMessageAt;
  final DateTime createdAt;
  final bool isGroup;

  const TextConversation({
    required this.id,
    required this.ref,
    this.title = '',
    this.participantRefs = const [],
    this.participantNames = const [],
    this.teamRef,
    this.teamName,
    this.lastMessageText,
    this.lastMessageSenderName,
    this.lastMessageAt,
    required this.createdAt,
    this.isGroup = false,
  });

  factory TextConversation.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final d = doc.data() ?? {};
    final lastMsgTs = d['lastMessageAt'] as Timestamp?;
    final createdTs = d['createdAt'] as Timestamp?;

    return TextConversation(
      id: doc.id,
      ref: doc.reference,
      title: (d['title'] as String?) ?? '',
      participantRefs: (d['participantRefs'] as List<dynamic>? ?? [])
          .whereType<DocumentReference>()
          .map((r) => r.withConverter<Map<String, dynamic>>(
                fromFirestore: (s, _) => s.data() ?? {},
                toFirestore: (m, _) => m,
              ))
          .toList(),
      participantNames:
          (d['participantNames'] as List<dynamic>? ?? []).whereType<String>().toList(),
      teamRef: d['teamRef'] as DocumentReference<Map<String, dynamic>>?,
      teamName: d['teamName'] as String?,
      lastMessageText: d['lastMessageText'] as String?,
      lastMessageSenderName: d['lastMessageSenderName'] as String?,
      lastMessageAt: lastMsgTs?.toDate(),
      createdAt: createdTs?.toDate() ?? DateTime.now(),
      isGroup: d['isGroup'] as bool? ?? false,
    );
  }

  String getDisplayTitle(String currentMemberId) {
    if (title.isNotEmpty) return title;
    if (teamName != null && teamName!.isNotEmpty) return teamName!;
    final others = <String>[];
    for (int i = 0; i < participantRefs.length; i++) {
      if (participantRefs[i].id != currentMemberId &&
          i < participantNames.length) {
        others.add(participantNames[i]);
      }
    }
    return others.isNotEmpty ? others.join(', ') : 'Conversation';
  }
}
