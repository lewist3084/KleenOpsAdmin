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

  /// A short human description of what the company is (user-editable).
  final String? description;

  /// Email domains owned by this org (e.g. ['alibaba.com']).
  final List<String> domains;

  /// Known phone numbers (E.164).
  final List<String> phones;

  /// Public websites (e.g. ['https://acme.com']).
  final List<String> websites;

  /// Physical locations. Each map: {label, address, city, state, postalCode,
  /// country, phone}.
  final List<Map<String, dynamic>> locations;

  /// Lightweight people at the org, stored on the doc (distinct from the
  /// `externalContact` collection). Each map: {name, email, phone, title}.
  final List<Map<String, dynamic>> contacts;

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
    this.description,
    this.domains = const [],
    this.phones = const [],
    this.websites = const [],
    this.locations = const [],
    this.contacts = const [],
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
      description: (data['description'] as String?)?.trim().isNotEmpty == true
          ? (data['description'] as String).trim()
          : null,
      domains: (data['domains'] as List<dynamic>?)
              ?.whereType<String>()
              .toList() ??
          const [],
      phones:
          (data['phones'] as List<dynamic>?)?.whereType<String>().toList() ??
              const [],
      websites:
          (data['websites'] as List<dynamic>?)?.whereType<String>().toList() ??
              const [],
      locations: (data['locations'] as List<dynamic>?)
              ?.whereType<Map>()
              .map((m) => Map<String, dynamic>.from(m))
              .toList() ??
          const [],
      contacts: (data['contacts'] as List<dynamic>?)
              ?.whereType<Map>()
              .map((m) => Map<String, dynamic>.from(m))
              .toList() ??
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
        if (description != null) 'description': description,
        'domains': domains,
        'phones': phones,
        'websites': websites,
        'locations': locations,
        'contacts': contacts,
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
