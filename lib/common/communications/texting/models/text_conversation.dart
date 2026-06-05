// lib/common/communications/texting/models/text_conversation.dart

import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a text conversation (thread) between members or within a team.
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
  final int unreadCount;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isGroup;
  final String? avatarUrl;
  final DocumentReference<Map<String, dynamic>>? createdBy;

  /// When true, non-creator replies are pinned to a private thread between
  /// the replier and the [createdBy] member (via per-message `visibleTo`).
  /// Null/false means a normal group thread visible to everyone.
  final bool? directResponseMode;

  /// Conversation channel: `'internal'` (default, Firestore-only) or `'sms'`
  /// (two-way Twilio SMS/MMS with an external phone).
  final String channel;

  /// For SMS conversations: the external contact's number (E.164) and the
  /// business (Twilio) number used to send/receive.
  final String? externalPhoneE164;
  final String? businessNumberE164;

  /// For SMS conversations: the external contact has texted STOP â€” sending is
  /// blocked until they text START.
  final bool optedOut;

  /// True when this is an external SMS thread (vs an internal chat).
  bool get isExternal => channel == 'sms';

  const TextConversation({
    required this.id,
    required this.ref,
    required this.title,
    this.participantRefs = const [],
    this.participantNames = const [],
    this.teamRef,
    this.teamName,
    this.lastMessageText,
    this.lastMessageSenderName,
    this.lastMessageAt,
    this.unreadCount = 0,
    required this.createdAt,
    required this.updatedAt,
    this.isGroup = false,
    this.avatarUrl,
    this.createdBy,
    this.directResponseMode,
    this.channel = 'internal',
    this.externalPhoneE164,
    this.businessNumberE164,
    this.optedOut = false,
  });

  factory TextConversation.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc, {
    int unreadCount = 0,
  }) {
    final data = doc.data() ?? {};
    final createdTs = data['createdAt'] as Timestamp?;
    final updatedTs = data['updatedAt'] as Timestamp?;
    final lastMsgTs = data['lastMessageAt'] as Timestamp?;

    final rawParticipants = data['participantRefs'] as List<dynamic>? ?? [];
    final participantRefs = rawParticipants
        .whereType<DocumentReference>()
        .map((r) => r.withConverter<Map<String, dynamic>>(
              fromFirestore: (s, _) => s.data() ?? {},
              toFirestore: (m, _) => m,
            ))
        .toList();

    final rawNames = data['participantNames'] as List<dynamic>? ?? [];
    final participantNames = rawNames.whereType<String>().toList();

    return TextConversation(
      id: doc.id,
      ref: doc.reference,
      title: (data['title'] as String?) ?? 'Conversation',
      participantRefs: participantRefs,
      participantNames: participantNames,
      teamRef: data['teamRef'] as DocumentReference<Map<String, dynamic>>?,
      teamName: data['teamName'] as String?,
      lastMessageText: data['lastMessageText'] as String?,
      lastMessageSenderName: data['lastMessageSenderName'] as String?,
      lastMessageAt: lastMsgTs?.toDate(),
      unreadCount: unreadCount,
      createdAt: createdTs?.toDate() ?? DateTime.now(),
      updatedAt: updatedTs?.toDate() ?? DateTime.now(),
      isGroup: data['isGroup'] as bool? ?? (participantRefs.length > 2),
      avatarUrl: data['avatarUrl'] as String?,
      createdBy: data['createdBy'] as DocumentReference<Map<String, dynamic>>?,
      directResponseMode: data['directResponseMode'] as bool?,
      channel: (data['channel'] as String?) ?? 'internal',
      externalPhoneE164: data['externalPhoneE164'] as String?,
      businessNumberE164: data['businessNumberE164'] as String?,
      optedOut: data['optedOut'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
        'title': title,
        'participantRefs': participantRefs,
        'participantNames': participantNames,
        if (teamRef != null) 'teamRef': teamRef,
        if (teamName != null) 'teamName': teamName,
        if (lastMessageText != null) 'lastMessageText': lastMessageText,
        if (lastMessageSenderName != null)
          'lastMessageSenderName': lastMessageSenderName,
        if (lastMessageAt != null)
          'lastMessageAt': Timestamp.fromDate(lastMessageAt!),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'isGroup': isGroup,
        if (avatarUrl != null) 'avatarUrl': avatarUrl,
        if (channel != 'internal') 'channel': channel,
        if (externalPhoneE164 != null) 'externalPhoneE164': externalPhoneE164,
        if (businessNumberE164 != null) 'businessNumberE164': businessNumberE164,
      };

  /// Get display title for conversation (other participant's name in 1:1 chat).
  String getDisplayTitle(String currentMemberId) {
    if (title.isNotEmpty && title != 'Conversation') return title;
    if (isGroup && teamName != null && teamName!.isNotEmpty) return teamName!;

    // For 1:1 conversations, show the other person's name
    final otherNames = <String>[];
    for (int i = 0; i < participantRefs.length; i++) {
      if (participantRefs[i].id != currentMemberId) {
        if (i < participantNames.length) {
          otherNames.add(participantNames[i]);
        }
      }
    }
    if (otherNames.isNotEmpty) return otherNames.join(', ');
    return 'Conversation';
  }
}

