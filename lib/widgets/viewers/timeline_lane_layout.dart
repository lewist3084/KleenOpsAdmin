import 'package:syncfusion_flutter_calendar/calendar.dart' as sf;

/// Helper that maps overlapping timeline appointments into distinct lanes so
/// the calendar can expose a vertical scroll instead of compressing bars.
class TimelineLaneLayout {
  const TimelineLaneLayout({
    required this.appointments,
    required this.resources,
    required this.laneCount,
  });

  const TimelineLaneLayout.empty()
      : appointments = const <sf.Appointment>[],
        resources = const <sf.CalendarResource>[],
        laneCount = 0;

  final List<sf.Appointment> appointments;
  final List<sf.CalendarResource> resources;
  final int laneCount;
}

TimelineLaneLayout buildTimelineLaneLayout(List<sf.Appointment> source) {
  if (source.isEmpty) {
    return const TimelineLaneLayout.empty();
  }

  final clones = List<sf.Appointment>.generate(
    source.length,
    (index) => _cloneAppointment(source[index]),
  );
  final assignments = List<int>.filled(clones.length, 0);

  final indices = List<int>.generate(clones.length, (i) => i)
    ..sort((a, b) {
      final aStart = clones[a].startTime;
      final bStart = clones[b].startTime;
      final cmp = aStart.compareTo(bStart);
      if (cmp != 0) {
        return cmp;
      }
      return clones[a].endTime.compareTo(clones[b].endTime);
    });

  final laneEndTimes = <DateTime>[];

  for (final idx in indices) {
    final appt = clones[idx];
    final start = appt.startTime;
    final end = appt.endTime;

    var lane = -1;
    for (var i = 0; i < laneEndTimes.length; i++) {
      if (!start.isBefore(laneEndTimes[i])) {
        lane = i;
        break;
      }
    }

    if (lane == -1) {
      laneEndTimes.add(end);
      lane = laneEndTimes.length - 1;
    } else if (end.isAfter(laneEndTimes[lane])) {
      laneEndTimes[lane] = end;
    }

    assignments[idx] = lane;
    if (end.isAfter(laneEndTimes[lane])) {
      laneEndTimes[lane] = end;
    }
  }

  final laneCount = laneEndTimes.length;
  if (laneCount <= 1) {
    return TimelineLaneLayout(
      appointments: clones,
      resources: const <sf.CalendarResource>[],
      laneCount: laneCount,
    );
  }

  final resources = List<sf.CalendarResource>.generate(
    laneCount,
    (lane) => sf.CalendarResource(
      id: 'lane_$lane',
      displayName: '',
    ),
  );

  for (var i = 0; i < clones.length; i++) {
    clones[i].resourceIds = <Object>['lane_${assignments[i]}'];
  }

  return TimelineLaneLayout(
    appointments: clones,
    resources: resources,
    laneCount: laneCount,
  );
}

sf.Appointment _cloneAppointment(sf.Appointment original) {
  return sf.Appointment(
    startTime: original.startTime,
    endTime: original.endTime,
    subject: original.subject,
    color: original.color,
    startTimeZone: original.startTimeZone,
    endTimeZone: original.endTimeZone,
    recurrenceRule: original.recurrenceRule,
    isAllDay: original.isAllDay,
    notes: original.notes,
    location: original.location,
    recurrenceId: original.recurrenceId,
    id: original.id,
    resourceIds: original.resourceIds == null
        ? null
        : List<Object>.from(original.resourceIds!),
    recurrenceExceptionDates: original.recurrenceExceptionDates == null
        ? null
        : List<DateTime>.from(original.recurrenceExceptionDates!),
  );
}

