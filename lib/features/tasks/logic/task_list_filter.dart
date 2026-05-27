import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kleenops_admin/features/tasks/logic/task_filtering.dart';
import 'package:kleenops_admin/features/tasks/logic/task_data_logic.dart';

Map<String, dynamic> _asMap(Map? raw) =>
    (raw ?? const <String, dynamic>{}).cast<String, dynamic>();

class TaskListFilterResult {
  const TaskListFilterResult({
    required this.filteredDocs,
    required this.collapse,
    required this.debug,
  });

  final List<QueryDocumentSnapshot<Map<String, dynamic>>> filteredDocs;
  final bool collapse;
  final TaskFilterDebug? debug;
}

/// Builds a single filter entry from a Firestore doc/data pair. Exposed so
/// callers can build a global entry list (across all teams) and compute one
/// shared pacing anchor before invoking the per-team filter.
///
/// When [viewDay] is provided, the entry's `startTime` is projected onto that
/// day while preserving the original time-of-day. This mirrors the UI's
/// time-of-day grouping in TaskListView and is what makes carryover /
/// "scheduled until complete" tasks anchor at today's same-time-of-day instead
/// of dragging the pacing window back to whatever calendar date they were
/// originally created on.
TaskFilterEntry buildTaskFilterEntry({
  required String docId,
  required Map<String, dynamic> data,
  required DateTime now,
  required String searchLower,
  DateTime? viewDay,
}) {
  final ac = _asMap(data['activeContributors'] as Map<Object?, Object?>?);
  final blk = isInBlackout(data, now);
  final skip = data['skip'] == true;
  final done = data['completeTimestamp'] != null;
  final pr = isPriorityActive(data, now);
  final isDependent = data['dependent'] == true;
  final timerEndRaw = data['timerEndTime'];
  final hasActiveTimer =
      timerEndRaw is Timestamp && timerEndRaw.toDate().isAfter(now);

  final onStartRefs = (data['alertOnStart'] as List?) ?? const [];
  final onCompleteRefs = (data['alertWhenComplete'] as List?) ?? const [];
  final bool isFlagged =
      onStartRefs.isNotEmpty || onCompleteRefs.isNotEmpty;

  // Accept lockUser as DocumentReference, full path string, or bare id
  // string. Also honour the legacy `lockUsers` / `lockedUsers` field
  // names. Comparison happens by bare id so storage shape doesn't matter.
  final lockRaw =
      data['lockUser'] ?? data['lockUsers'] ?? data['lockedUsers'];
  final lockList = <String>[];
  if (lockRaw is Iterable) {
    for (final entry in lockRaw) {
      if (entry is DocumentReference) {
        lockList.add(entry.id);
      } else if (entry is String) {
        final t = entry.trim();
        if (t.isEmpty) continue;
        lockList.add(t.contains('/') ? t.split('/').last : t);
      }
    }
  }

  final lowerName = (data['name'] ?? '').toString().toLowerCase();
  final matchesSearch =
      searchLower.isEmpty || lowerName.contains(searchLower);

  final rawStart = (data['startTime'] as Timestamp).toDate();
  final startTime = viewDay == null
      ? rawStart
      : DateTime(
          viewDay.year,
          viewDay.month,
          viewDay.day,
          rawStart.hour,
          rawStart.minute,
          rawStart.second,
          rawStart.millisecond,
        );

  return TaskFilterEntry(
    id: docId,
    startTime: startTime,
    lowerName: lowerName,
    priorityActive: pr,
    blackout: blk,
    skip: skip,
    done: done,
    hasActiveContributor: ac.isNotEmpty,
    isDependent: isDependent,
    isFlagged: isFlagged,
    matchesSearch: matchesSearch,
    lockUserIds: lockList,
    hasActiveTimer: hasActiveTimer,
  );
}

/// Builds filter entries from Firestore docs and delegates the actual
/// filtering/sorting to the pure helper `filterAndSortTasks`.
TaskListFilterResult filterTaskDocs({
  required List<QueryDocumentSnapshot<Map<String, dynamic>>> eligibleDocs,
  required Map<String, Map<String, dynamic>> dataByDocId,
  required DocumentReference<Map<String, dynamic>> memberRef,
  required DateTime now,
  required bool showFlagged,
  required bool showCompleted,
  required bool showBlackouts,
  required bool showSkipped,
  required bool showPriority,
  required bool showDependents,
  required bool pacingEnabled,
  required bool disablePacing,
  required int paceMinutes,
  required String searchLower,
  DateTime? globalAnchor,
  DateTime? viewDay,
}) {
  if (eligibleDocs.isEmpty) {
    return const TaskListFilterResult(
      filteredDocs: <QueryDocumentSnapshot<Map<String, dynamic>>>[],
      collapse: false,
      debug: null,
    );
  }

  final docById = {
    for (final doc in eligibleDocs) doc.id: doc,
  };

  final entries = <TaskFilterEntry>[];
  for (final doc in eligibleDocs) {
    final data = dataByDocId[doc.id] ?? const <String, dynamic>{};
    entries.add(
      buildTaskFilterEntry(
        docId: doc.id,
        data: data,
        now: now,
        searchLower: searchLower,
        viewDay: viewDay,
      ),
    );
  }

  final filterResult = filterAndSortTasks(
    entries: entries,
    options: TaskFilterOptions(
      showFlagged: showFlagged,
      showCompleted: showCompleted,
      showBlackouts: showBlackouts,
      showSkipped: showSkipped,
      showPriority: showPriority,
      showDependents: showDependents,
      pacingEnabled: pacingEnabled,
      disablePacing: disablePacing,
      paceMinutes: paceMinutes,
      memberId: memberRef.id,
      now: now,
      globalAnchor: globalAnchor,
    ),
  );

  final filteredDocs = filterResult.items
      .map((entry) => docById[entry.id])
      .whereType<QueryDocumentSnapshot<Map<String, dynamic>>>()
      .toList(growable: false);

  return TaskListFilterResult(
    filteredDocs: filteredDocs,
    collapse: filterResult.collapseActive,
    debug: filterResult.debug,
  );
}
