// lib/common/communications/timeline/models/timeline_item.dart
//
// Unified model for items rendered on the AI canvas timeline. A single
// TimelineItem represents one row regardless of underlying source
// (AI conversation, email, phone call, message board post, etc.).
//
// Items are constructed via factory constructors that adapt each source
// Firestore document or domain model into the common shape.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:kleenops_admin/features/occupancy/models/agent_task_run.dart';

enum TimelineItemKind {
  aiConversation,
  aiTask,
  email,
  textMessage,
  phoneCall,
  videoCall,
  messageBoardPost,
  taskCompletion,
  myTask,
  calendarEvent,
  note,
}

extension TimelineItemKindExt on TimelineItemKind {
  String get displayLabel {
    switch (this) {
      case TimelineItemKind.aiConversation:
        return 'AI';
      case TimelineItemKind.aiTask:
        return 'AI Task';
      case TimelineItemKind.email:
        return 'Email';
      case TimelineItemKind.textMessage:
        return 'Text';
      case TimelineItemKind.phoneCall:
        return 'Phone';
      case TimelineItemKind.videoCall:
        return 'Video';
      case TimelineItemKind.messageBoardPost:
        return 'Board';
      case TimelineItemKind.taskCompletion:
        return 'Task';
      case TimelineItemKind.myTask:
        return 'To-do';
      case TimelineItemKind.calendarEvent:
        return 'Event';
      case TimelineItemKind.note:
        return 'Note';
    }
  }

  IconData get icon {
    switch (this) {
      case TimelineItemKind.aiConversation:
        return Icons.smart_toy_outlined;
      case TimelineItemKind.aiTask:
        return Icons.auto_awesome_outlined;
      case TimelineItemKind.email:
        return Icons.email_outlined;
      case TimelineItemKind.textMessage:
        return Icons.chat_outlined;
      case TimelineItemKind.phoneCall:
        return Icons.phone_outlined;
      case TimelineItemKind.videoCall:
        return Icons.videocam_outlined;
      case TimelineItemKind.messageBoardPost:
        return Icons.push_pin_outlined;
      case TimelineItemKind.taskCompletion:
        return Icons.check_circle_outline;
      case TimelineItemKind.myTask:
        return Icons.task_alt;
      case TimelineItemKind.calendarEvent:
        return Icons.event_outlined;
      case TimelineItemKind.note:
        return Icons.sticky_note_2_outlined;
    }
  }

  Color get accentColor {
    switch (this) {
      case TimelineItemKind.aiConversation:
        return const Color(0xFF7C4DFF); // deep purple
      case TimelineItemKind.aiTask:
        return const Color(0xFFFFA000); // amber
      case TimelineItemKind.email:
        return const Color(0xFF1976D2); // blue
      case TimelineItemKind.textMessage:
        return const Color(0xFF00ACC1); // cyan
      case TimelineItemKind.phoneCall:
        return const Color(0xFF43A047); // green
      case TimelineItemKind.videoCall:
        return const Color(0xFF5E35B1); // indigo
      case TimelineItemKind.messageBoardPost:
        return const Color(0xFFEF6C00); // orange
      case TimelineItemKind.taskCompletion:
        return const Color(0xFF2E7D32); // dark green
      case TimelineItemKind.myTask:
        return const Color(0xFF00897B); // teal
      case TimelineItemKind.calendarEvent:
        return const Color(0xFF3949AB); // indigo
      case TimelineItemKind.note:
        return const Color(0xFFFBC02D); // amber
    }
  }
}

/// Sender direction on the timeline.
enum TimelineItemDirection { inbound, outbound, neutral }

/// One row on the unified communications timeline.
class TimelineItem {
  /// Stable identifier for list keying. Composed as `${kind}_${sourceId}`.
  /// Also used as the doc id of the per-member acknowledgement record.
  final String id;
  final TimelineItemKind kind;
  final DateTime timestamp;

  /// Short heading: email subject, post title, "AI Conversation", etc.
  final String title;

  /// One-sentence preview. Prefer an AI-generated summary; fall back to a
  /// truncated body or a synthetic description like "5 min call with Jane".
  final String summary;

  /// Human-readable label for who originated/sent the item.
  final String? senderLabel;

  /// Optional secondary line (e.g., recipient list for email, duration for
  /// a call, the event date/time for a calendar entry).
  final String? subline;

  /// Whether the user authored this (outbound) or received it (inbound).
  final TimelineItemDirection direction;

  /// Source document for drill-down. Doubles as the item's stable identity.
  final DocumentReference<Map<String, dynamic>>? sourceRef;

  /// Where a tap should actually navigate, when that is *not* [sourceRef].
  /// Message board timeline entries, for example, point at a separate
  /// `messageBoardPost` document.
  final DocumentReference<Map<String, dynamic>>? openRef;

  /// go_router path a tap should push (My Tasks deep-links, the calendar
  /// event form). Null for kinds opened via a [sourceRef]/[openRef] screen.
  final String? routePath;

  /// AI-role for `aiConversation` items so the renderer can choose
  /// user/assistant/system styling.
  final String? aiRole;

  /// Session id stamped on every `aiConversation` row produced by one
  /// canvas-open. The timeline renderer collapses consecutive rows that
  /// share this id into a single expandable card. Older rows written
  /// before bundling shipped will be null and render as standalone bubbles.
  final String? conversationId;

  /// Populated only for `aiTask` items — the full agent-task run, including
  /// its live step log. The timeline tile uses this to render the expandable
  /// progress checklist.
  final AgentTaskRun? agentRun;

  /// When the signed-in member acknowledged this item from the timeline.
  /// Populated by [TimelineFacadeRepository] from the per-member
  /// `timelineAck` collection — never set by the source factories.
  final DateTime? acknowledgedAt;

  /// True when the *source* document already records this item as
  /// handled — a read email, a completed My Task, an acknowledged agent
  /// run. Such items render as done regardless of [acknowledgedAt].
  final bool sourceResolved;

  /// True when this item needs a real decision in its own screen and so
  /// must not be swipe-completed from the timeline (option B for My Tasks:
  /// approval-style tasks open, they are not checked off in place).
  final bool actionRequired;

  const TimelineItem({
    required this.id,
    required this.kind,
    required this.timestamp,
    required this.title,
    required this.summary,
    this.senderLabel,
    this.subline,
    this.direction = TimelineItemDirection.neutral,
    this.sourceRef,
    this.openRef,
    this.routePath,
    this.aiRole,
    this.conversationId,
    this.agentRun,
    this.acknowledgedAt,
    this.sourceResolved = false,
    this.actionRequired = false,
  });

  /// Whether this item reads as handled on the timeline — drives the dimmed
  /// "marked read" treatment. A text thread re-surfaces as unread when a new
  /// message lands after the acknowledgement.
  bool get isAcknowledged {
    if (sourceResolved) return true;
    final acked = acknowledgedAt;
    if (acked == null) return false;
    if (kind == TimelineItemKind.textMessage) {
      return !acked.isBefore(timestamp);
    }
    return true;
  }

  /// Whether a left/right swipe on the tile should acknowledge it. AI chat
  /// bubbles and already-completed task rows have nothing to acknowledge;
  /// action-required My Tasks open instead of being checked off in place.
  bool get supportsAcknowledge {
    switch (kind) {
      case TimelineItemKind.email:
      case TimelineItemKind.textMessage:
      case TimelineItemKind.phoneCall:
      case TimelineItemKind.videoCall:
      case TimelineItemKind.messageBoardPost:
      case TimelineItemKind.calendarEvent:
      case TimelineItemKind.aiTask:
        return true;
      case TimelineItemKind.myTask:
        return !actionRequired;
      case TimelineItemKind.aiConversation:
      case TimelineItemKind.taskCompletion:
      case TimelineItemKind.note:
        return false;
    }
  }

  /// Returns a copy with [acknowledgedAt] overridden — used by the repository
  /// to fold in the per-member acknowledgement stream.
  TimelineItem copyWith({DateTime? acknowledgedAt}) {
    return TimelineItem(
      id: id,
      kind: kind,
      timestamp: timestamp,
      title: title,
      summary: summary,
      senderLabel: senderLabel,
      subline: subline,
      direction: direction,
      sourceRef: sourceRef,
      openRef: openRef,
      routePath: routePath,
      aiRole: aiRole,
      conversationId: conversationId,
      agentRun: agentRun,
      acknowledgedAt: acknowledgedAt ?? this.acknowledgedAt,
      sourceResolved: sourceResolved,
      actionRequired: actionRequired,
    );
  }

  // ───────────────── factories ─────────────────

  /// AI canvas message stored at `company/{id}/timeline` with
  /// `type == 'ai_canvas'`.
  factory TimelineItem.aiConversation(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    final role = _stringField(data, ['role', 'aiRole', 'senderRole']);
    final body = _stringField(data, ['bodyPlain', 'body', 'message', 'text']);
    final snippet = _stringField(data, ['snippet']) ?? '';
    final summary = (body != null && body.isNotEmpty)
        ? _truncate(body, 200)
        : snippet;
    final ts = _timestampField(data, ['timestamp', 'createdAt', 'internalDateMs']);
    final title = _stringField(data, ['title']) ??
        (role == 'user' ? 'You asked' : role == 'assistant' ? 'AI replied' : 'AI');
    final conversationId = _stringField(data, ['conversationId']);
    return TimelineItem(
      id: 'aiConversation_${doc.id}',
      kind: TimelineItemKind.aiConversation,
      timestamp: ts ?? DateTime.now(),
      title: title,
      summary: summary,
      aiRole: role,
      conversationId: conversationId,
      direction: role == 'user'
          ? TimelineItemDirection.outbound
          : TimelineItemDirection.inbound,
      sourceRef: doc.reference,
    );
  }

  /// Agent Task Run at top-level `agentTaskRuns/{id}`. Carries the run's
  /// live step log on [agentRun] so the timeline tile can render an
  /// expandable progress checklist while the agent works.
  factory TimelineItem.aiTask(DocumentSnapshot<Map<String, dynamic>> doc) {
    final run = AgentTaskRun.fromSnapshot(doc);
    final taskName = (run.taskName == null || run.taskName!.trim().isEmpty)
        ? 'AI task'
        : run.taskName!.trim();

    final String summary;
    switch (run.status) {
      case AgentTaskRunStatus.running:
        summary = run.progressLabel;
        break;
      case AgentTaskRunStatus.failed:
        final stepError = run.failedStep?.error;
        final runError = run.error?['message'] as String?;
        summary = _truncate(
          stepError ?? runError ?? 'The agent task failed.',
          200,
        );
        break;
      case AgentTaskRunStatus.readyForReview:
      case AgentTaskRunStatus.unknown:
        final failed = run.failedStep;
        if (failed != null) {
          summary = _truncate(
            failed.error ?? 'Stopped at "${failed.label}".',
            200,
          );
        } else {
          final narrative = run.output?.narrative ?? '';
          summary = narrative.trim().isEmpty
              ? 'Ready for review'
              : _truncate(narrative, 200);
        }
        break;
    }

    final ts = run.completedAt ?? run.startedAt;
    return TimelineItem(
      id: 'aiTask_${doc.id}',
      kind: TimelineItemKind.aiTask,
      timestamp: ts ?? DateTime.now(),
      title: taskName,
      summary: summary,
      direction: TimelineItemDirection.inbound,
      sourceRef: doc.reference,
      agentRun: run,
      sourceResolved: run.acknowledgedAt != null,
    );
  }

  /// Email at `company/{id}/member/{id}/email/{id}` (or the company-level
  /// `emailLog`). Set [idByMessageId] when merging the member's own copy with
  /// the company-log copy of the *same* message (different doc ids) so the
  /// funnel's id-dedup collapses them into one row.
  factory TimelineItem.email(
    DocumentSnapshot<Map<String, dynamic>> doc, {
    bool idByMessageId = false,
  }) {
    final data = doc.data() ?? const <String, dynamic>{};
    final subject = _stringField(data, ['subject']) ?? '(no subject)';
    final from = _stringField(data, ['from']) ?? '';
    final fromName = _stringField(data, ['fromName']) ?? from;
    final aiSummary = _stringField(data, ['aiSummary', 'emailSummary']);
    final snippet = _stringField(data, ['snippet', 'bodyPlain']) ?? '';
    final summary = (aiSummary != null && aiSummary.isNotEmpty)
        ? _truncate(aiSummary, 200)
        : _truncate(snippet, 200);
    final ts = _timestampField(data, ['receivedAt', 'sentAt', 'updatedAt']);
    final folder = _stringField(data, ['folder']) ?? 'INBOX';
    final messageId = _stringField(data, ['messageId']);
    final id = (idByMessageId && messageId != null)
        ? 'email_msg_$messageId'
        : 'email_${doc.id}';
    return TimelineItem(
      id: id,
      kind: TimelineItemKind.email,
      timestamp: ts ?? DateTime.now(),
      title: subject,
      summary: summary,
      senderLabel: fromName,
      direction: folder == 'Sent'
          ? TimelineItemDirection.outbound
          : TimelineItemDirection.inbound,
      sourceRef: doc.reference,
      sourceResolved: data['isRead'] == true,
    );
  }

  /// Text conversation summary at `company/{id}/textConversation/{convId}`.
  /// One timeline entry represents one conversation thread, surfacing the
  /// most recent message via the denormalized `lastMessage*` fields.
  factory TimelineItem.textConversation(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    final title = _stringField(data, ['title', 'name']) ?? 'Conversation';
    // Prefer AI summary if a summarizer Cloud Function has run.
    final lastMsg = _stringField(data, ['aiSummary', 'lastMessageText']) ?? '';
    final sender = _stringField(data, ['lastMessageSenderName']);
    final ts = _timestampField(data, ['lastMessageAt', 'updatedAt', 'createdAt']);
    return TimelineItem(
      id: 'textMessage_${doc.id}',
      kind: TimelineItemKind.textMessage,
      timestamp: ts ?? DateTime.now(),
      title: title,
      summary: lastMsg.isEmpty ? 'New conversation' : _truncate(lastMsg, 200),
      senderLabel: sender,
      direction: TimelineItemDirection.neutral,
      sourceRef: doc.reference,
    );
  }

  /// Phone or video call at `company/{id}/member/{id}/timeline/{id}`.
  factory TimelineItem.call(
    DocumentSnapshot<Map<String, dynamic>> doc, {
    required bool isVideo,
  }) {
    final data = doc.data() ?? const <String, dynamic>{};
    final title = _stringField(data, ['title']) ??
        (isVideo ? 'Video call' : 'Phone call');
    // Prefer AI summary if a summarizer Cloud Function has run.
    final rawSummary = _stringField(data, ['aiSummary', 'summary']) ?? '';
    final durationMin = (data['durationMinutes'] as num?)?.toInt();
    final ts = _timestampField(data, ['timestamp', 'createdAt', 'loggedAt']);
    final loggedByName = _stringField(data, ['loggedByName']) ??
        _stringField(data, ['createdByName']);
    final summary = rawSummary.isEmpty
        ? (durationMin != null ? '$durationMin min call' : 'Call logged')
        : _truncate(rawSummary, 200);
    return TimelineItem(
      id: '${isVideo ? 'videoCall' : 'phoneCall'}_${doc.id}',
      kind: isVideo
          ? TimelineItemKind.videoCall
          : TimelineItemKind.phoneCall,
      timestamp: ts ?? DateTime.now(),
      title: title,
      summary: summary,
      senderLabel: loggedByName,
      subline: durationMin != null ? '$durationMin min' : null,
      direction: TimelineItemDirection.neutral,
      sourceRef: doc.reference,
    );
  }

  /// Call summary on the COMPANY-level timeline (`company/{id}/timeline`
  /// with `timelineCategory == 'callSummary'`). This is the cross-member
  /// mirror written by the call/video summarizers — distinct from the
  /// per-member `timeline` call docs ([call]) in both field shape (`callType`,
  /// `startTime`/`endTime`) and doc id. Used by the uniform per-entity funnel,
  /// which reads the company-level collections.
  factory TimelineItem.companyCallSummary(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    final callType = _stringField(data, ['callType']) ?? '';
    final isVideo = callType == 'videoCall';
    final title = isVideo
        ? 'Video call'
        : (callType == 'phone' ? 'Phone call' : 'Voice call');
    final rawSummary = _stringField(data, ['summary', 'aiSummary']) ?? '';
    final ts = _timestampField(data, ['endTime', 'startTime', 'createdAt']);
    final names = (data['participantNames'] as List?)
            ?.whereType<String>()
            .where((s) => s.trim().isNotEmpty)
            .toList() ??
        const <String>[];
    return TimelineItem(
      id: '${isVideo ? 'videoCall' : 'phoneCall'}_${doc.id}',
      kind: isVideo
          ? TimelineItemKind.videoCall
          : TimelineItemKind.phoneCall,
      timestamp: ts ?? DateTime.now(),
      title: title,
      summary: rawSummary.isEmpty ? 'Call logged' : _truncate(rawSummary, 200),
      senderLabel: names.isEmpty ? null : names.join(', '),
      direction: TimelineItemDirection.neutral,
      sourceRef: doc.reference,
    );
  }

  /// Message board post timeline-ref doc at `company/{id}/timeline`
  /// with `timelineCategory == 'message_board_category'`. A tap opens the
  /// referenced `messageBoardPost` document, carried on [openRef].
  factory TimelineItem.messageBoardPost(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    final title = _stringField(data, ['title', 'name']) ?? 'Board post';
    // Prefer AI summary if a summarizer Cloud Function has run.
    final body = _stringField(data, ['aiSummary', 'content', 'body', 'bodyPlain', 'snippet']) ?? '';
    final ts = _timestampField(data, ['createdAt', 'timestamp']);
    final author = _stringField(data, ['createdByName']);
    final postRef = data['messageBoardPostId'];
    return TimelineItem(
      id: 'messageBoardPost_${doc.id}',
      kind: TimelineItemKind.messageBoardPost,
      timestamp: ts ?? DateTime.now(),
      title: title,
      summary: body.isEmpty ? 'New board post' : _truncate(body, 200),
      senderLabel: author,
      direction: TimelineItemDirection.inbound,
      sourceRef: doc.reference,
      openRef: postRef is DocumentReference<Map<String, dynamic>>
          ? postRef
          : null,
    );
  }

  /// Completed task on `company/{id}/timeline` whose `timelineCategory`
  /// is one of the task category IDs and which has a non-null
  /// `completeTimestamp`.
  factory TimelineItem.taskCompletion(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    final title = _stringField(
            data, ['title', 'name', 'taskName', 'userName']) ??
        'Task';
    final description =
        _stringField(data, ['description', 'summary', 'notes', 'snippet']) ?? '';
    final ts = _timestampField(data, ['completeTimestamp']) ?? DateTime.now();
    final completedBy =
        _stringField(data, ['completedByName', 'memberName', 'createdByName']);
    final summary = description.isEmpty ? 'Completed' : _truncate(description, 200);
    return TimelineItem(
      id: 'taskCompletion_${doc.id}',
      kind: TimelineItemKind.taskCompletion,
      timestamp: ts,
      title: title,
      summary: summary,
      senderLabel: completedBy,
      direction: TimelineItemDirection.outbound,
      sourceRef: doc.reference,
    );
  }

  /// Pending or recently-completed action item from the signed-in member's
  /// `company/{id}/member/{id}/myTask` subcollection. Positioned on the
  /// timeline at the moment it was assigned (`createdAt`). A tap deep-links
  /// to the source screen via [routePath].
  factory TimelineItem.myTask(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    final title = _stringField(data, ['title']) ?? 'Task';
    final description = _stringField(data, ['description', 'summary']) ?? '';
    final ts = _timestampField(data, ['createdAt']) ?? DateTime.now();
    final status = _stringField(data, ['status']) ?? 'pending';
    final routePath = _stringField(data, ['routePath']);
    // A My Task backed by a workflow document (an absence, a performance
    // review, …) is resolved by acting on that document — it must not be
    // checked off in place. A free-standing to-do has no such source.
    final hasSource = data['sourceRef'] != null ||
        (_stringField(data, ['sourcePath']) != null);
    return TimelineItem(
      id: 'myTask_${doc.id}',
      kind: TimelineItemKind.myTask,
      timestamp: ts,
      title: title,
      summary: description.isEmpty
          ? 'Action needed'
          : _truncate(description, 200),
      direction: TimelineItemDirection.inbound,
      sourceRef: doc.reference,
      routePath: routePath,
      actionRequired: hasSource,
      sourceResolved: status == 'completed',
    );
  }

  /// Calendar event timeline doc at `company/{id}/timeline` with
  /// `timelineCategory == kCalendarEventCategoryId`. A tap opens the event
  /// form/detail screen via [routePath].
  factory TimelineItem.calendarEvent(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    final name = _stringField(data, ['name', 'title']) ?? 'Calendar event';
    final ts = _timestampField(data, ['createdAt', 'startTime']);
    final start = _timestampField(data, ['startTime']);
    final end = _timestampField(data, ['endTime']);
    final isAllDay = data['isAllDay'] == true;
    final description = _stringField(data, ['description', 'notes']) ?? '';
    return TimelineItem(
      id: 'calendarEvent_${doc.id}',
      kind: TimelineItemKind.calendarEvent,
      timestamp: ts ?? start ?? DateTime.now(),
      title: name,
      summary: description.isEmpty ? '' : _truncate(description, 200),
      subline: _calendarSubline(start, end, isAllDay),
      direction: TimelineItemDirection.neutral,
      sourceRef: doc.reference,
    );
  }

  /// Supervisor note at `company/{id}/member/{id}/timeline/{id}` with
  /// `type == 'note'`. A private annotation a supervisor writes about a
  /// conversation, agreement, or observation — not visible to the subject
  /// employee, only to the note's author on their AI canvas and to the
  /// author when reviewing the subject's Communication tab.
  factory TimelineItem.note(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    final title = _stringField(data, ['title']) ?? 'Note';
    final body = _stringField(data, ['text', 'body', 'summary']) ?? '';
    final ts = _timestampField(data, ['timestamp', 'createdAt']);
    final author = _stringField(data, ['createdByName']);
    return TimelineItem(
      id: 'note_${doc.id}',
      kind: TimelineItemKind.note,
      timestamp: ts ?? DateTime.now(),
      title: title,
      summary: body.isEmpty ? 'Note' : _truncate(body, 200),
      senderLabel: author,
      direction: TimelineItemDirection.outbound,
      sourceRef: doc.reference,
    );
  }

  // ───────────────── helpers ─────────────────

  static String? _stringField(Map<String, dynamic> data, List<String> keys) {
    for (final k in keys) {
      final v = data[k];
      if (v is String && v.isNotEmpty) return v;
    }
    return null;
  }

  static DateTime? _timestampField(Map<String, dynamic> data, List<String> keys) {
    for (final k in keys) {
      final v = data[k];
      if (v is Timestamp) return v.toDate();
      if (v is num) return DateTime.fromMillisecondsSinceEpoch(v.toInt());
      if (v is DateTime) return v;
    }
    return null;
  }

  static String _truncate(String s, int max) {
    final compact = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (compact.length <= max) return compact;
    return '${compact.substring(0, max - 1)}…';
  }

  /// Human-readable "when" line for a calendar event tile.
  static String? _calendarSubline(
    DateTime? start,
    DateTime? end,
    bool isAllDay,
  ) {
    if (start == null) return null;
    final s = start.toLocal();
    if (isAllDay) {
      if (end != null) {
        final e = end.toLocal();
        final eDay = DateTime(e.year, e.month, e.day);
        final sDay = DateTime(s.year, s.month, s.day);
        if (eDay.isAfter(sDay)) {
          return 'All day · ${DateFormat.MMMd().format(s)} – '
              '${DateFormat.MMMd().format(e)}';
        }
      }
      return 'All day · ${DateFormat.MMMEd().format(s)}';
    }
    final startLabel = DateFormat.MMMEd().add_jm().format(s);
    if (end != null) {
      final e = end.toLocal();
      if (e.year == s.year && e.month == s.month && e.day == s.day) {
        return '$startLabel – ${DateFormat.jm().format(e)}';
      }
    }
    return startLabel;
  }
}
