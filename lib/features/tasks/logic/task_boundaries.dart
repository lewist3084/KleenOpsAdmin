import 'package:cloud_firestore/cloud_firestore.dart';

/// Time-based "interesting moments" for a timeline task doc — the
/// instants at which client-side filter logic would change its answer
/// for the task. Used by `TimeBasedRebuildMixin` so screens fire a
/// precise rebuild at each boundary instead of polling.
///
/// Boundaries included (only those strictly after `now`):
/// - each blackout `startTime` and `endTime`
/// - `startTime + priorityDelay` minutes (priority activation moment)
/// - `endTimeExtended - 24h` (priorityOnLastDay activation moment)
/// - `endTimeExtended` itself (do-until-complete window closes)
///
/// Pass any task timeline doc's `data` map; non-applicable fields are
/// skipped. Returns boundaries in unspecified order.
Iterable<DateTime> collectTaskBoundaries(
  Map<String, dynamic> data,
  DateTime now,
) sync* {
  // Blackouts
  final rawBlackouts = data['blackouts'];
  Iterable<dynamic> intervals;
  if (rawBlackouts is List) {
    intervals = rawBlackouts;
  } else if (rawBlackouts is Map) {
    final inner = rawBlackouts['blackoutInterval'];
    if (inner is List) {
      intervals = inner;
    } else if (inner != null) {
      intervals = [inner];
    } else {
      intervals = [rawBlackouts];
    }
  } else {
    intervals = const [];
  }
  for (final entry in intervals) {
    if (entry is! Map) continue;
    final s = entry['startTime'];
    final e = entry['endTime'];
    if (s is Timestamp) {
      final d = s.toDate();
      if (d.isAfter(now)) yield d;
    }
    if (e is Timestamp) {
      final d = e.toDate();
      if (d.isAfter(now)) yield d;
    }
  }

  // priorityDelay completion (only matters when priority=true)
  if (data['priority'] == true) {
    final startRaw = data['startTime'];
    final delayRaw = data['priorityDelay'];
    final delayMin = delayRaw is int
        ? delayRaw
        : (delayRaw is num ? delayRaw.toInt() : null);
    if (startRaw is Timestamp && delayMin != null && delayMin > 0) {
      final activate = startRaw.toDate().add(Duration(minutes: delayMin));
      if (activate.isAfter(now)) yield activate;
    }
  }

  // priorityOnLastDay activation — last 24h of endTimeExtended
  if (data['priorityOnLastDay'] == true && data['untilComplete'] == true) {
    final endExt = data['endTimeExtended'];
    if (endExt is Timestamp) {
      final lastDayStart =
          endExt.toDate().subtract(const Duration(hours: 24));
      if (lastDayStart.isAfter(now)) yield lastDayStart;
    }
  }

  // endTimeExtended itself (task's do-until-complete window closes)
  final endExt = data['endTimeExtended'];
  if (endExt is Timestamp) {
    final d = endExt.toDate();
    if (d.isAfter(now)) yield d;
  }
}

/// Earliest task-related boundary across a collection of timeline doc
/// data maps. Caps look-ahead by [maxLookAhead] so screens don't
/// schedule absurdly distant timers (Dart's Timer max is large but the
/// 5-min safety net in the mixin will re-pick it up anyway).
DateTime? earliestUpcomingBoundary({
  required Iterable<Map<String, dynamic>> datas,
  required DateTime now,
  Duration maxLookAhead = const Duration(hours: 6),
}) {
  final ceiling = now.add(maxLookAhead);
  DateTime? earliest;
  for (final data in datas) {
    for (final b in collectTaskBoundaries(data, now)) {
      if (b.isAfter(ceiling)) continue;
      if (earliest == null || b.isBefore(earliest)) earliest = b;
    }
  }
  return earliest;
}

/// Returns the next wall-clock midnight strictly after [now]. Useful for
/// screens that filter by weekday or "today" — they need to rebuild
/// when the date rolls.
DateTime nextMidnightAfter(DateTime now) {
  return DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
}

/// Returns the next top-of-hour strictly after [now].
DateTime nextHourAfter(DateTime now) {
  return DateTime(now.year, now.month, now.day, now.hour + 1);
}
