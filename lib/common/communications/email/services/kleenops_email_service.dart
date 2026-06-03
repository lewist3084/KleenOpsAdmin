import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

/// Email service for KleenOps-hosted email accounts (Cloudflare + SendGrid).
///
/// Ported verbatim from the kleenops app. Sending goes through the shared
/// `emailSend` Cloud Function; reading streams from the same Firestore
/// structure (`company/{cid}/member/{mid}/email`) that the kleenops app uses,
/// so both apps operate on one mailbox.
class KleenopsEmailService {
  KleenopsEmailService._();
  static final instance = KleenopsEmailService._();

  final _functions = FirebaseFunctions.instance;

  /// Send an email via SendGrid through the KleenOps backend.
  Future<Map<String, dynamic>> send({
    required String companyId,
    required String fromAddress,
    String? fromName,
    required List<String> to,
    List<String>? cc,
    List<String>? bcc,
    required String subject,
    String? bodyPlain,
    String? bodyHtml,
    String? inReplyTo,
    List<Map<String, dynamic>>? attachments,
  }) async {
    final callable = _functions.httpsCallable('emailSend');
    final result = await callable.call<Map<String, dynamic>>({
      'companyId': companyId,
      'fromAddress': fromAddress,
      'fromName': fromName,
      'to': to,
      'cc': cc,
      'bcc': bcc,
      'subject': subject,
      'bodyPlain': bodyPlain,
      'bodyHtml': bodyHtml,
      'inReplyTo': inReplyTo,
      'attachments': attachments,
    });
    return Map<String, dynamic>.from(result.data);
  }

  /// Set up SendGrid Inbound Parse for a domain.
  Future<void> setupInboundParse({
    required String companyId,
    required String domainDocId,
  }) async {
    final callable = _functions.httpsCallable('emailSetupInboundParse');
    await callable.call({
      'companyId': companyId,
      'domainDocId': domainDocId,
    });
  }

  /// Watch inbox emails for a member.
  Stream<QuerySnapshot<Map<String, dynamic>>> watchInbox({
    required DocumentReference<Map<String, dynamic>> companyRef,
    required String memberId,
    required String accountId,
    int limit = 50,
  }) {
    return companyRef
        .collection('member')
        .doc(memberId)
        .collection('email')
        .where('accountId', isEqualTo: accountId)
        .where('folder', isEqualTo: 'INBOX')
        .where('isDeleted', isEqualTo: false)
        .orderBy('receivedAt', descending: true)
        .limit(limit)
        .snapshots();
  }

  /// Watch sent emails for a member.
  Stream<QuerySnapshot<Map<String, dynamic>>> watchSent({
    required DocumentReference<Map<String, dynamic>> companyRef,
    required String memberId,
    required String accountId,
    int limit = 50,
  }) {
    return companyRef
        .collection('member')
        .doc(memberId)
        .collection('email')
        .where('accountId', isEqualTo: accountId)
        .where('folder', isEqualTo: 'Sent')
        .orderBy('receivedAt', descending: true)
        .limit(limit)
        .snapshots();
  }

  /// Watch trashed emails for a member (manual trash + AI-flagged junk).
  Stream<QuerySnapshot<Map<String, dynamic>>> watchTrash({
    required DocumentReference<Map<String, dynamic>> companyRef,
    required String memberId,
    required String accountId,
    int limit = 50,
  }) {
    return companyRef
        .collection('member')
        .doc(memberId)
        .collection('email')
        .where('accountId', isEqualTo: accountId)
        .where('folder', isEqualTo: 'Trash')
        .where('isDeleted', isEqualTo: true)
        .orderBy('receivedAt', descending: true)
        .limit(limit)
        .snapshots();
  }

  /// Mark an email as read.
  Future<void> markAsRead(DocumentReference<Map<String, dynamic>> emailRef) {
    return emailRef
        .update({'isRead': true, 'updatedAt': FieldValue.serverTimestamp()});
  }

  /// Toggle star on an email.
  Future<void> toggleStar(
      DocumentReference<Map<String, dynamic>> emailRef, bool starred) {
    return emailRef.update(
        {'isStarred': starred, 'updatedAt': FieldValue.serverTimestamp()});
  }

  /// Move an email to trash.
  Future<void> moveToTrash(DocumentReference<Map<String, dynamic>> emailRef) {
    return emailRef.update({
      'isDeleted': true,
      'folder': 'Trash',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Restore a trashed/junked/archived email back to the inbox.
  Future<void> restoreToInbox(
      DocumentReference<Map<String, dynamic>> emailRef) {
    return emailRef.update({
      'isDeleted': false,
      'folder': 'INBOX',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Archive an email — moves it out of the inbox into the 'Archive' folder.
  Future<void> archive(DocumentReference<Map<String, dynamic>> emailRef) {
    return emailRef.update({
      'isDeleted': false,
      'folder': 'Archive',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Permanently delete an email document (empties it from Trash).
  Future<void> deleteForever(
      DocumentReference<Map<String, dynamic>> emailRef) {
    return emailRef.delete();
  }
}
