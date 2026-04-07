// Firestore-based texting service for admin app.
// Mirrors the kleenops TextingService operating on the same collections.
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/text_conversation.dart';
import '../models/text_message.dart';

class TextingService {
  final DocumentReference<Map<String, dynamic>> companyRef;
  final DocumentReference<Map<String, dynamic>> memberRef;
  final String memberName;

  TextingService({
    required this.companyRef,
    required this.memberRef,
    required this.memberName,
  });

  CollectionReference<Map<String, dynamic>> get _convRef =>
      companyRef.collection('textConversation');

  Stream<List<TextConversation>> watchConversations() {
    return _convRef
        .where('participantRefs', arrayContains: memberRef)
        .orderBy('lastMessageAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => TextConversation.fromFirestore(doc))
            .toList());
  }

  Stream<List<TextMessage>> watchMessages(String conversationId) {
    return _convRef
        .doc(conversationId)
        .collection('message')
        .where('isDeleted', isEqualTo: false)
        .orderBy('createdAt')
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => TextMessage.fromFirestore(doc))
            .toList());
  }

  Future<TextConversation> getOrCreateDirectConversation({
    required DocumentReference<Map<String, dynamic>> otherMemberRef,
    required String otherMemberName,
  }) async {
    final existing = await _convRef
        .where('participantRefs', arrayContains: memberRef)
        .where('isGroup', isEqualTo: false)
        .get();

    for (final doc in existing.docs) {
      final refs = (doc.data()['participantRefs'] as List<dynamic>? ?? [])
          .whereType<DocumentReference>();
      if (refs.any((r) => r.path == otherMemberRef.path)) {
        return TextConversation.fromFirestore(doc);
      }
    }

    final docRef = await _convRef.add({
      'title': '',
      'participantRefs': [memberRef, otherMemberRef],
      'participantNames': [memberName, otherMemberName],
      'isGroup': false,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    final doc = await docRef.get();
    return TextConversation.fromFirestore(doc);
  }

  Future<TextMessage> sendMessage({
    required String conversationId,
    required String text,
  }) async {
    final msgRef = await _convRef
        .doc(conversationId)
        .collection('message')
        .add({
      'text': text,
      'senderRef': memberRef,
      'senderName': memberName,
      'createdAt': FieldValue.serverTimestamp(),
      'readByMemberIds': [memberRef.id],
      'isDeleted': false,
    });

    await _convRef.doc(conversationId).update({
      'lastMessageText': text,
      'lastMessageSenderName': memberName,
      'lastMessageAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    final doc = await msgRef.get();
    return TextMessage.fromFirestore(doc);
  }

  Future<void> markMessagesAsRead(String conversationId) async {
    final unread = await _convRef
        .doc(conversationId)
        .collection('message')
        .where('isDeleted', isEqualTo: false)
        .get();

    final batch = FirebaseFirestore.instance.batch();
    for (final doc in unread.docs) {
      final readBy =
          (doc.data()['readByMemberIds'] as List<dynamic>? ?? []).cast<String>();
      if (!readBy.contains(memberRef.id)) {
        batch.update(doc.reference, {
          'readByMemberIds': FieldValue.arrayUnion([memberRef.id]),
        });
      }
    }
    await batch.commit();
  }
}
