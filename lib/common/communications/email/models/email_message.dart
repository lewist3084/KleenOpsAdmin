// lib/common/communications/email/models/email_message.dart
// Ported from the kleenops app — kept field-for-field identical so the same
// Firestore email docs (company/{cid}/member/{mid}/email) render in both apps.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'email_attachment.dart';

/// Represents an individual email message.
class EmailMessage {
  final String id;
  final DocumentReference<Map<String, dynamic>>? ref;

  /// RFC Message-ID header.
  final String messageId;

  /// Thread/conversation ID for grouping related emails.
  final String? threadId;

  /// In-Reply-To header for threading.
  final String? inReplyTo;

  /// Email subject line.
  final String subject;

  /// Sender email address.
  final String from;

  /// Sender display name.
  final String? fromName;

  /// Primary recipients.
  final List<String> to;

  /// CC recipients.
  final List<String> cc;

  /// BCC recipients (only for sent mail).
  final List<String> bcc;

  /// Plain text body.
  final String bodyPlain;

  /// HTML body.
  final String bodyHtml;

  /// Date received from server.
  final DateTime receivedAt;

  /// Date sent (from headers).
  final DateTime? sentAt;

  /// Read status.
  final bool isRead;

  /// Starred/flagged status.
  final bool isStarred;

  /// Draft status.
  final bool isDraft;

  /// Deleted/trash status.
  final bool isDeleted;

  /// Attachments.
  final List<EmailAttachment> attachments;

  /// IMAP folder (INBOX, Sent, Drafts, Trash, etc.).
  final String folder;

  /// IMAP UID for sync.
  final int? uid;

  /// Email account ID this message belongs to.
  final String accountId;

  /// Snippet/preview text.
  final String? snippet;

  /// AI-generated summary text.
  final String? emailSummary;

  /// AI-generated summary bullet points.
  final List<String> emailSummaryList;

  /// Whether the summary engine has processed this email.
  final String? emailSummaryEngine;

  /// AI-determined junk confidence (0.0 - 1.0).
  final double? junkConfidence;

  /// Whether AI flagged an action item in this email.
  final bool emailHasActionItem;

  /// AI-extracted name of the actual person who wrote the email (from the
  /// signature / content), e.g. "Angie Wells" even when the mailbox alias is
  /// "partners". Null when unknown.
  final String? emailSenderPerson;

  const EmailMessage({
    required this.id,
    this.ref,
    required this.messageId,
    this.threadId,
    this.inReplyTo,
    required this.subject,
    required this.from,
    this.fromName,
    this.to = const [],
    this.cc = const [],
    this.bcc = const [],
    this.bodyPlain = '',
    this.bodyHtml = '',
    required this.receivedAt,
    this.sentAt,
    this.isRead = false,
    this.isStarred = false,
    this.isDraft = false,
    this.isDeleted = false,
    this.attachments = const [],
    this.folder = 'INBOX',
    this.uid,
    required this.accountId,
    this.snippet,
    this.emailSummary,
    this.emailSummaryList = const [],
    this.emailSummaryEngine,
    this.junkConfidence,
    this.emailHasActionItem = false,
    this.emailSenderPerson,
  });

  factory EmailMessage.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    final receivedTs = data['receivedAt'] as Timestamp?;
    final sentTs = data['sentAt'] as Timestamp?;

    final rawAttachments = data['attachments'] as List<dynamic>? ?? [];
    final attachments = rawAttachments
        .whereType<Map<String, dynamic>>()
        .map((e) => EmailAttachment.fromMap(e))
        .toList();

    final rawTo = data['to'] as List<dynamic>? ?? [];
    final to = rawTo.whereType<String>().toList();

    final rawCc = data['cc'] as List<dynamic>? ?? [];
    final cc = rawCc.whereType<String>().toList();

    final rawBcc = data['bcc'] as List<dynamic>? ?? [];
    final bcc = rawBcc.whereType<String>().toList();

    return EmailMessage(
      id: doc.id,
      ref: doc.reference,
      messageId: (data['messageId'] as String?) ?? doc.id,
      threadId: data['threadId'] as String?,
      inReplyTo: data['inReplyTo'] as String?,
      subject: (data['subject'] as String?) ?? '(No subject)',
      from: (data['from'] as String?) ?? '',
      fromName: data['fromName'] as String?,
      to: to,
      cc: cc,
      bcc: bcc,
      bodyPlain: (data['bodyPlain'] as String?) ?? '',
      bodyHtml: (data['bodyHtml'] as String?) ?? '',
      receivedAt: receivedTs?.toDate() ?? DateTime.now(),
      sentAt: sentTs?.toDate(),
      isRead: data['isRead'] as bool? ?? false,
      isStarred: data['isStarred'] as bool? ?? false,
      isDraft: data['isDraft'] as bool? ?? false,
      isDeleted: data['isDeleted'] as bool? ?? false,
      attachments: attachments,
      folder: (data['folder'] as String?) ?? 'INBOX',
      uid: data['uid'] as int?,
      accountId: (data['accountId'] as String?) ?? '',
      snippet: data['snippet'] as String?,
      emailSummary: data['emailSummary'] as String?,
      emailSummaryList: (data['emailSummaryList'] as List<dynamic>?)
              ?.whereType<String>()
              .toList() ??
          const [],
      emailSummaryEngine: data['emailSummaryEngine'] as String?,
      junkConfidence: (data['junkConfidence'] as num?)?.toDouble(),
      emailHasActionItem: data['emailHasActionItem'] as bool? ?? false,
      emailSenderPerson: data['emailSenderPerson'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'messageId': messageId,
        if (threadId != null) 'threadId': threadId,
        if (inReplyTo != null) 'inReplyTo': inReplyTo,
        'subject': subject,
        'from': from,
        if (fromName != null) 'fromName': fromName,
        'to': to,
        'cc': cc,
        'bcc': bcc,
        'bodyPlain': bodyPlain,
        'bodyHtml': bodyHtml,
        'receivedAt': Timestamp.fromDate(receivedAt),
        if (sentAt != null) 'sentAt': Timestamp.fromDate(sentAt!),
        'isRead': isRead,
        'isStarred': isStarred,
        'isDraft': isDraft,
        'isDeleted': isDeleted,
        'attachments': attachments.map((a) => a.toMap()).toList(),
        'folder': folder,
        if (uid != null) 'uid': uid,
        'accountId': accountId,
        if (snippet != null) 'snippet': snippet,
        if (emailSummary != null) 'emailSummary': emailSummary,
        if (emailSummaryList.isNotEmpty) 'emailSummaryList': emailSummaryList,
        if (emailSummaryEngine != null) 'emailSummaryEngine': emailSummaryEngine,
        if (junkConfidence != null) 'junkConfidence': junkConfidence,
        'emailHasActionItem': emailHasActionItem,
        if (emailSenderPerson != null) 'emailSenderPerson': emailSenderPerson,
        'updatedAt': FieldValue.serverTimestamp(),
      };

  /// Create a copy with updated fields.
  EmailMessage copyWith({
    String? id,
    DocumentReference<Map<String, dynamic>>? ref,
    String? messageId,
    String? threadId,
    String? inReplyTo,
    String? subject,
    String? from,
    String? fromName,
    List<String>? to,
    List<String>? cc,
    List<String>? bcc,
    String? bodyPlain,
    String? bodyHtml,
    DateTime? receivedAt,
    DateTime? sentAt,
    bool? isRead,
    bool? isStarred,
    bool? isDraft,
    bool? isDeleted,
    List<EmailAttachment>? attachments,
    String? folder,
    int? uid,
    String? accountId,
    String? snippet,
    String? emailSummary,
    List<String>? emailSummaryList,
    String? emailSummaryEngine,
    double? junkConfidence,
    bool? emailHasActionItem,
    String? emailSenderPerson,
  }) {
    return EmailMessage(
      id: id ?? this.id,
      ref: ref ?? this.ref,
      messageId: messageId ?? this.messageId,
      threadId: threadId ?? this.threadId,
      inReplyTo: inReplyTo ?? this.inReplyTo,
      subject: subject ?? this.subject,
      from: from ?? this.from,
      fromName: fromName ?? this.fromName,
      to: to ?? this.to,
      cc: cc ?? this.cc,
      bcc: bcc ?? this.bcc,
      bodyPlain: bodyPlain ?? this.bodyPlain,
      bodyHtml: bodyHtml ?? this.bodyHtml,
      receivedAt: receivedAt ?? this.receivedAt,
      sentAt: sentAt ?? this.sentAt,
      isRead: isRead ?? this.isRead,
      isStarred: isStarred ?? this.isStarred,
      isDraft: isDraft ?? this.isDraft,
      isDeleted: isDeleted ?? this.isDeleted,
      attachments: attachments ?? this.attachments,
      folder: folder ?? this.folder,
      uid: uid ?? this.uid,
      accountId: accountId ?? this.accountId,
      snippet: snippet ?? this.snippet,
      emailSummary: emailSummary ?? this.emailSummary,
      emailSummaryList: emailSummaryList ?? this.emailSummaryList,
      emailSummaryEngine: emailSummaryEngine ?? this.emailSummaryEngine,
      junkConfidence: junkConfidence ?? this.junkConfidence,
      emailHasActionItem: emailHasActionItem ?? this.emailHasActionItem,
      emailSenderPerson: emailSenderPerson ?? this.emailSenderPerson,
    );
  }

  /// Get display name for sender.
  String get senderDisplayName => fromName ?? from.split('@').first;

  /// Check if email has attachments.
  bool get hasAttachments => attachments.isNotEmpty;

  /// Get non-inline attachments.
  List<EmailAttachment> get nonInlineAttachments =>
      attachments.where((a) => !a.isInline).toList();

  /// Get preview text (snippet or first part of body).
  String get preview {
    if (snippet != null && snippet!.isNotEmpty) return snippet!;
    if (bodyPlain.isNotEmpty) {
      return bodyPlain.length > 150
          ? '${bodyPlain.substring(0, 150)}...'
          : bodyPlain;
    }
    return '';
  }

  /// Best available one-line gist for list display: the AI summary if it is
  /// ready, otherwise the raw preview once analysis has finished. Returns null
  /// while the summary is still being generated (so callers can show a
  /// "Generating summary…" placeholder).
  String? get displaySummary {
    if (emailSummary != null && emailSummary!.isNotEmpty) return emailSummary;
    if (emailSummaryEngine != null) {
      return preview.isNotEmpty ? preview : null;
    }
    return null;
  }

  /// True while the AI summary has not yet been generated (engine unset).
  bool get isSummaryPending => emailSummaryEngine == null;
}
