// lib/features/directory/providers/directory_providers.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod/legacy.dart';
import 'package:kleenops_admin/features/auth/providers/auth_provider.dart';

import '../../../common/communications/email/models/email_message.dart';
import '../models/external_contact.dart';
import '../models/organization.dart';
import '../services/directory_service.dart';

final directoryServiceProvider =
    Provider<DirectoryService>((_) => const DirectoryService());

/// All organizations (any status), newest-activity first. Small collection, so
/// we stream it whole and split active/suggested client-side — avoids a
/// status+lastActivityAt composite index.
final _allOrganizationsProvider =
    StreamProvider.autoDispose<List<Organization>>((ref) {
  final companyRef = ref.watch(companyIdProvider).value;
  if (companyRef == null) return Stream.value(const []);
  return companyRef
      .collection('organization')
      .orderBy('lastActivityAt', descending: true)
      .limit(300)
      .snapshots()
      .map((s) => s.docs.map(Organization.fromFirestore).toList());
});

/// Confirmed organizations.
final organizationsProvider = Provider.autoDispose<List<Organization>>((ref) {
  final all = ref.watch(_allOrganizationsProvider).value ?? const [];
  return all.where((o) => o.status == 'active').toList();
});

/// Organizations awaiting confirmation.
final suggestedOrganizationsProvider =
    Provider.autoDispose<List<Organization>>((ref) {
  final all = ref.watch(_allOrganizationsProvider).value ?? const [];
  return all.where((o) => o.status == 'suggested').toList();
});

final _allContactsProvider =
    StreamProvider.autoDispose<List<ExternalContact>>((ref) {
  final companyRef = ref.watch(companyIdProvider).value;
  if (companyRef == null) return Stream.value(const []);
  return companyRef
      .collection('externalContact')
      .orderBy('lastActivityAt', descending: true)
      .limit(300)
      .snapshots()
      .map((s) => s.docs.map(ExternalContact.fromFirestore).toList());
});

/// A contact is visible to the signed-in member when it's shared company-wide,
/// has no owners (legacy/global), or lists the member as an owner.
bool _contactVisible(ExternalContact c, String? myMemberId) {
  if (c.shared || c.ownerMemberIds.isEmpty) return true;
  return myMemberId != null && c.ownerMemberIds.contains(myMemberId);
}

/// Confirmed external contacts visible to the signed-in member.
final externalContactsProvider =
    Provider.autoDispose<List<ExternalContact>>((ref) {
  final all = ref.watch(_allContactsProvider).value ?? const [];
  final me = ref.watch(memberDocRefProvider).value?.id;
  return all
      .where((c) => c.status == 'active' && _contactVisible(c, me))
      .toList();
});

/// External contacts awaiting confirmation (visible to the member).
final suggestedContactsProvider =
    Provider.autoDispose<List<ExternalContact>>((ref) {
  final all = ref.watch(_allContactsProvider).value ?? const [];
  final me = ref.watch(memberDocRefProvider).value?.id;
  return all
      .where((c) => c.status == 'suggested' && _contactVisible(c, me))
      .toList();
});

/// People-directory filter (initial view shows all).
enum DirectoryPeopleFilter { all, internal, external }

final directoryPeopleFilterProvider =
    StateProvider.autoDispose<DirectoryPeopleFilter>(
        (_) => DirectoryPeopleFilter.all);

/// Active internal staff (member docs), for the unified People list.
final companyMembersProvider =
    StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  final companyRef = ref.watch(companyIdProvider).value;
  if (companyRef == null) return Stream.value(const []);
  return companyRef
      .collection('member')
      .where('active', isEqualTo: true)
      .snapshots()
      .map((s) => s.docs.map((d) => {'id': d.id, ...d.data()}).toList());
});

/// External contacts linked to an organization (the people there), visible to
/// the signed-in member. Excludes dismissed.
final contactsForOrgProvider =
    Provider.autoDispose.family<List<ExternalContact>, String>((ref, orgId) {
  final all = ref.watch(_allContactsProvider).value ?? const [];
  final me = ref.watch(memberDocRefProvider).value?.id;
  return all
      .where((c) =>
          c.organizationId == orgId &&
          c.status != 'dismissed' &&
          _contactVisible(c, me))
      .toList()
    ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
});

/// Single organization by id.
final organizationByIdProvider = StreamProvider.autoDispose
    .family<Organization?, String>((ref, orgId) {
  final companyRef = ref.watch(companyIdProvider).value;
  if (companyRef == null) return Stream.value(null);
  return companyRef
      .collection('organization')
      .doc(orgId)
      .snapshots()
      .map((d) => d.exists ? Organization.fromFirestore(d) : null);
});

final externalContactByIdProvider = StreamProvider.autoDispose
    .family<ExternalContact?, String>((ref, contactId) {
  final companyRef = ref.watch(companyIdProvider).value;
  if (companyRef == null) return Stream.value(null);
  return companyRef
      .collection('externalContact')
      .doc(contactId)
      .snapshots()
      .map((d) => d.exists ? ExternalContact.fromFirestore(d) : null);
});

/// Signed-in member's own emails stamped with a directory entity's id — their
/// inbox/sent/archived copies (openable, with read state).
final _memberEntityEmailsProvider = StreamProvider.autoDispose
    .family<List<EmailMessage>, ({String field, String id})>((ref, key) {
  final memberRef = ref.watch(memberDocRefProvider).value;
  if (memberRef == null) return Stream.value(const []);
  return memberRef
      .collection('email')
      .where(key.field, isEqualTo: key.id)
      .snapshots()
      .map((s) => s.docs.map(EmailMessage.fromFirestore).toList());
});

/// Company-wide inbound log stamped with the entity's id — one doc per inbound
/// email, covering every member's correspondence with this org/contact.
final _entityEmailLogProvider = StreamProvider.autoDispose
    .family<List<EmailMessage>, ({String field, String id})>((ref, key) {
  final companyRef = ref.watch(companyIdProvider).value;
  if (companyRef == null) return Stream.value(const []);
  return companyRef
      .collection('emailLog')
      .where(key.field, isEqualTo: key.id)
      .snapshots()
      .map((s) => s.docs.map(EmailMessage.fromFirestore).toList());
});

/// Company-wide communication feed for a directory entity: the shared inbound
/// log merged with the signed-in member's own copies, deduped by messageId
/// (the member's doc wins so it stays openable + carries read state), newest
/// first. Colleague-only emails come from the log and open read-only.
///
/// Note: outbound mail by *other* members isn't in emailLog yet, so their sent
/// replies aren't shown — that's the remaining follow-up.
final entityCommunicationsProvider = Provider.autoDispose
    .family<List<EmailMessage>, ({String field, String id})>((ref, key) {
  final mine = ref.watch(_memberEntityEmailsProvider(key)).value ?? const [];
  final log = ref.watch(_entityEmailLogProvider(key)).value ?? const [];
  final byMessageId = <String, EmailMessage>{};
  // Log first, then member copies overwrite (member doc is openable).
  for (final e in log) {
    byMessageId[e.messageId] = e;
  }
  for (final e in mine) {
    byMessageId[e.messageId] = e;
  }
  final list = byMessageId.values.toList()
    ..sort((a, b) => b.receivedAt.compareTo(a.receivedAt));
  return list;
});

/// True while either underlying source is still loading (for a spinner).
final entityCommunicationsLoadingProvider = Provider.autoDispose
    .family<bool, ({String field, String id})>((ref, key) {
  return ref.watch(_memberEntityEmailsProvider(key)).isLoading ||
      ref.watch(_entityEmailLogProvider(key)).isLoading;
});

/// Notes on an entity's timeline subcollection (org or contact), newest first.
final entityNotesProvider = StreamProvider.autoDispose
    .family<List<DirectoryNote>, ({String collection, String id})>((ref, key) {
  final companyRef = ref.watch(companyIdProvider).value;
  if (companyRef == null) return Stream.value(const []);
  return companyRef
      .collection(key.collection)
      .doc(key.id)
      .collection('timeline')
      .where('type', isEqualTo: 'note')
      .snapshots()
      .map((s) {
    final notes = s.docs.map(DirectoryNote.fromDoc).toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return notes;
  });
});

/// A note on an org/contact timeline.
class DirectoryNote {
  final String id;
  final String text;
  final DateTime timestamp;
  final String byName;
  const DirectoryNote({
    required this.id,
    required this.text,
    required this.timestamp,
    required this.byName,
  });

  factory DirectoryNote.fromDoc(dynamic doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    return DirectoryNote(
      id: doc.id as String,
      text: (data['text'] as String?) ?? '',
      timestamp:
          (data['timestamp'] as dynamic)?.toDate() as DateTime? ?? DateTime(2000),
      byName: (data['createdByName'] as String?) ?? '',
    );
  }
}
