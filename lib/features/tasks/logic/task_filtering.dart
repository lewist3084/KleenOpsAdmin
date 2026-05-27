import 'package:meta/meta.dart';

/// Lightweight view of a task timeline entry used for filtering/sorting.
@immutable
class TaskFilterEntry {
  const TaskFilterEntry({
    required this.id,
    required this.startTime,
    required this.lowerName,
    required this.priorityActive,
    required this.blackout,
    required this.skip,
    required this.done,
    required this.hasActiveContributor,
    required this.isDependent,
    required this.isFlagged,
    required this.matchesSearch,
    required this.lockUserIds,
    this.hasActiveTimer = false,
  });

  final String id;
  final DateTime startTime;
  final String lowerName;
  final bool priorityActive;
  final bool blackout;
  final bool skip;
  final bool done;
  final bool hasActiveContributor;
  final bool isDependent;
  final bool isFlagged;
  final bool matchesSearch;

  /// Bare member document ids (last path segment). Compare against
  /// `memberRef.id`, not `memberRef.path`.
  final List<String> lockUserIds;
  final bool hasActiveTimer;
}

/// User/UI preferences that influence filtering.
@immutable
class TaskFilterOptions {
  const TaskFilterOptions({
    required this.showFlagged,
    required this.showCompleted,
    required this.showBlackouts,
    required this.showSkipped,
    required this.showPriority,
    required this.showDependents,
    required this.pacingEnabled,
    required this.disablePacing,
    required this.paceMinutes,
    required this.memberId,
    required this.now,
    this.globalAnchor,
  });

  final bool showFlagged;
  final bool showCompleted;
  final bool showBlackouts;
  final bool showSkipped;
  final bool showPriority;
  final bool showDependents;
  final bool pacingEnabled;
  final bool disablePacing;
  final int paceMinutes;

  /// Bare member document id (memberRef.id). Used to evaluate `lockUser`.
  final String memberId;
  final DateTime now;

  /// Pacing anchor computed across the user's full eligible set, not just the
  /// per-team slice passed into [filterAndSortTasks]. When provided, the
  /// per-team filter will use this instead of computing its own anchor.
  /// Each team still applies its own [paceMinutes] window length on top.
  final DateTime? globalAnchor;
}

@immutable
class TaskFilterResult {
  const TaskFilterResult({
    required this.items,
    required this.collapseActive,
    this.debug,
  });

  final List<TaskFilterEntry> items;
  final bool collapseActive;
  final TaskFilterDebug? debug;
}

@immutable
class TaskFilterDebug {
  const TaskFilterDebug({
    required this.totalEntries,
    required this.filteredCount,
    required this.collapseActive,
    required this.earliestOpen,
    required this.lockedOutCount,
    required this.withinPaceCount,
    required this.hasActiveContributorCount,
    required this.doneCount,
    required this.skippedCount,
    required this.blackoutCount,
  });

  final int totalEntries;
  final int filteredCount;
  final bool collapseActive;
  final DateTime? earliestOpen;
  final int lockedOutCount;
  final int withinPaceCount;
  final int hasActiveContributorCount;
  final int doneCount;
  final int skippedCount;
  final int blackoutCount;
}

/// Returns true when [entry]'s `lockUser` array excludes [memberId]. An
/// empty array means the task isn't locked to anyone in particular.
/// Comparison is by bare member id so the lock matches regardless of
/// whether the doc field stored a DocumentReference, a full path, or a
/// bare id string.
bool _entryLockedOut(TaskFilterEntry entry, String memberId) {
  if (entry.lockUserIds.isEmpty) return false;
  return entry.lockUserIds.every((id) => id != memberId);
}

/// True when [entry] is "open" — eligible to be picked up — and therefore a
/// candidate for anchoring the pacing window. Mirrors the visibility filters
/// in `filterAndSortTasks` so the anchor never lands on an entry that
/// wouldn't actually appear in the list — e.g. a dependent task hidden by
/// `showDependents=false`, or one filtered out by an active search.
bool isOpenForAnchor(
  TaskFilterEntry entry,
  String memberId, {
  bool showDependents = true,
}) {
  if (_entryLockedOut(entry, memberId)) return false;
  // A hidden dependent task isn't shown in the list, so it shouldn't be
  // allowed to dictate where today's pacing wave starts. Without this guard
  // a 5AM dependent task drags the anchor before the actual workday and
  // pushes today's 6AM open tasks out of a ~60min window.
  if (entry.isDependent && !showDependents) return false;
  // Search-hidden entries also shouldn't anchor — same principle.
  if (!entry.matchesSearch) return false;
  if (entry.skip ||
      entry.done ||
      entry.hasActiveContributor ||
      entry.blackout ||
      entry.hasActiveTimer) {
    return false;
  }
  return true;
}

/// Earliest start time among entries that are "open" for [memberId]. Intended
/// to be called once over the user's full eligible set (across all teams) so
/// every team's per-team filter shares one anchor — without this hoist a user
/// on multiple teams gets one independent wave per team, which causes the
/// "view jumps from 6:30 to 10:30" symptom when one team's earliest open task
/// is much later than another's.
///
/// [minStart], when provided, excludes anchor candidates whose `startTime` is
/// before it. The screen passes the start of the day being viewed so a
/// multi-day or carryover task that started yesterday — but is still "open"
/// today because it hasn't been completed — does not drag today's pacing
/// window back 24h. Such tasks remain visible via active-contributor / timer /
/// priority paths if they're being worked on; they just can't dictate the
/// anchor.
///
/// [showDependents] mirrors the user's "show dependents" toggle so a hidden
/// dependent task can't anchor a wave the user can't see.
DateTime? computeEarliestOpenAnchor({
  required Iterable<TaskFilterEntry> entries,
  required String memberId,
  DateTime? minStart,
  bool showDependents = true,
}) {
  DateTime? earliestOpen;
  for (final entry in entries) {
    if (!isOpenForAnchor(entry, memberId, showDependents: showDependents)) {
      continue;
    }
    if (minStart != null && entry.startTime.isBefore(minStart)) continue;
    if (earliestOpen == null || entry.startTime.isBefore(earliestOpen)) {
      earliestOpen = entry.startTime;
    }
  }
  return earliestOpen;
}

/// Mirrors the filtering logic used in the task screen so it can be tested
/// separately from widgets.
TaskFilterResult filterAndSortTasks({
  required List<TaskFilterEntry> entries,
  required TaskFilterOptions options,
}) {
  if (entries.isEmpty) {
    return const TaskFilterResult(items: <TaskFilterEntry>[], collapseActive: false);
  }

  bool isLockedOut(TaskFilterEntry entry) =>
      _entryLockedOut(entry, options.memberId);

  final collapseActive = entries.any(
    (entry) =>
        !isLockedOut(entry) &&
        entry.matchesSearch &&
        entry.priorityActive &&
        !entry.skip &&
        !entry.blackout &&
        !entry.done &&
        !entry.hasActiveContributor,
  );

  // Use the caller-supplied global anchor when available so a multi-team user
  // sees one coherent wave; fall back to a local anchor otherwise.
  DateTime? earliestOpen;
  if (options.pacingEnabled && !options.disablePacing) {
    earliestOpen = options.globalAnchor ??
        computeEarliestOpenAnchor(
          entries: entries,
          memberId: options.memberId,
          showDependents: options.showDependents,
        );
  }

  bool withinPace(TaskFilterEntry entry) {
    if (!options.pacingEnabled || earliestOpen == null) {
      return true;
    }
    final diff = entry.startTime.difference(earliestOpen).inMinutes;
    return diff >= 0 && diff <= options.paceMinutes;
  }

  final filtered = <TaskFilterEntry>[];
  for (final entry in entries) {
    // Dependents are controlled by a dedicated toggle and should be
    // excluded early when the toggle is off.
    if (entry.isDependent && !options.showDependents) continue;
    if (entry.isFlagged && options.showFlagged) {
      filtered.add(entry);
      continue;
    }
    if (entry.done && options.showCompleted) {
      filtered.add(entry);
      continue;
    }
    if (isLockedOut(entry)) continue;
    if (!entry.matchesSearch) continue;
    if (entry.done && !options.showCompleted) continue;
    if (!entry.done && !entry.hasActiveContributor && entry.blackout && !options.showBlackouts) {
      continue;
    }
    if (entry.skip &&
        !options.showSkipped &&
        !entry.hasActiveContributor) {
      continue;
    }
    if (entry.hasActiveContributor) {
      filtered.add(entry);
      continue;
    }
    // A held/paused task (timer running) is "engaged" the same way an active
    // contributor is: don't anchor the pacing window on it (handled above)
    // and don't subject it to the window check here either, otherwise a 6AM
    // paused task gets dropped against a later anchor while pacing is on but
    // reappears the moment pacing is disabled.
    if (entry.hasActiveTimer) {
      filtered.add(entry);
      continue;
    }

    if (collapseActive && !options.showPriority && !options.disablePacing) {
      // Priority collapse should not override the pacing window. Keep
      // priority tasks visible, but still allow paced tasks through.
      if (entry.priorityActive || withinPace(entry)) {
        filtered.add(entry);
      }
      continue;
    }

    if (options.showPriority) {
      if (entry.priorityActive || entry.hasActiveContributor || withinPace(entry)) {
        filtered.add(entry);
      }
      continue;
    }

    if (options.pacingEnabled && !withinPace(entry)) continue;

    if (entry.priorityActive || withinPace(entry)) {
      filtered.add(entry);
    }
  }

  filtered.sort((a, b) {
    final cmp = a.startTime.compareTo(b.startTime);
    if (cmp != 0) return cmp;
    return a.lowerName.compareTo(b.lowerName);
  });

  // Build lightweight debug stats to help diagnose pacing/collapse behavior.
  var lockedOutCount = 0;
  var withinPaceCount = 0;
  var hasActiveContributorCount = 0;
  var doneCount = 0;
  var skippedCount = 0;
  var blackoutCount = 0;

  for (final entry in entries) {
    final lockedOut = isLockedOut(entry);
    if (lockedOut) lockedOutCount += 1;
    if (withinPace(entry)) withinPaceCount += 1;
    if (entry.hasActiveContributor) hasActiveContributorCount += 1;
    if (entry.done) doneCount += 1;
    if (entry.skip) skippedCount += 1;
    if (entry.blackout) blackoutCount += 1;
  }

  final debug = TaskFilterDebug(
    totalEntries: entries.length,
    filteredCount: filtered.length,
    collapseActive: collapseActive,
    earliestOpen: earliestOpen,
    lockedOutCount: lockedOutCount,
    withinPaceCount: withinPaceCount,
    hasActiveContributorCount: hasActiveContributorCount,
    doneCount: doneCount,
    skippedCount: skippedCount,
    blackoutCount: blackoutCount,
  );

  return TaskFilterResult(
    items: filtered,
    collapseActive: collapseActive,
    debug: debug,
  );
}
