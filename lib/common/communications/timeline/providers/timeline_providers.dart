// lib/common/communications/timeline/providers/timeline_providers.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kleenops_admin/common/communications/email/providers/email_providers.dart';
import 'package:kleenops_admin/features/auth/providers/auth_provider.dart';
import 'package:kleenops_admin/repositories/timeline_facade_repository.dart';
import '../models/timeline_item.dart';

/// Unified per-member communications timeline. Returns the most recent
/// 100 items across AI conversations, AI task runs, emails, voice/video
/// calls, message board posts, and calendar entries. Newest first.
final memberTimelineProvider =
    StreamProvider.autoDispose<List<TimelineItem>>((ref) {
  final companyRef = ref.watch(companyIdProvider).value;
  final memberRef = ref.watch(memberDocRefProvider).value;
  final uid = ref.watch(authStateChangesProvider).value?.uid;
  if (companyRef == null || memberRef == null || uid == null) {
    return Stream.value(const <TimelineItem>[]);
  }
  return TimelineFacadeRepository.watchUnified(
    companyRef: companyRef,
    memberId: memberRef.id,
    uid: uid,
  );
});

/// Communications-only timeline for an arbitrary member, keyed by the member
/// document path. Surfaces emails, text conversations, and voice/video calls
/// (with transcripts) — used by the Communication tab on the member profile,
/// in both the "Me" section and the supervisor's employee view.
///
/// When the signed-in user is viewing *someone else*, the feed is scoped to
/// communications they both took part in — the supervisor's shared 1:1 and
/// group threads with that member, not the member's entire history. Viewing
/// your own profile is unscoped. Scoping is purely participation-based, never
/// team- or role-based.
final memberCommunicationsTimelineProvider = StreamProvider.autoDispose
    .family<List<TimelineItem>, String>((ref, memberPath) {
  final rawMemberRef = FirebaseFirestore.instance.doc(memberPath);
  final rawCompanyRef = rawMemberRef.parent.parent;
  if (rawCompanyRef == null) {
    return Stream.value(const <TimelineItem>[]);
  }
  final companyRef = rawCompanyRef.withConverter<Map<String, dynamic>>(
    fromFirestore: (snap, _) => snap.data() ?? <String, dynamic>{},
    toFirestore: (data, _) => data,
  );

  // Hold the feed in a loading state until the signed-in viewer resolves, so
  // a supervisor never briefly sees an unscoped feed.
  final viewerAsync = ref.watch(memberDocRefProvider);
  if (!viewerAsync.hasValue) {
    return Stream<List<TimelineItem>>.empty();
  }
  final viewerRef = viewerAsync.value;

  TimelineCommScope? scope;
  if (viewerRef != null && viewerRef.id != rawMemberRef.id) {
    final mailboxes =
        ref.watch(currentUserMailboxesProvider).value ?? const [];
    final viewerUid = ref.watch(authStateChangesProvider).value?.uid ?? '';
    scope = TimelineCommScope(
      viewerMemberId: viewerRef.id,
      viewerMemberPath: viewerRef.path,
      viewerEmails: mailboxes
          .map((m) => m.emailAddress.toLowerCase().trim())
          .where((e) => e.isNotEmpty)
          .toSet(),
      viewerUid: viewerUid,
    );
  }

  return TimelineFacadeRepository.watchMemberCommunications(
    companyRef: companyRef,
    memberId: rawMemberRef.id,
    scope: scope,
  );
});

/// Communications-only timeline for a single task — the task-linked text
/// thread plus any calls/notes on the task's own `timeline` subcollection.
/// Used by the task Communication tab so it renders the same node-rail feed
/// as the member Communication tab. Keyed by company + task id.
final taskCommunicationsTimelineProvider = StreamProvider.autoDispose
    .family<List<TimelineItem>, ({String companyId, String taskId})>(
        (ref, key) {
  final companyRef = FirebaseFirestore.instance
      .collection('company')
      .doc(key.companyId)
      .withConverter<Map<String, dynamic>>(
        fromFirestore: (snap, _) => snap.data() ?? <String, dynamic>{},
        toFirestore: (data, _) => data,
      );
  return TimelineFacadeRepository.watchTaskCommunications(
    companyRef: companyRef,
    taskId: key.taskId,
  );
});

/// Communications timeline for a directory entity (organization or external
/// contact / vendor). Combines the uniform per-entity funnel for texts + calls
/// (tagged via `commContextRefs`) with the directory's established email model:
/// the viewer's own email copies plus the company `emailLog`, queried by the
/// legacy `organizationId` / `externalContactId` field and deduped by
/// messageId. Keeping the legacy email queries means org/vendor email keeps
/// working before the `commContextRefs` backfill runs.
final directoryEntityCommunicationsProvider = StreamProvider.autoDispose.family<
    List<TimelineItem>,
    ({String companyId, String kind, String entityId})>((ref, key) {
  final companyRef = FirebaseFirestore.instance
      .collection('company')
      .doc(key.companyId)
      .withConverter<Map<String, dynamic>>(
        fromFirestore: (snap, _) => snap.data() ?? <String, dynamic>{},
        toFirestore: (data, _) => data,
      );
  final isOrg = key.kind == 'organization';
  final collection = isOrg ? 'organization' : 'externalContact';
  final field = isOrg ? 'organizationId' : 'externalContactId';
  final entityPath = companyRef.collection(collection).doc(key.entityId).path;
  final memberRef = ref.watch(memberDocRefProvider).value;

  final sources = <CommSource>[
    // Texts tagged with this entity.
    CommSource(
      stream: companyRef
          .collection('textConversation')
          .where('commContextRefs', arrayContains: entityPath)
          .limit(100)
          .snapshots(),
      map: TimelineItem.textConversation,
    ),
    // Call summaries tagged with this entity (company-level mirror).
    CommSource(
      stream: companyRef
          .collection('timeline')
          .where('commContextRefs', arrayContains: entityPath)
          .limit(100)
          .snapshots(),
      map: TimelineItem.companyCallSummary,
      where: (data) => data['timelineCategory'] == 'callSummary',
    ),
    // Emails — the viewer's own copies (openable, carry read state)…
    if (memberRef != null)
      CommSource(
        stream: memberRef
            .collection('email')
            .where(field, isEqualTo: key.entityId)
            .snapshots(),
        map: (d) => TimelineItem.email(d, idByMessageId: true),
      ),
    // …plus the company-wide log (colleague mail), deduped by messageId.
    CommSource(
      stream: companyRef
          .collection('emailLog')
          .where(field, isEqualTo: key.entityId)
          .snapshots(),
      map: (d) => TimelineItem.email(d, idByMessageId: true),
    ),
  ];

  return TimelineFacadeRepository.mergeCommSources(sources: sources);
});
