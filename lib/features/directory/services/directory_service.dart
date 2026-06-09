// lib/features/directory/services/directory_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../common/communications/email/models/email_message.dart';
import '../utils/directory_classifier.dart';

// Note: all reads/writes are scoped under the passed-in companyRef, so the
// service holds no Firestore handle of its own.

/// Resolved directory party for a communication: an organization (business
/// domain) or an external contact (personal/free-mail individual).
class ResolvedParty {
  final String? organizationId;
  final String? externalContactId;
  const ResolvedParty({this.organizationId, this.externalContactId});
  bool get isEmpty => organizationId == null && externalContactId == null;
}

/// Creates/links external organizations and contacts and their communications.
class DirectoryService {
  const DirectoryService();

  CollectionReference<Map<String, dynamic>> _orgs(
          DocumentReference<Map<String, dynamic>> companyRef) =>
      companyRef.collection('organization');

  CollectionReference<Map<String, dynamic>> _contacts(
          DocumentReference<Map<String, dynamic>> companyRef) =>
      companyRef.collection('externalContact');

  /// Find an org by [domain], or create one. Returns its id. If it existed as a
  /// suggestion and we're acting explicitly (e.g. archiving), promote it to
  /// active.
  Future<String> findOrCreateOrg(
    DocumentReference<Map<String, dynamic>> companyRef,
    String domain, {
    String? name,
    String status = 'active',
    String source = 'archive',
  }) async {
    final existing = await _orgs(companyRef)
        .where('domains', arrayContains: domain)
        .limit(1)
        .get();
    if (existing.docs.isNotEmpty) {
      final doc = existing.docs.first;
      final updates = <String, dynamic>{
        'lastActivityAt': FieldValue.serverTimestamp(),
        'emailCount': FieldValue.increment(1),
      };
      if (status == 'active' && doc.data()['status'] == 'suggested') {
        updates['status'] = 'active';
      }
      await doc.reference.set(updates, SetOptions(merge: true));
      return doc.id;
    }
    final ref = await _orgs(companyRef).add({
      'name': (name != null && name.trim().isNotEmpty)
          ? name.trim()
          : orgNameFromDomain(domain),
      'domains': [domain],
      'phones': <String>[],
      'status': status,
      'source': source,
      'createdAt': FieldValue.serverTimestamp(),
      'lastActivityAt': FieldValue.serverTimestamp(),
      'emailCount': 1,
      'colorSeed': domain.hashCode.abs(),
    });
    return ref.id;
  }

  /// Find a contact by [email], or create one. Returns its id. When
  /// [organizationId] is given, the contact is linked to that org (backfilled
  /// on an existing contact that has none).
  Future<String> findOrCreateContact(
    DocumentReference<Map<String, dynamic>> companyRef,
    String email, {
    String? name,
    String? organizationId,
    String? ownerMemberId,
    String status = 'active',
    String source = 'archive',
  }) async {
    final lower = email.toLowerCase();
    final existing = await _contacts(companyRef)
        .where('emails', arrayContains: lower)
        .limit(1)
        .get();
    if (existing.docs.isNotEmpty) {
      final doc = existing.docs.first;
      final updates = <String, dynamic>{
        'lastActivityAt': FieldValue.serverTimestamp(),
        'emailCount': FieldValue.increment(1),
      };
      if (status == 'active' && doc.data()['status'] == 'suggested') {
        updates['status'] = 'active';
      }
      if (organizationId != null && doc.data()['organizationId'] == null) {
        updates['organizationId'] = organizationId;
      }
      if (ownerMemberId != null) {
        updates['ownerMemberIds'] = FieldValue.arrayUnion([ownerMemberId]);
      }
      await doc.reference.set(updates, SetOptions(merge: true));
      return doc.id;
    }
    final ref = await _contacts(companyRef).add({
      'name': (name != null && name.trim().isNotEmpty)
          ? name.trim()
          : lower.split('@').first,
      'emails': [lower],
      'phones': <String>[],
      if (organizationId != null) 'organizationId': organizationId,
      'ownerMemberIds': ownerMemberId != null ? [ownerMemberId] : <String>[],
      'shared': false,
      'status': status,
      'source': source,
      'createdAt': FieldValue.serverTimestamp(),
      'lastActivityAt': FieldValue.serverTimestamp(),
      'emailCount': 1,
      'colorSeed': lower.hashCode.abs(),
    });
    return ref.id;
  }

  /// The external counterparty address for an email from the user's side.
  String? _counterpartyAddress(EmailMessage e, String? myAddress) {
    final mine = e.folder == 'Sent' ||
        (myAddress != null && e.from.toLowerCase() == myAddress.toLowerCase());
    if (mine) {
      // Sent: first recipient that isn't me.
      for (final to in e.to) {
        if (myAddress == null || to.toLowerCase() != myAddress.toLowerCase()) {
          return to;
        }
      }
      return e.to.isNotEmpty ? e.to.first : null;
    }
    return e.from;
  }

  /// Resolve (find-or-create) the org/contact for a single email.
  Future<ResolvedParty> resolveParty(
    DocumentReference<Map<String, dynamic>> companyRef,
    EmailMessage email, {
    String? myAddress,
    String? ownerMemberId,
    String status = 'active',
    String source = 'archive',
  }) async {
    final addr = _counterpartyAddress(email, myAddress);
    if (addr == null || addr.isEmpty) return const ResolvedParty();

    // Personal/free-mail address → an individual only (no org).
    if (isPersonalEmail(addr)) {
      final id = await findOrCreateContact(
        companyRef,
        addr,
        name: email.emailSenderPerson ?? email.fromName,
        ownerMemberId: ownerMemberId,
        status: status,
        source: source,
      );
      return ResolvedParty(externalContactId: id);
    }

    // Business domain → always an organization (keep the domain-derived name,
    // unless there's no person name and the display name reads like a company).
    final domain = domainOf(addr);
    if (domain == null) return const ResolvedParty();
    final orgId = await findOrCreateOrg(
      companyRef,
      domain,
      name: email.emailSenderPerson == null ? email.fromName : null,
      status: status,
      source: source,
    );

    // A named person at that domain (not a role mailbox like service@) →
    // ALSO a contact, linked to the org. Both ids are stamped on the email.
    String? contactId;
    if (!isRoleMailbox(addr)) {
      contactId = await findOrCreateContact(
        companyRef,
        addr,
        name: email.emailSenderPerson ?? email.fromName,
        organizationId: orgId,
        ownerMemberId: ownerMemberId,
        status: status,
        source: source,
      );
    }
    return ResolvedParty(organizationId: orgId, externalContactId: contactId);
  }

  /// Archive a thread's inbox emails and link them to a (created-if-needed)
  /// organization or contact. The party is resolved once from the first email.
  Future<void> archiveAndLink(
    List<EmailMessage> emails, {
    required DocumentReference<Map<String, dynamic>> companyRef,
    String? myAddress,
    String? ownerMemberId,
  }) async {
    final linkable = emails.where((e) => e.ref != null).toList();
    if (linkable.isEmpty) return;
    final party = await resolveParty(
      companyRef,
      linkable.first,
      myAddress: myAddress,
      ownerMemberId: ownerMemberId,
    );
    for (final e in linkable) {
      await e.ref!.update({
        'folder': 'Archive',
        'isDeleted': false,
        if (party.organizationId != null)
          'organizationId': party.organizationId,
        if (party.externalContactId != null)
          'externalContactId': party.externalContactId,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  /// Promote a suggested org/contact to active.
  Future<void> confirm(DocumentReference<Map<String, dynamic>> entityRef) =>
      entityRef.set(
        {'status': 'active', 'updatedAt': FieldValue.serverTimestamp()},
        SetOptions(merge: true),
      );

  /// Toggle company-wide visibility of a contact (or org).
  Future<void> setShared(
          DocumentReference<Map<String, dynamic>> entityRef, bool shared) =>
      entityRef.set(
        {'shared': shared, 'updatedAt': FieldValue.serverTimestamp()},
        SetOptions(merge: true),
      );

  /// Dismiss a suggested org/contact (won't show in the directory).
  Future<void> dismiss(DocumentReference<Map<String, dynamic>> entityRef) =>
      entityRef.set(
        {'status': 'dismissed', 'updatedAt': FieldValue.serverTimestamp()},
        SetOptions(merge: true),
      );

  /// Add a note to an org/contact timeline.
  Future<void> addNote(
    DocumentReference<Map<String, dynamic>> entityRef, {
    required String text,
    required String byUid,
    required String byName,
  }) =>
      entityRef.collection('timeline').add({
        'type': 'note',
        'text': text,
        'timestamp': FieldValue.serverTimestamp(),
        'createdByUid': byUid,
        'createdByName': byName,
      });
}
