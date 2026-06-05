import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_calendar/calendar.dart' as sf;

/// Builds a set of thin [sf.TimeRegion] entries aligned to each time interval
/// so we can render custom vertical grid lines in timeline views.
List<sf.TimeRegion> buildTimelineGridRegions({
  required Iterable<DateTime> visibleDates,
  Duration interval = const Duration(hours: 1),
  double startHour = 0,
  double endHour = 24,
  Color color = const Color(0xFFDDDDDD),
}) {
  final minutes = interval.inMinutes.abs();
  if (minutes == 0) {
    return const <sf.TimeRegion>[];
  }

  final startMinutes = (startHour * 60).floor();
  final endMinutes = (endHour * 60).floor();
  if (endMinutes <= startMinutes) {
    return const <sf.TimeRegion>[];
  }

  final days = {
    for (final date in visibleDates) DateTime(date.year, date.month, date.day)
  }.toList()
    ..sort();

  if (days.isEmpty) {
    return const <sf.TimeRegion>[];
  }

  final regions = <sf.TimeRegion>[];
  for (final day in days) {
    for (var minute = startMinutes; minute < endMinutes; minute += minutes) {
      final start = day.add(Duration(minutes: minute));
      final end = start.add(const Duration(minutes: 1));
      regions.add(
        sf.TimeRegion(
          startTime: start,
          endTime: end,
          enablePointerInteraction: false,
          color: color,
        ),
      );
    }
  }
  return regions;
}

/// Compares two timeline region lists for equality based on time span and color.
bool timelineRegionsEqual(List<sf.TimeRegion> a, List<sf.TimeRegion> b) {
  if (identical(a, b)) {
    return true;
  }
  if (a.length != b.length) {
    return false;
  }
  for (var i = 0; i < a.length; i++) {
    final first = a[i];
    final second = b[i];
    if (first.startTime != second.startTime ||
        first.endTime != second.endTime ||
        first.color != second.color) {
      return false;
    }
  }
  return true;
}

