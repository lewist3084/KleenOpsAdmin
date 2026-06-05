// lib/common/communications/texting/services/texting_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/text_conversation.dart';
import '../models/text_message.dart';

/// Timeline category ID for text messages.
const String kTextMessageTimelineCategoryId = 'text_message_category';

/// Service for managing text conversations and messages.
class TextingService {
  final DocumentReference<Map<String, dynamic>> companyRef;
  final DocumentReference<Map<String, dynamic>> memberRef;
  final String memberName;

  TextingService({
    required this.companyRef,
    required this.memberRef,
    required this.memberName,
  });

  /// Collection reference for conversations.
  CollectionReference<Map<String, dynamic>> get _conversationsRef =>
      companyRef.collection('textConversation');

  /// Get messages collection for a conversation.
  CollectionReference<Map<String, dynamic>> _messagesRef(String conversationId) =>
      _conversationsRef.doc(conversationId).collection('message');

  /// Stream of conversations for the current member.
  Stream<List<TextConversation>> watchConversations() {
    return _conversationsRef
        .where('participantRefs', arrayContains: memberRef)
        .orderBy('lastMessageAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => TextConversation.fromFirestore(doc))
            .toList());
  }

  /// Stream of messages for a conversation, restricted to the ones the
  /// current member is allowed to see. Every message carries a
  /// `visibleToMemberIds` audience â€” all participants for a broadcast, or
  /// just the replier + thread creator for a direct-response reply â€” so the
  /// query (and the matching security rule) both enforce visibility.
  Stream<List<TextMessage>> watchMessages(String conversationId) {
    return _messagesRef(conversationId)
        .where('visibleToMemberIds', arrayContains: memberRef.id)
        .where('isDeleted', isEqualTo: false)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snap) =>
            snap.docs.map((doc) => TextMessage.fromFirestore(doc)).toList());
  }

  /// Fetch a single conversation by id.
  Future<TextConversation> getConversation(String conversationId) async {
    final doc = await _conversationsRef.doc(conversationId).get();
    return TextConversation.fromFirestore(doc);
  }

  /// Get or create a 1:1 conversation with another member.
  Future<TextConversation> getOrCreateDirectConversation({
    required DocumentReference<Map<String, dynamic>> otherMemberRef,
    required String otherMemberName,
  }) async {
    // Look for existing 1:1 conversation
    final existing = await _conversationsRef
        .where('participantRefs', arrayContains: memberRef)
        .where('isGroup', isEqualTo: false)
        .get();

    for (final doc in existing.docs) {
      final data = doc.data();
      final participants = (data['participantRefs'] as List<dynamic>? ?? [])
          .whereType<DocumentReference>()
          .map((r) => r.path)
          .toSet();
      if (participants.contains(otherMemberRef.path) &&
          participants.length == 2) {
        return TextConversation.fromFirestore(doc);
      }
    }

    // Create new conversation
    final payload = {
      'title': '',
      'participantRefs': [memberRef, otherMemberRef],
      'participantNames': [memberName, otherMemberName],
      'isGroup': false,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    final docRef = await _conversationsRef.add(payload);
    final doc = await docRef.get();
    return TextConversation.fromFirestore(doc);
  }

  /// Create a group conversation.
  Future<TextConversation> createGroupConversation({
    required String title,
    required List<DocumentReference<Map<String, dynamic>>> participantRefs,
    required List<String> participantNames,
    DocumentReference<Map<String, dynamic>>? teamRef,
    String? teamName,
  }) async {
    final allParticipants = [memberRef, ...participantRefs];
    final allNames = [memberName, ...participantNames];

    final payload = {
      'title': title,
      'participantRefs': allParticipants,
      'participantNames': allNames,
      'isGroup': true,
      if (teamRef != null) 'teamRef': teamRef,
      if (teamName != null) 'teamName': teamName,
      'createdBy': memberRef,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    final docRef = await _conversationsRef.add(payload);
    final doc = await docRef.get();
    return TextConversation.fromFirestore(doc);
  }

  /// Send a text message.
  ///
  /// [audienceMemberIds] is the full set of member IDs allowed to see the
  /// message â€” every participant for a normal broadcast, or just the replier
  /// + thread creator for a direct-response reply. It is always written to
  /// `visibleToMemberIds` so the message query and the security rule can
  /// enforce visibility server-side.
  ///
  /// [isDirectResponse] marks a private reply: its text is kept off the
  /// shared conversation preview and out of the company timeline so it is
  /// never exposed to the rest of the group.
  Future<TextMessage> sendMessage({
    required String conversationId,
    required String text,
    required List<String> audienceMemberIds,
    List<TextMessageAttachment> attachments = const [],
    bool isDirectResponse = false,
  }) async {
    final messagesRef = _messagesRef(conversationId);

    final payload = {
      'text': text,
      'senderRef': memberRef,
      'senderName': memberName,
      'createdAt': FieldValue.serverTimestamp(),
      'readByMemberIds': [memberRef.id],
      'attachments': attachments.map((a) => a.toMap()).toList(),
      'isDeleted': false,
      'visibleToMemberIds': audienceMemberIds,
    };

    final docRef = await messagesRef.add(payload);

    // Update the conversation preview. The conversation doc is visible to
    // every participant, so a direct-response reply writes a generic
    // placeholder instead of the real text and drops the sender name.
    await _conversationsRef.doc(conversationId).update({
      'lastMessageText': isDirectResponse ? 'Direct reply' : text,
      'lastMessageSenderName':
          isDirectResponse ? FieldValue.delete() : memberName,
      'lastMessageAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // The timeline is a company-wide feed â€” only broadcast messages belong
    // there. A direct-response reply stays private to the thread.
    if (!isDirectResponse) {
      await _createTimelineEntry(
        conversationId: conversationId,
        messageText: text,
      );
    }

    final doc = await docRef.get();
    return TextMessage.fromFirestore(doc);
  }

  /// Set the conversation's direct-response mode. When true, non-creator
  /// replies are written with `visibleToMemberIds` containing only the
  /// replier and the conversation creator.
  Future<void> setDirectResponseMode(String conversationId, bool value) async {
    await _conversationsRef.doc(conversationId).update({
      'directResponseMode': value,
    });
  }

  /// Update the current member's typing state on a conversation. Writes
  /// `typing.{memberId}` = serverTimestamp when [isTyping] is true, or
  /// deletes the entry when false. Receivers compare the timestamp to
  /// `now()` to render an indicator while it's fresh.
  Future<void> setTyping(String conversationId, bool isTyping) async {
    final field = 'typing.${memberRef.id}';
    try {
      await _conversationsRef.doc(conversationId).update({
        field: isTyping ? FieldValue.serverTimestamp() : FieldValue.delete(),
      });
    } catch (_) {
      // Best-effort: a typing ping should never surface to the UI.
    }
  }

  /// Mark every message the current member can see in a conversation as read.
  Future<void> markMessagesAsRead(String conversationId) async {
    // Scope the query to this member's audience â€” the security rule rejects
    // a list query that could return messages outside it. The unread filter
    // then runs client-side.
    final visibleMessages = await _messagesRef(conversationId)
        .where('visibleToMemberIds', arrayContains: memberRef.id)
        .get();

    final batch = FirebaseFirestore.instance.batch();
    var pending = 0;
    for (final doc in visibleMessages.docs) {
      final readBy = (doc.data()['readByMemberIds'] as List<dynamic>? ?? [])
          .whereType<String>();
      if (readBy.contains(memberRef.id)) continue;
      batch.update(doc.reference, {
        'readByMemberIds': FieldValue.arrayUnion([memberRef.id]),
      });
      pending++;
    }
    if (pending > 0) await batch.commit();
  }

  /// Delete a message (soft delete).
  Future<void> deleteMessage({
    required String conversationId,
    required String messageId,
  }) async {
    await _messagesRef(conversationId).doc(messageId).update({
      'isDeleted': true,
    });
  }

  /// Edit the text of a message. The security rule restricts this to the
  /// member who sent the message; `visibleToMemberIds` is left untouched so
  /// an edited reply keeps its original audience.
  ///
  /// Pass [previewText] when the edited message is the conversation's latest,
  /// to refresh the conversation-list preview. For a direct-response reply
  /// this must be a generic placeholder, never the real text.
  Future<void> editMessage({
    required String conversationId,
    required String messageId,
    required String newText,
    String? previewText,
  }) async {
    await _messagesRef(conversationId).doc(messageId).update({
      'text': newText,
      'editedAt': FieldValue.serverTimestamp(),
    });
    if (previewText != null) {
      await _conversationsRef.doc(conversationId).update({
        'lastMessageText': previewText,
      });
    }
  }

  /// Get unread count for a conversation (messages visible to this member).
  Future<int> getUnreadCount(String conversationId) async {
    // Scope to this member's audience so the security rule accepts the query;
    // `isDeleted` is filtered client-side to avoid a second composite index.
    final snap = await _messagesRef(conversationId)
        .where('visibleToMemberIds', arrayContains: memberRef.id)
        .get();

    int count = 0;
    for (final doc in snap.docs) {
      final data = doc.data();
      if (data['isDeleted'] == true) continue;
      final readBy = data['readByMemberIds'] as List<dynamic>? ?? [];
      final readByIds = readBy.map((e) {
        if (e is DocumentReference) return e.id;
        if (e is String) return e;
        return '';
      }).toSet();
      if (!readByIds.contains(memberRef.id)) count++;
    }
    return count;
  }

  /// Get total unread count across all conversations.
  Stream<int> watchTotalUnreadCount() {
    return watchConversations().asyncMap((conversations) async {
      int total = 0;
      for (final conv in conversations) {
        total += await getUnreadCount(conv.id);
      }
      return total;
    });
  }

  /// Create a timeline entry for the message.
  Future<void> _createTimelineEntry({
    required String conversationId,
    required String messageText,
  }) async {
    final timelineCategoryRef = FirebaseFirestore.instance
        .collection('timelineCategory')
        .doc(kTextMessageTimelineCategoryId);

    await companyRef.collection('timeline').add({
      'timelineCategory': kTextMessageTimelineCategoryId,
      'timelineCategoryId': timelineCategoryRef,
      'conversationId': conversationId,
      'message': messageText,
      'snippet': messageText.length > 100
          ? '${messageText.substring(0, 100)}...'
          : messageText,
      'createdAt': FieldValue.serverTimestamp(),
      'createdBy': memberRef,
      'createdByName': memberName,
      'memberId': memberRef,
    });
  }

  /// Sync file to file collection for a message attachment.
  Future<void> syncFileAttachment({
    required String conversationId,
    required String messageId,
    required TextMessageAttachment attachment,
  }) async {
    final messageRef = _messagesRef(conversationId).doc(messageId);

    await companyRef.collection('file').add({
      'textMessageId': messageRef,
      'conversationId': conversationId,
      'url': attachment.url,
      'fileUrl': attachment.url,
      'downloadUrl': attachment.url,
      if (attachment.thumbnailUrl != null)
        'thumbnailUrl': attachment.thumbnailUrl,
      if (attachment.fileName != null) 'fileName': attachment.fileName,
      if (attachment.mimeType != null) 'mimeType': attachment.mimeType,
      if (attachment.sizeBytes != null) 'sizeBytes': attachment.sizeBytes,
      'mediaType': attachment.type.name,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}

