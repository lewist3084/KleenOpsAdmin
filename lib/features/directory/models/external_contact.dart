// lib/features/directory/models/external_contact.dart

import 'package:cloud_firestore/cloud_firestore.dart';

/// An external individual we communicate with (by email address — typically a
/// personal/free-mail domain). Tracked under `company/{cid}/externalContact/
/// {id}` with a `timeline` subcollection for notes. Communications are linked
/// by stamping `externalContactId` on email docs.
class ExternalContact {
  final String id;
  final DocumentReference<Map<String, dynamic>>? ref;
  final String name;

  /// Known email addresses for this person.
  final List<String> emails;

  /// Known phone numbers (E.164).
  final List<String> phones;

  /// Optional link to an [Organization] this person belongs to.
  final String? organizationId;

  /// Member ids who "own" this contact (added it / correspond with them). A
  /// contact is visible to its owners; empty is treated as legacy/global.
  final List<String> ownerMemberIds;

  /// When true the contact is visible company-wide regardless of [ownerMemberIds].
  final bool shared;

  /// 'active', 'suggested', 'dismissed', or 'archived'.
  final String status;

  /// 'archive', 'auto', or 'manual'.
  final String source;

  final DateTime? createdAt;
  final DateTime? lastActivityAt;
  final int emailCount;
  final int colorSeed;

  const ExternalContact({
    required this.id,
    this.ref,
    required this.name,
    this.emails = const [],
    this.phones = const [],
    this.organizationId,
    this.ownerMemberIds = const [],
    this.shared = false,
    this.status = 'active',
    this.source = 'manual',
    this.createdAt,
    this.lastActivityAt,
    this.emailCount = 0,
    this.colorSeed = 0,
  });

  bool get isSuggested => status == 'suggested';

  factory ExternalContact.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    return ExternalContact(
      id: doc.id,
      ref: doc.reference,
      name: (data['name'] as String?)?.trim().isNotEmpty == true
          ? (data['name'] as String).trim()
          : 'Unknown',
      emails:
          (data['emails'] as List<dynamic>?)?.whereType<String>().toList() ??
              const [],
      phones:
          (data['phones'] as List<dynamic>?)?.whereType<String>().toList() ??
              const [],
      organizationId: data['organizationId'] as String?,
      ownerMemberIds: (data['ownerMemberIds'] as List<dynamic>?)
              ?.whereType<String>()
              .toList() ??
          const [],
      shared: data['shared'] as bool? ?? false,
      status: (data['status'] as String?) ?? 'active',
      source: (data['source'] as String?) ?? 'manual',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      lastActivityAt: (data['lastActivityAt'] as Timestamp?)?.toDate(),
      emailCount: (data['emailCount'] as num?)?.toInt() ?? 0,
      colorSeed: (data['colorSeed'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'emails': emails,
        'phones': phones,
        if (organizationId != null) 'organizationId': organizationId,
        'ownerMemberIds': ownerMemberIds,
        'shared': shared,
        'status': status,
        'source': source,
        if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
        if (lastActivityAt != null)
          'lastActivityAt': Timestamp.fromDate(lastActivityAt!),
        'emailCount': emailCount,
        'colorSeed': colorSeed,
        'updatedAt': FieldValue.serverTimestamp(),
      };
}
