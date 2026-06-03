// lib/common/communications/email/providers/email_providers.dart
//
// SendGrid + Firestore backed email providers — ported from the kleenops app.
//
// ADMIN ADAPTATION: mail lands at `company/{cid}/member/{mid}/email`, but the
// admin app's `companyIdProvider`/`memberDocRefProvider` resolve the *overlord*
// entity under `kleenops/{id}`. So these providers resolve the member + company
// from [mailboxMemberRefProvider] (the active membership under the `company`
// collection, where mail actually lands) instead.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod/legacy.dart';

import 'package:kleenops_admin/features/auth/providers/auth_provider.dart';
import '../models/email_account.dart';
import '../models/email_message.dart';
import '../models/email_thread.dart';
import '../services/kleenops_email_service.dart';

/// KleenOps email service (Cloud Functions + Firestore).
final kleenopsEmailServiceProvider = Provider<KleenopsEmailService>(
  (_) => KleenopsEmailService.instance,
);

/// Auth UID for the signed-in user.
final _currentUidProvider = Provider.autoDispose<String?>((ref) {
  return ref.watch(authStateChangesProvider).value?.uid;
});

/// The `company/{cid}` doc where the signed-in user's mail lands, derived from
/// the member ref (`company/{cid}/member/{mid}` → its grandparent doc).
final mailboxCompanyRefProvider =
    Provider.autoDispose<DocumentReference<Map<String, dynamic>>?>((ref) {
  final memberRef = ref.watch(mailboxMemberRefProvider).value;
  return memberRef?.parent.parent;
});

/// Stream of mailboxes accessible to the current user — `emailAddress` docs
/// whose `memberUids` array contains the user's UID.
final currentUserMailboxesProvider =
    StreamProvider.autoDispose<List<EmailAccount>>((ref) {
  final companyRef = ref.watch(mailboxCompanyRefProvider);
  final uid = ref.watch(_currentUidProvider);
  if (companyRef == null || uid == null) return Stream.value(const []);

  return companyRef
      .collection('emailAddress')
      .where('memberUids', arrayContains: uid)
      .where('status', isEqualTo: 'active')
      .snapshots()
      .map((snap) => snap.docs.map(EmailAccount.fromFirestore).toList());
});

/// Backwards-compatible alias.
final emailAccountsProvider = currentUserMailboxesProvider;

/// All active mailboxes in the company (admin view).
final companyMailboxesProvider =
    StreamProvider.autoDispose<List<EmailAccount>>((ref) {
  final companyRef = ref.watch(mailboxCompanyRefProvider);
  if (companyRef == null) return Stream.value(const []);
  return companyRef
      .collection('emailAddress')
      .where('status', isEqualTo: 'active')
      .snapshots()
      .map((snap) => snap.docs.map(EmailAccount.fromFirestore).toList());
});

/// Primary mailbox (the one marked `isPrimary`, falling back to the first).
final primaryEmailAccountProvider = Provider.autoDispose<EmailAccount?>((ref) {
  final list = ref.watch(currentUserMailboxesProvider).value ?? const [];
  if (list.isEmpty) return null;
  for (final acct in list) {
    if (acct.isPrimary) return acct;
  }
  return list.first;
});

/// User's explicit mailbox selection by address. `null` means "use primary".
final selectedMailboxAddressProvider =
    StateProvider.autoDispose<String?>((_) => null);

/// Currently active mailbox. Resolves the user's explicit selection (if any and
/// still valid) and otherwise falls back to the primary mailbox.
final currentEmailAccountProvider = Provider.autoDispose<EmailAccount?>((ref) {
  final list = ref.watch(currentUserMailboxesProvider).value ?? const [];
  final selectedAddress = ref.watch(selectedMailboxAddressProvider);
  if (selectedAddress != null) {
    for (final acct in list) {
      if (acct.emailAddress == selectedAddress) return acct;
    }
  }
  return ref.watch(primaryEmailAccountProvider);
});

/// Whether the user has any mailbox to read/send from.
final hasEmailAccountProvider = Provider.autoDispose<bool>((ref) {
  return (ref.watch(currentUserMailboxesProvider).value ?? const []).isNotEmpty;
});

/// Inbox messages for the currently selected mailbox.
final inboxEmailsProvider =
    StreamProvider.autoDispose<List<EmailMessage>>((ref) {
  final companyRef = ref.watch(mailboxCompanyRefProvider);
  final memberRef = ref.watch(mailboxMemberRefProvider).value;
  final accountId = ref.watch(
    currentEmailAccountProvider.select((a) => a?.emailAddress),
  );
  if (companyRef == null || memberRef == null || accountId == null) {
    return Stream.value(const []);
  }
  return ref
      .watch(kleenopsEmailServiceProvider)
      .watchInbox(
        companyRef: companyRef,
        memberId: memberRef.id,
        accountId: accountId,
      )
      .map((snap) => snap.docs.map(EmailMessage.fromFirestore).toList());
});

/// Sent messages for the currently selected mailbox.
final sentEmailsProvider =
    StreamProvider.autoDispose<List<EmailMessage>>((ref) {
  final companyRef = ref.watch(mailboxCompanyRefProvider);
  final memberRef = ref.watch(mailboxMemberRefProvider).value;
  final accountId = ref.watch(
    currentEmailAccountProvider.select((a) => a?.emailAddress),
  );
  if (companyRef == null || memberRef == null || accountId == null) {
    return Stream.value(const []);
  }
  return ref
      .watch(kleenopsEmailServiceProvider)
      .watchSent(
        companyRef: companyRef,
        memberId: memberRef.id,
        accountId: accountId,
      )
      .map((snap) => snap.docs.map(EmailMessage.fromFirestore).toList());
});

/// Trashed + junked messages for the currently selected mailbox.
final trashEmailsProvider =
    StreamProvider.autoDispose<List<EmailMessage>>((ref) {
  final companyRef = ref.watch(mailboxCompanyRefProvider);
  final memberRef = ref.watch(mailboxMemberRefProvider).value;
  final accountId = ref.watch(
    currentEmailAccountProvider.select((a) => a?.emailAddress),
  );
  if (companyRef == null || memberRef == null || accountId == null) {
    return Stream.value(const []);
  }
  return ref
      .watch(kleenopsEmailServiceProvider)
      .watchTrash(
        companyRef: companyRef,
        memberId: memberRef.id,
        accountId: accountId,
      )
      .map((snap) => snap.docs.map(EmailMessage.fromFirestore).toList());
});

/// Unread count for the Inbox tab badge.
final inboxUnreadCountProvider = Provider.autoDispose<int>((ref) {
  final emails = ref.watch(inboxEmailsProvider).value ?? const [];
  return emails.where((e) => !e.isRead).length;
});

/// Item count for the Trash tab badge.
final trashCountProvider = Provider.autoDispose<int>((ref) {
  return (ref.watch(trashEmailsProvider).value ?? const []).length;
});

/// All emails in the same conversation as [emailId] — every non-trashed
/// message whose normalized subject matches. Reads a bounded recent window and
/// filters client-side.
final conversationEmailsProvider = StreamProvider.autoDispose
    .family<List<EmailMessage>, String>((ref, emailId) {
  final memberRef = ref.watch(mailboxMemberRefProvider).value;
  final opened = ref.watch(emailByIdProvider(emailId)).value;
  if (memberRef == null || opened == null) {
    return Stream.value(const []);
  }
  final key = stripSubjectPrefixes(opened.subject).toLowerCase();
  return memberRef
      .collection('email')
      .orderBy('receivedAt', descending: true)
      .limit(200)
      .snapshots()
      .map((snap) => snap.docs
          .map(EmailMessage.fromFirestore)
          .where((e) => e.folder != 'Trash')
          .where((e) => stripSubjectPrefixes(e.subject).toLowerCase() == key)
          .toList());
});

/// Single email by Firestore doc id, from the current user's member
/// email subcollection.
final emailByIdProvider =
    StreamProvider.autoDispose.family<EmailMessage?, String>((ref, emailId) {
  final memberRef = ref.watch(mailboxMemberRefProvider).value;
  if (memberRef == null) return Stream.value(null);
  return memberRef
      .collection('email')
      .doc(emailId)
      .snapshots()
      .map((doc) => doc.exists ? EmailMessage.fromFirestore(doc) : null);
});
