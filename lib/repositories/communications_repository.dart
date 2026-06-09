// lib/repositories/communications_repository.dart
//
// Consolidated Firestore access for the Communications feature family:
// video calls, intercom/voice, open channels, external portal chat, and
// related realtime artifacts. Ported from the kleenops app verbatim — these
// are tenant-company-scoped (`company/{id}`) paths, shared by both apps.
//
// Consumers should depend on `communicationsRepositoryProvider` rather than
// reaching into `FirebaseFirestore.instance` directly.

import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CommunicationsRepository {
  CommunicationsRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  // ─────────────── Company ───────────────

  DocumentReference<Map<String, dynamic>> companyDoc(String companyId) =>
      _firestore.collection('company').doc(companyId);

  // ─────────────── Video / intercom rooms ───────────────

  CollectionReference<Map<String, dynamic>> videoRoomCollection(
          String companyId) =>
      companyDoc(companyId).collection('videoRooms');

  DocumentReference<Map<String, dynamic>> videoRoomDoc(
          String companyId, String roomId) =>
      videoRoomCollection(companyId).doc(roomId);

  /// Participants are a subcollection under each room.
  CollectionReference<Map<String, dynamic>> videoRoomParticipantCollection(
          String companyId, String roomId) =>
      videoRoomDoc(companyId, roomId).collection('participants');

  // ─────────────── Open channels (push-to-talk task channels) ───────────────

  CollectionReference<Map<String, dynamic>> openChannelCollection(
          String companyId) =>
      companyDoc(companyId).collection('open_channels');

  DocumentReference<Map<String, dynamic>> openChannelDoc(
          String companyId, String channelId) =>
      openChannelCollection(companyId).doc(channelId);

  /// Participants are a subcollection under each open channel.
  CollectionReference<Map<String, dynamic>> openChannelParticipantCollection(
          String companyId, String channelId) =>
      openChannelDoc(companyId, channelId).collection('participants');

  // ─────────────── Email domain ───────────────

  /// Per-company email-domain configuration (DNS, SendGrid status, inbound
  /// parse). Written by the admin email/domain screen and read by the email
  /// routing service.
  CollectionReference<Map<String, dynamic>> domainCollection(String companyId) =>
      companyDoc(companyId).collection('domain');

  DocumentReference<Map<String, dynamic>> domainDoc(
          String companyId, String domainId) =>
      domainCollection(companyId).doc(domainId);

  // ─────────────── External contacts (portal-backed chat) ───────────────

  /// Outside people/orgs the company corresponds with via the portal (vendors,
  /// customers, contractors). Distinct from `member` (employees) and from the
  /// internal `textConversation` collection (which is member↔member only).
  CollectionReference<Map<String, dynamic>> externalContactCollection(
          String companyId) =>
      companyDoc(companyId).collection('externalContact');

  DocumentReference<Map<String, dynamic>> externalContactDoc(
          String companyId, String contactId) =>
      externalContactCollection(companyId).doc(contactId);

  // ─────────────── External threads (one per contact + assigned member) ───────────────

  /// A portal-backed conversation between one external contact and one
  /// internal member. Two members talking to the same contact = two separate
  /// thread docs with two separate portal URLs.
  CollectionReference<Map<String, dynamic>> externalThreadCollection(
          String companyId) =>
      companyDoc(companyId).collection('externalThread');

  DocumentReference<Map<String, dynamic>> externalThreadDoc(
          String companyId, String threadId) =>
      externalThreadCollection(companyId).doc(threadId);

  /// Fresh externalThread doc reference with a generated ID. Use when a
  /// member creates a new external conversation.
  DocumentReference<Map<String, dynamic>> newExternalThreadDoc(
          String companyId) =>
      externalThreadCollection(companyId).doc();

  /// Messages inside an external thread. Each message carries
  /// `direction: 'outbound' | 'inbound'` so member writes and portal writes
  /// share the same shape.
  CollectionReference<Map<String, dynamic>> externalThreadMessageCollection(
          String companyId, String threadId) =>
      externalThreadDoc(companyId, threadId).collection('message');

  DocumentReference<Map<String, dynamic>> externalThreadMessageDoc(
          String companyId, String threadId, String messageId) =>
      externalThreadMessageCollection(companyId, threadId).doc(messageId);

  /// Fresh message doc reference with a generated ID.
  DocumentReference<Map<String, dynamic>> newExternalThreadMessageDoc(
          String companyId, String threadId) =>
      externalThreadMessageCollection(companyId, threadId).doc();

  // ─────────────── External thread queries ───────────────

  /// External threads assigned to a single member, sorted by latest activity.
  /// Used by the unified inbox to merge with internal timeline entries.
  Query<Map<String, dynamic>> memberExternalThreadsQuery({
    required String companyId,
    required String memberUid,
    bool activeOnly = true,
  }) {
    Query<Map<String, dynamic>> q = externalThreadCollection(companyId)
        .where('assignedMemberUid', isEqualTo: memberUid);
    if (activeOnly) {
      q = q.where('status', isEqualTo: 'active');
    }
    return q.orderBy('lastMessageAt', descending: true);
  }

  /// All threads for one external contact (across members). Use when showing
  /// a contact's history page.
  Query<Map<String, dynamic>> contactThreadsQuery({
    required String companyId,
    required String externalContactId,
  }) =>
      externalThreadCollection(companyId)
          .where('externalContactId', isEqualTo: externalContactId)
          .orderBy('lastMessageAt', descending: true);

  /// Messages in one thread, oldest first. Driving query for the in-app
  /// thread detail screen.
  Query<Map<String, dynamic>> threadMessagesQuery(
          String companyId, String threadId) =>
      externalThreadMessageCollection(companyId, threadId)
          .orderBy('createdAt', descending: false);

  // ─────────────── Transactions / utility helpers ───────────────

  /// Generate a unique Firestore ID without creating a real document. Used
  /// when a caller needs an ID up front (e.g. for a slug-keyed lookup table).
  String newId() => _firestore.collection('_ids').doc().id;

  /// Generates an RFC-4122 v4 UUID. Document IDs that surface to iOS CallKit
  /// as a call id (videoRooms, open_channels) MUST be UUIDs — CallKit, via
  /// flutter_callkit_incoming, parses the id with `UUID(uuidString:)` and
  /// force-unwraps the result, so a Firestore auto-ID crashes the iOS app on
  /// every incoming call.
  static String newUuid() {
    final rnd = Random.secure();
    final bytes = List<int>.generate(16, (_) => rnd.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40; // version 4
    bytes[8] = (bytes[8] & 0x3f) | 0x80; // variant 1 (RFC 4122)
    String hex(int start, int end) => bytes
        .sublist(start, end)
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
    return '${hex(0, 4)}-${hex(4, 6)}-${hex(6, 8)}-${hex(8, 10)}-${hex(10, 16)}';
  }

  Future<T> runTransaction<T>(
    TransactionHandler<T> handler, {
    Duration timeout = const Duration(seconds: 30),
    int maxAttempts = 5,
  }) =>
      _firestore.runTransaction<T>(
        handler,
        timeout: timeout,
        maxAttempts: maxAttempts,
      );

  WriteBatch batch() => _firestore.batch();
}

final communicationsRepositoryProvider =
    Provider<CommunicationsRepository>((ref) {
  return CommunicationsRepository();
});
