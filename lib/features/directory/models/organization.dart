// lib/features/directory/models/organization.dart

import 'package:cloud_firestore/cloud_firestore.dart';

/// An external organization we communicate with (by email domain). Tracked
/// member-like under `company/{cid}/organization/{orgId}` with a `timeline`
/// subcollection for notes/logged calls. Communications are linked by stamping
/// `organizationId` on email docs.
class Organization {
  final String id;
  final DocumentReference<Map<String, dynamic>>? ref;
  final String name;

  /// Email domains owned by this org (e.g. ['alibaba.com']).
  final List<String> domains;

  /// Known phone numbers (E.164).
  final List<String> phones;

  /// 'active' (confirmed), 'suggested' (awaiting confirmation), 'dismissed',
  /// or 'archived'.
  final String status;

  /// How it was created: 'archive' (user archived mail), 'auto' (inbound
  /// classifier), or 'manual'.
  final String source;

  final DateTime? createdAt;
  final DateTime? lastActivityAt;
  final int emailCount;

  /// Stable seed for the avatar colour.
  final int colorSeed;

  const Organization({
    required this.id,
    this.ref,
    required this.name,
    this.domains = const [],
    this.phones = const [],
    this.status = 'active',
    this.source = 'manual',
    this.createdAt,
    this.lastActivityAt,
    this.emailCount = 0,
    this.colorSeed = 0,
  });

  bool get isSuggested => status == 'suggested';

  factory Organization.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    return Organization(
      id: doc.id,
      ref: doc.reference,
      name: (data['name'] as String?)?.trim().isNotEmpty == true
          ? (data['name'] as String).trim()
          : 'Unknown',
      domains: (data['domains'] as List<dynamic>?)
              ?.whereType<String>()
              .toList() ??
          const [],
      phones:
          (data['phones'] as List<dynamic>?)?.whereType<String>().toList() ??
              const [],
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
        'domains': domains,
        'phones': phones,
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
