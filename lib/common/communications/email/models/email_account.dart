// lib/common/communications/email/models/email_account.dart
// Ported from the kleenops app. Storage: company/{cid}/emailAddress/{docId}.

import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a KleenOps-hosted email mailbox.
///
/// Inbound mail is delivered by the SendGrid webhook into
/// `company/{companyId}/member/{memberId}/email/{docId}` for each member in
/// `memberUids`. If `memberUids` is empty, the address is a shared inbox and
/// all active company members receive the message.
class EmailAccount {
  final String id;
  final DocumentReference<Map<String, dynamic>>? ref;

  /// The full email address, e.g. `tlewis@kleenops.com`.
  final String emailAddress;

  /// Display name for outgoing mail.
  final String displayName;

  /// Member UIDs that own this mailbox. Empty list = shared inbox.
  final List<String> memberUids;

  /// Whether this is flagged as the user's primary mailbox.
  final bool isPrimary;

  /// `active` | `deleted` | `pending`.
  final String status;

  final DateTime? createdAt;

  const EmailAccount({
    required this.id,
    this.ref,
    required this.emailAddress,
    this.displayName = '',
    this.memberUids = const [],
    this.isPrimary = false,
    this.status = 'active',
    this.createdAt,
  });

  bool get isActive => status == 'active';
  bool get isShared => memberUids.isEmpty;

  factory EmailAccount.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    final memberUidsRaw = data['memberUids'] as List<dynamic>? ?? const [];
    final createdTs = data['createdAt'] as Timestamp?;
    final addr = (data['address'] as String?) ?? '';
    final label = data['label'] as String?;
    return EmailAccount(
      id: doc.id,
      ref: doc.reference,
      emailAddress: addr.toLowerCase(),
      displayName: (data['displayName'] as String?) ?? label ?? '',
      memberUids: memberUidsRaw.whereType<String>().toList(),
      isPrimary: data['isPrimary'] as bool? ?? false,
      status: (data['status'] as String?) ?? 'active',
      createdAt: createdTs?.toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
        'address': emailAddress,
        'displayName': displayName,
        'memberUids': memberUids,
        'isPrimary': isPrimary,
        'status': status,
        if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
        'updatedAt': FieldValue.serverTimestamp(),
      };

  EmailAccount copyWith({
    String? id,
    DocumentReference<Map<String, dynamic>>? ref,
    String? emailAddress,
    String? displayName,
    List<String>? memberUids,
    bool? isPrimary,
    String? status,
    DateTime? createdAt,
  }) {
    return EmailAccount(
      id: id ?? this.id,
      ref: ref ?? this.ref,
      emailAddress: emailAddress ?? this.emailAddress,
      displayName: displayName ?? this.displayName,
      memberUids: memberUids ?? this.memberUids,
      isPrimary: isPrimary ?? this.isPrimary,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
