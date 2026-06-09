// lib/repositories/timeline_facade_repository.dart
//
// Merges multiple Firestore streams into a single per-member chronological
// timeline of TimelineItems. Used by the AI canvas to render a unified feed
// of AI conversations, AI task runs, emails, text threads, calls, message
// board posts, completed tasks, My Tasks, and calendar events.
//
// Each underlying source is queried independently; results are combined
// in-memory, sorted by timestamp descending, and capped to `limit`. A
// per-member `timelineAck` stream is folded in so a swiped-acknowledged
// item renders as read without dropping off the feed.

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../common/communications/timeline/models/timeline_item.dart';

/// Task-related `timelineCategory` IDs that appear on
/// `company/{id}/timeline`. Tasks are surfaced on the timeline when they
/// complete (`completeTimestamp != null`). Schedule shifts and timecards are
/// intentionally excluded — only out-of-routine activity belongs here.
const _kTaskCategories = <String>[
  'kG9DMLORk88VrZIGD7x3',
  'ZOQH1ojP4a6QgRKCFTr8',
  'Rpl9Mn34gJBdZ007jXpo',
];

const _kMessageBoardCategory = 'message_board_category';

/// `timelineCategory` ID for manually-created calendar events. Shared with
/// the communications calendar (`kCalendarEventCategoryId` in calendar.dart);
/// inlined here to avoid pulling the Syncfusion-heavy calendar library into
/// the repository layer.
const _kCalendarEventCategory = 'in0MAUlQmUXiwXGoqWX7';

class TimelineFacadeRepository {
  /// Returns a single merged stream of timeline items, newest first.
  ///
  /// All underlying queries fan out in parallel; whenever any one emits,
  /// the merged list is recomputed, re-sorted, capped to [limit], folded
  /// against the acknowledgement stream, and emitted downstream.
  static Stream<List<TimelineItem>> watchUnified({
    required DocumentReference<Map<String, dynamic>> companyRef,
    required String memberId,
    required String uid,
    int limit = 100,
  }) {
    final controller = StreamController<List<TimelineItem>>.broadcast();
    final db = companyRef.firestore;

    // Latest slot per source.
    var aiConvs = const <TimelineItem>[];
    var aiTasks = const <TimelineItem>[];
    var emails = const <TimelineItem>[];
    var textConversations = const <TimelineItem>[];
    var voiceCalls = const <TimelineItem>[];
    var videoCalls = const <TimelineItem>[];
    var boardPosts = const <TimelineItem>[];
    var taskCompletions = const <TimelineItem>[];
    var myTasks = const <TimelineItem>[];
    var calendarEvents = const <TimelineItem>[];
    var notes = const <TimelineItem>[];

    // Per-member acknowledgement stream: itemId → when it was acknowledged.
    var acks = const <String, DateTime>{};

    void emit() {
      if (controller.isClosed) return;
      final merged = <TimelineItem>[
        ...aiConvs,
        ...aiTasks,
        ...emails,
        ...textConversations,
        ...voiceCalls,
        ...videoCalls,
        ...boardPosts,
        ...taskCompletions,
        ...myTasks,
        ...calendarEvents,
        ...notes,
      ]..sort((a, b) => b.timestamp.compareTo(a.timestamp));
      final capped = merged.take(limit).toList();
      controller.add(
        acks.isEmpty
            ? capped
            : capped.map((item) {
                final at = acks[item.id];
                return at == null ? item : item.copyWith(acknowledgedAt: at);
              }).toList(),
      );
    }

    final subs = <StreamSubscription>[];

    // 1. AI conversations from company/{id}/timeline where type='ai_canvas'.
    subs.add(
      companyRef
          .collection('timeline')
          .where('type', isEqualTo: 'ai_canvas')
          .where('createdByUid', isEqualTo: uid)
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .snapshots()
          .listen(
        (snap) {
          aiConvs = snap.docs.map(TimelineItem.aiConversation).toList();
          emit();
        },
        onError: (e) {/* ignore source-level errors, keep feed alive */},
      ),
    );

    // 2. AI agent task runs (top-level agentTaskRuns owned by this user).
    //    All statuses — `running` ones surface a live progress tile, and
    //    finished/failed ones stay as history. Ordered by `startedAt` so a
    //    still-running run (no `completedAt` yet) sorts correctly.
    subs.add(
      db
          .collection('agentTaskRuns')
          .where('ownerUid', isEqualTo: uid)
          .orderBy('startedAt', descending: true)
          .limit(limit)
          .snapshots()
          .listen(
        (snap) {
          aiTasks = snap.docs.map(TimelineItem.aiTask).toList();
          emit();
        },
        onError: (_) {},
      ),
    );

    // 3. Email — member's email subcollection (any folder except Trash).
    subs.add(
      companyRef
          .collection('member')
          .doc(memberId)
          .collection('email')
          .where('isDeleted', isEqualTo: false)
          .orderBy('receivedAt', descending: true)
          .limit(limit)
          .snapshots()
          .listen(
        (snap) {
          emails = snap.docs.map(TimelineItem.email).toList();
          emit();
        },
        onError: (_) {},
      ),
    );

    // 4. Text conversations — one timeline entry per thread the member is in,
    //    surfacing the denormalized lastMessage fields. (Not raw messages —
    //    threads scale and read better on a unified feed.)
    final memberRefForTexts = companyRef.collection('member').doc(memberId);
    subs.add(
      companyRef
          .collection('textConversation')
          .where('participantRefs', arrayContains: memberRefForTexts)
          .orderBy('lastMessageAt', descending: true)
          .limit(limit)
          .snapshots()
          .listen(
        (snap) {
          textConversations =
              snap.docs.map(TimelineItem.textConversation).toList();
          emit();
        },
        onError: (_) {},
      ),
    );

    // 5. Voice calls — member-scoped timeline.
    subs.add(
      companyRef
          .collection('member')
          .doc(memberId)
          .collection('timeline')
          .where('type', isEqualTo: 'voice_call')
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .snapshots()
          .listen(
        (snap) {
          voiceCalls = snap.docs
              .map((d) => TimelineItem.call(d, isVideo: false))
              .toList();
          emit();
        },
        onError: (_) {},
      ),
    );

    // 5. Video calls.
    subs.add(
      companyRef
          .collection('member')
          .doc(memberId)
          .collection('timeline')
          .where('type', isEqualTo: 'video_call')
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .snapshots()
          .listen(
        (snap) {
          videoCalls = snap.docs
              .map((d) => TimelineItem.call(d, isVideo: true))
              .toList();
          emit();
        },
        onError: (_) {},
      ),
    );

    // 6. Message board posts — company-level timeline refs.
    subs.add(
      companyRef
          .collection('timeline')
          .where('timelineCategory', isEqualTo: _kMessageBoardCategory)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .snapshots()
          .listen(
        (snap) {
          boardPosts = snap.docs.map(TimelineItem.messageBoardPost).toList();
          emit();
        },
        onError: (_) {},
      ),
    );

    // 7. Completed tasks — company-level timeline, task categories, scoped to
    //    this member, only docs that have a `completeTimestamp` set. The
    //    `orderBy(completeTimestamp)` clause excludes docs missing that field
    //    so we naturally see only completed work, not assigned-but-pending.
    final memberRef = companyRef.collection('member').doc(memberId);
    subs.add(
      companyRef
          .collection('timeline')
          .where('timelineCategory', whereIn: _kTaskCategories)
          .where('memberId', isEqualTo: memberRef)
          .orderBy('completeTimestamp', descending: true)
          .limit(limit)
          .snapshots()
          .listen(
        (snap) {
          taskCompletions = snap.docs.map(TimelineItem.taskCompletion).toList();
          emit();
        },
        onError: (_) {},
      ),
    );

    // 8. My Tasks — the member's own action-item inbox. Both pending and
    //    recently-completed docs are surfaced so a checked-off task stays
    //    visible (dimmed) per "the timeline possesses everything".
    subs.add(
      companyRef
          .collection('member')
          .doc(memberId)
          .collection('myTask')
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .snapshots()
          .listen(
        (snap) {
          myTasks = snap.docs.map(TimelineItem.myTask).toList();
          emit();
        },
        onError: (_) {},
      ),
    );

    // 9. Calendar events — company-wide manually-created events. The
    //    communications calendar is itself company-scoped (no per-member
    //    filter), so the timeline mirrors that: everyone sees company events.
    subs.add(
      companyRef
          .collection('timeline')
          .where('timelineCategory', isEqualTo: _kCalendarEventCategory)
          .orderBy('startTime', descending: true)
          .limit(limit)
          .snapshots()
          .listen(
        (snap) {
          calendarEvents =
              snap.docs.map(TimelineItem.calendarEvent).toList();
          emit();
        },
        onError: (_) {},
      ),
    );

    // 10. Supervisor notes — annotations the signed-in user has written about
    //     other members. Each note lives in the *subject* member's timeline
    //     subcollection, so a collection-group query scoped to this author
    //     surfaces every note they've taken across employees.
    subs.add(
      db
          .collectionGroup('timeline')
          .where('type', isEqualTo: 'note')
          .where('createdByUid', isEqualTo: uid)
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .snapshots()
          .listen(
        (snap) {
          notes = snap.docs.map(TimelineItem.note).toList();
          emit();
        },
        onError: (_) {},
      ),
    );

    // 11. Per-member acknowledgements. One tiny doc per item the member has
    //     swiped to acknowledge; folded into every item's `acknowledgedAt`
    //     in `emit()` so a swipe instantly dims its tile.
    subs.add(
      companyRef
          .collection('member')
          .doc(memberId)
          .collection('timelineAck')
          .limit(500)
          .snapshots()
          .listen(
        (snap) {
          final map = <String, DateTime>{};
          for (final d in snap.docs) {
            final raw = d.data()['acknowledgedAt'];
            // A freshly-written serverTimestamp reads back null until the
            // server resolves it — treat that as "just now" so the swipe
            // dims the tile optimistically.
            map[d.id] = raw is Timestamp ? raw.toDate() : DateTime.now();
          }
          acks = map;
          emit();
        },
        onError: (_) {},
      ),
    );

    controller.onCancel = () async {
      for (final s in subs) {
        await s.cancel();
      }
    };

    return controller.stream;
  }

  /// Returns a per-member timeline limited to *communications* — emails,
  /// text conversations, and voice/video calls (with their transcripts and
  /// AI summaries). Newest first.
  ///
  /// Unlike [watchUnified] this needs no `uid`: it surfaces only data that
  /// belongs to the member document itself, so it works for any member a
  /// supervisor (or the member) is allowed to view.
  ///
  /// When [scope] is supplied, the feed is narrowed to communications that
  /// *also* involve the scoped viewer — used so a supervisor looking at an
  /// employee sees only their shared 1:1 and group threads, not the
  /// employee's entire history. Pass null (the default) to see everything,
  /// which is what a member viewing their own profile gets.
  static Stream<List<TimelineItem>> watchMemberCommunications({
    required DocumentReference<Map<String, dynamic>> companyRef,
    required String memberId,
    TimelineCommScope? scope,
    int limit = 100,
  }) {
    final controller = StreamController<List<TimelineItem>>.broadcast();
    final memberRef = companyRef.collection('member').doc(memberId);

    // The viewer-involvement filter runs client-side, so when scoped we
    // over-fetch to avoid missing older shared items past the merge cap.
    final fetchLimit = scope == null ? limit : limit * 3;

    var emails = const <TimelineItem>[];
    var textConversations = const <TimelineItem>[];
    var voiceCalls = const <TimelineItem>[];
    var videoCalls = const <TimelineItem>[];
    var notes = const <TimelineItem>[];

    void emit() {
      if (controller.isClosed) return;
      final merged = <TimelineItem>[
        ...emails,
        ...textConversations,
        ...voiceCalls,
        ...videoCalls,
        ...notes,
      ]..sort((a, b) => b.timestamp.compareTo(a.timestamp));
      controller.add(merged.take(limit).toList());
    }

    final subs = <StreamSubscription>[];

    // Emails — member's email subcollection (any folder except Trash).
    subs.add(
      memberRef
          .collection('email')
          .where('isDeleted', isEqualTo: false)
          .orderBy('receivedAt', descending: true)
          .limit(fetchLimit)
          .snapshots()
          .listen(
        (snap) {
          emails = snap.docs
              .where((d) => _emailInScope(d.data(), scope))
              .map(TimelineItem.email)
              .toList();
          emit();
        },
        onError: (_) {/* keep feed alive if one source fails */},
      ),
    );

    // Text conversations — one entry per thread the member participates in.
    subs.add(
      companyRef
          .collection('textConversation')
          .where('participantRefs', arrayContains: memberRef)
          .orderBy('lastMessageAt', descending: true)
          .limit(fetchLimit)
          .snapshots()
          .listen(
        (snap) {
          textConversations = snap.docs
              .where((d) => _textInScope(d.data(), scope))
              .map(TimelineItem.textConversation)
              .toList();
          emit();
        },
        onError: (_) {},
      ),
    );

    // Voice calls — member-scoped timeline subcollection.
    subs.add(
      memberRef
          .collection('timeline')
          .where('type', isEqualTo: 'voice_call')
          .orderBy('timestamp', descending: true)
          .limit(fetchLimit)
          .snapshots()
          .listen(
        (snap) {
          voiceCalls = snap.docs
              .where((d) => _callInScope(d.data(), scope))
              .map((d) => TimelineItem.call(d, isVideo: false))
              .toList();
          emit();
        },
        onError: (_) {},
      ),
    );

    // Video calls.
    subs.add(
      memberRef
          .collection('timeline')
          .where('type', isEqualTo: 'video_call')
          .orderBy('timestamp', descending: true)
          .limit(fetchLimit)
          .snapshots()
          .listen(
        (snap) {
          videoCalls = snap.docs
              .where((d) => _callInScope(d.data(), scope))
              .map((d) => TimelineItem.call(d, isVideo: true))
              .toList();
          emit();
        },
        onError: (_) {},
      ),
    );

    // Supervisor notes — only surface when a viewer scope is set (a
    // supervisor reading an employee's profile) and only the notes that
    // same viewer authored. Notes are private to their creator: the subject
    // employee never sees them on their own Communication tab.
    if (scope != null) {
      subs.add(
        memberRef
            .collection('timeline')
            .where('type', isEqualTo: 'note')
            .where('createdByUid', isEqualTo: scope.viewerUid)
            .orderBy('timestamp', descending: true)
            .limit(fetchLimit)
            .snapshots()
            .listen(
          (snap) {
            notes = snap.docs.map(TimelineItem.note).toList();
            emit();
          },
          onError: (_) {},
        ),
      );
    }

    controller.onCancel = () async {
      for (final s in subs) {
        await s.cancel();
      }
    };

    return controller.stream;
  }

  // ─────────────── uniform per-entity funnel ───────────────
  //
  // Every communication doc (text conversation, call summary, email) carries
  // a `commContextRefs` array of the entity paths it relates to — member,
  // task, organization, external contact, team. A single uniform funnel then
  // pulls EVERY modality for ANY entity with one `arrayContains` query per
  // company-level collection. New entity types (vendors, …) get a complete
  // communications timeline for free: tag their path into `commContextRefs`
  // at the write points and call [watchEntityCommunications].
  //
  // The company-level mirrors are the query surface so no collection-group
  // index is needed: `textConversation` is already company-level, and the
  // call/email summarizers write company-level mirrors (`timeline` with
  // `timelineCategory == 'callSummary'`, and `emailLog`). `arrayContains`
  // uses an automatic single-field index; the merge sorts client-side, so no
  // composite index is required.

  /// The uniform modality sources for an entity, keyed by the entity's full
  /// Firestore path (e.g. `company/{id}/task/{taskId}` or
  /// `company/{id}/organization/{orgId}`). Reused by tasks, organizations,
  /// vendors, and any future entity that owns a communication timeline.
  static List<CommSource> entityCommSources({
    required DocumentReference<Map<String, dynamic>> companyRef,
    required String entityPath,
    int fetchLimit = 100,
  }) {
    return <CommSource>[
      // Text threads tagged with this entity.
      CommSource(
        stream: companyRef
            .collection('textConversation')
            .where('commContextRefs', arrayContains: entityPath)
            .limit(fetchLimit)
            .snapshots(),
        map: TimelineItem.textConversation,
      ),
      // Voice/video call summaries (company-level mirror).
      CommSource(
        stream: companyRef
            .collection('timeline')
            .where('commContextRefs', arrayContains: entityPath)
            .limit(fetchLimit)
            .snapshots(),
        map: TimelineItem.companyCallSummary,
        where: (data) => data['timelineCategory'] == 'callSummary',
      ),
      // Emails (company-level mirror).
      CommSource(
        stream: companyRef
            .collection('emailLog')
            .where('commContextRefs', arrayContains: entityPath)
            .limit(fetchLimit)
            .snapshots(),
        map: TimelineItem.email,
      ),
    ];
  }

  /// Uniform communications timeline for any entity identified by its
  /// Firestore [entityPath]. Funnels every modality tagged with that path.
  static Stream<List<TimelineItem>> watchEntityCommunications({
    required DocumentReference<Map<String, dynamic>> companyRef,
    required String entityPath,
    int limit = 100,
  }) {
    return mergeCommSources(
      sources:
          entityCommSources(companyRef: companyRef, entityPath: entityPath),
      limit: limit,
    );
  }

  /// Returns the *communications* timeline for a single task. Combines the
  /// uniform entity funnel (text/calls/email tagged with the task path) with
  /// task-owned extras: the task's own `timeline` subcollection notes and
  /// manually-logged calls, plus a legacy `taskId` text query for threads
  /// created before `commContextRefs` existed. The merge dedups by item id,
  /// so a thread matched by both the legacy and uniform queries appears once.
  static Stream<List<TimelineItem>> watchTaskCommunications({
    required DocumentReference<Map<String, dynamic>> companyRef,
    required String taskId,
    int limit = 100,
  }) {
    final taskRef = companyRef.collection('task').doc(taskId);
    final taskPath = taskRef.path;

    final sources = <CommSource>[
      ...entityCommSources(
        companyRef: companyRef,
        entityPath: taskPath,
        fetchLimit: limit,
      ),
      // Legacy: threads linked by `taskId` before `commContextRefs` shipped
      // (the backfill stamps `commContextRefs`, but this keeps pre-backfill
      // threads visible). Deduped against the uniform text source by id.
      CommSource(
        stream: companyRef
            .collection('textConversation')
            .where('taskId', isEqualTo: taskId)
            .snapshots(),
        map: TimelineItem.textConversation,
      ),
      // Task-owned notes — shared annotations every viewer can see (unlike a
      // member's private supervisor notes).
      CommSource(
        stream: taskRef
            .collection('timeline')
            .where('type', isEqualTo: 'note')
            .snapshots(),
        map: TimelineItem.note,
      ),
      // Manually-logged calls on the task's own timeline.
      CommSource(
        stream: taskRef
            .collection('timeline')
            .where('type', isEqualTo: 'voice_call')
            .snapshots(),
        map: (d) => TimelineItem.call(d, isVideo: false),
      ),
      CommSource(
        stream: taskRef
            .collection('timeline')
            .where('type', isEqualTo: 'video_call')
            .snapshots(),
        map: (d) => TimelineItem.call(d, isVideo: true),
      ),
    ];

    return mergeCommSources(sources: sources, limit: limit);
  }

  /// Merge engine shared by every communications funnel: subscribes to each
  /// [CommSource], maps its docs to [TimelineItem]s (applying any per-source
  /// client filter), then merges all sources — deduping by item id, sorting
  /// newest-first, and capping to [limit]. Re-emits whenever any source ticks.
  static Stream<List<TimelineItem>> mergeCommSources({
    required List<CommSource> sources,
    int limit = 100,
  }) {
    final controller = StreamController<List<TimelineItem>>.broadcast();
    final latest = List<List<TimelineItem>>.filled(sources.length, const []);

    void emit() {
      if (controller.isClosed) return;
      // Dedup by id — a doc surfaced by two sources (e.g. a task thread hit
      // by both the legacy `taskId` and uniform `commContextRefs` queries)
      // collapses to one item.
      final byId = <String, TimelineItem>{};
      for (final list in latest) {
        for (final item in list) {
          byId[item.id] = item;
        }
      }
      final merged = byId.values.toList()
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
      controller.add(merged.take(limit).toList());
    }

    final subs = <StreamSubscription>[];
    for (var i = 0; i < sources.length; i++) {
      final src = sources[i];
      final idx = i;
      subs.add(
        src.stream.listen(
          (snap) {
            final docs = src.where == null
                ? snap.docs
                : snap.docs
                    .where((d) => src.where!(d.data()))
                    .toList();
            latest[idx] = docs.map(src.map).toList();
            emit();
          },
          onError: (_) {/* keep the feed alive if one source fails */},
        ),
      );
    }

    controller.onCancel = () async {
      for (final s in subs) {
        await s.cancel();
      }
    };

    return controller.stream;
  }

  // ─────────────── viewer-scope filters ───────────────

  /// A text thread is in scope when the viewer is also a participant — true
  /// for the viewer's 1:1 thread with the member and any group thread that
  /// includes them both. (The query already guarantees member membership.)
  static bool _textInScope(
    Map<String, dynamic> data,
    TimelineCommScope? scope,
  ) {
    if (scope == null) return true;
    final refs = data['participantRefs'];
    if (refs is! List) return false;
    for (final r in refs) {
      if (r is DocumentReference && r.path == scope.viewerMemberPath) {
        return true;
      }
    }
    return false;
  }

  /// A call is in scope when the viewer is one of its participants. Calls
  /// logged before participants were recorded carry no list — those are kept
  /// rather than silently dropped from history.
  static bool _callInScope(
    Map<String, dynamic> data,
    TimelineCommScope? scope,
  ) {
    if (scope == null) return true;
    final participants = data['participants'];
    if (participants is List && participants.isNotEmpty) {
      return participants.whereType<String>().contains(scope.viewerMemberId);
    }
    return true;
  }

  /// An email is in scope when the viewer is its sender or a recipient.
  /// Addresses are matched leniently (substring) so display-name formatting
  /// like `Jane Doe <jane@co.com>` still matches `jane@co.com`.
  static bool _emailInScope(
    Map<String, dynamic> data,
    TimelineCommScope? scope,
  ) {
    if (scope == null) return true;
    if (scope.viewerEmails.isEmpty) return false;
    bool matches(String? raw) {
      if (raw == null || raw.isEmpty) return false;
      final lower = raw.toLowerCase();
      return scope.viewerEmails.any((addr) => lower.contains(addr));
    }

    if (matches(data['from'] as String?)) return true;
    for (final key in const ['to', 'cc']) {
      final list = data[key];
      if (list is List) {
        for (final entry in list) {
          if (entry is String && matches(entry)) return true;
        }
      }
    }
    return false;
  }
}

/// One modality input to [TimelineFacadeRepository.mergeCommSources]: a
/// Firestore query [stream], a [map] that adapts each doc into a
/// [TimelineItem], and an optional client-side [where] filter applied before
/// mapping (used when a single query returns more than the funnel wants, e.g.
/// company-`timeline` docs filtered to `timelineCategory == 'callSummary'`).
class CommSource {
  const CommSource({
    required this.stream,
    required this.map,
    this.where,
  });

  final Stream<QuerySnapshot<Map<String, dynamic>>> stream;
  final TimelineItem Function(DocumentSnapshot<Map<String, dynamic>>) map;
  final bool Function(Map<String, dynamic> data)? where;
}

/// Restricts a member communications timeline to items that also involve a
/// specific *viewer* — e.g. a supervisor looking at an employee's profile.
/// Passed to [TimelineFacadeRepository.watchMemberCommunications]; a null
/// scope means "show everything" (a member viewing their own profile).
class TimelineCommScope {
  const TimelineCommScope({
    required this.viewerMemberId,
    required this.viewerMemberPath,
    required this.viewerEmails,
    required this.viewerUid,
  });

  /// Viewer's member document id — matched against call `participants`.
  final String viewerMemberId;

  /// Viewer's member document path — matched against text-conversation
  /// `participantRefs`.
  final String viewerMemberPath;

  /// Viewer's mailbox addresses (lowercased) — matched against email
  /// `from`/`to`/`cc`.
  final Set<String> viewerEmails;

  /// Viewer's Firebase Auth uid — matched against `createdByUid` so the
  /// note stream only returns annotations this viewer authored.
  final String viewerUid;
}
