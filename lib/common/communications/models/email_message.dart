// Mirrors kleenops EmailMessage model for admin app.
import 'package:cloud_firestore/cloud_firestore.dart';

class EmailMessage {
  final String id;
  final DocumentReference<Map<String, dynamic>>? ref;
  final String messageId;
  final String subject;
  final String from;
  final String? fromName;
  final List<String> to;
  final String bodyPlain;
  final String bodyHtml;
  final DateTime receivedAt;
  final bool isRead;
  final bool isStarred;
  final bool isDeleted;
  final String folder;
  final int? uid;
  final String accountId;
  final String? snippet;
  final String? emailSummary;
  final double? junkConfidence;
  final bool emailHasActionItem;

  const EmailMessage({
    required this.id,
    this.ref,
    required this.messageId,
    required this.subject,
    required this.from,
    this.fromName,
    this.to = const [],
    this.bodyPlain = '',
    this.bodyHtml = '',
    required this.receivedAt,
    this.isRead = false,
    this.isStarred = false,
    this.isDeleted = false,
    this.folder = 'INBOX',
    this.uid,
    required this.accountId,
    this.snippet,
    this.emailSummary,
    this.junkConfidence,
    this.emailHasActionItem = false,
  });

  factory EmailMessage.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    final receivedTs = d['receivedAt'] as Timestamp?;
    return EmailMessage(
      id: doc.id,
      ref: doc.reference,
      messageId: (d['messageId'] as String?) ?? doc.id,
      subject: (d['subject'] as String?) ?? '(No subject)',
      from: (d['from'] as String?) ?? '',
      fromName: d['fromName'] as String?,
      to: (d['to'] as List<dynamic>? ?? []).whereType<String>().toList(),
      bodyPlain: (d['bodyPlain'] as String?) ?? '',
      bodyHtml: (d['bodyHtml'] as String?) ?? '',
      receivedAt: receivedTs?.toDate() ?? DateTime.now(),
      isRead: d['isRead'] as bool? ?? false,
      isStarred: d['isStarred'] as bool? ?? false,
      isDeleted: d['isDeleted'] as bool? ?? false,
      folder: (d['folder'] as String?) ?? 'INBOX',
      uid: d['uid'] as int?,
      accountId: (d['accountId'] as String?) ?? '',
      snippet: d['snippet'] as String?,
      emailSummary: d['emailSummary'] as String?,
      junkConfidence: (d['junkConfidence'] as num?)?.toDouble(),
      emailHasActionItem: d['emailHasActionItem'] as bool? ?? false,
    );
  }

  String get senderDisplayName => fromName ?? from.split('@').first;

  String get preview {
    if (snippet != null && snippet!.isNotEmpty) return snippet!;
    if (bodyPlain.isNotEmpty) {
      return bodyPlain.length > 150 ? '${bodyPlain.substring(0, 150)}...' : bodyPlain;
    }
    return '';
  }
}
