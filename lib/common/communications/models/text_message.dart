// Mirrors kleenops TextMessage model for admin app.
import 'package:cloud_firestore/cloud_firestore.dart';

class TextMessage {
  final String id;
  final DocumentReference<Map<String, dynamic>> ref;
  final String text;
  final DocumentReference<Map<String, dynamic>>? senderRef;
  final String senderName;
  final DateTime createdAt;
  final List<String> readByMemberIds;
  final bool isDeleted;

  const TextMessage({
    required this.id,
    required this.ref,
    required this.text,
    this.senderRef,
    required this.senderName,
    required this.createdAt,
    this.readByMemberIds = const [],
    this.isDeleted = false,
  });

  factory TextMessage.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final d = doc.data() ?? {};
    final ts = d['createdAt'] as Timestamp?;
    return TextMessage(
      id: doc.id,
      ref: doc.reference,
      text: (d['text'] as String?) ?? '',
      senderRef: d['senderRef'] as DocumentReference<Map<String, dynamic>>?,
      senderName: (d['senderName'] as String?) ?? '',
      createdAt: ts?.toDate() ?? DateTime.now(),
      readByMemberIds:
          (d['readByMemberIds'] as List<dynamic>? ?? []).whereType<String>().toList(),
      isDeleted: d['isDeleted'] as bool? ?? false,
    );
  }
}
