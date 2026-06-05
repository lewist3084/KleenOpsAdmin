// lib/common/communications/calendar/calendar.dart
//
// Communications calendar. Renders the polymorphic company `timeline`
// collection as a set of toggleable layers (calendar events, absences,
// tasks, requests, quality, scheduled work, actual worked time). Each
// layer is a date-window-scoped Firestore query; only enabled layers are
// subscribed, so the default view loads just events + absences instead of
// every doc-shape in the window.
//
// Supports search, header view-switch, live drag-and-drop / resize that
// persists to Firestore (editable layers only), and tap-to-edit / tap-to-add.
// Tested with Syncfusion Flutter Calendar 19.x â€“ 22.x.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod/legacy.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:syncfusion_flutter_calendar/calendar.dart' as sf;
import 'package:kleenops_admin/app/routes.dart';
import 'package:kleenops_admin/widgets/viewers/timeline_lane_layout.dart';
import 'package:kleenops_admin/widgets/viewers/timeline_grid_regions.dart';
import 'package:kleenops_admin/features/auth/providers/auth_provider.dart';
import 'package:kleenops_admin/app/shared_widgets/search/search_control_strip_adapter.dart';
import 'package:shared_widgets/dialogs/dialog_action.dart';
import 'package:shared_widgets/labels/text_info_checkbox.dart';
import 'package:kleenops_admin/common/utils/snackbar_service.dart';

/// Visibility flag for the communications calendar search strip. The
/// parent app bar toggles this; [CalendarContent] watches it to render
/// the inline search control.
final calendarSearchVisibleProvider = StateProvider<bool>((_) => false);

/// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ Layer model â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
///
/// Each [CalendarLayer] is one toggleable data source. Most are a single
/// `timelineCategory` value on the polymorphic `timeline` collection;
/// [CalendarLayer.absences] is keyed off the `isAbsence` flag instead.

/// `timelineCategory` ID for manually-created calendar events. Reused from
/// the legacy calendar; the event form now stamps it so events are queryable.
const String kCalendarEventCategoryId = 'in0MAUlQmUXiwXGoqWX7';
const String _kRequestCategoryId = 'ZOQH1ojP4a6QgRKCFTr8';
const String _kQualityCategoryId = 'VdjzT5izZVSWmrhfRRq0';
const String _kScheduledWorkCategoryId = 'ZLAjjDKp3hgRankr4sQ8';
const String _kTimecardCategoryId = 'X8yZRs8e8xXyHPl4VNAN';

/// Task-family `timelineCategory` IDs grouped under the single "Tasks" layer:
/// completed tasks, scheduled tasks, and ad-hoc / unscheduled tasks.
const List<String> _kTaskCategoryIds = <String>[
  'E2HMUuMUUl4Alttuweba', // completed tasks
  'kG9DMLORk88VrZIGD7x3', // scheduled task
  'Rpl9Mn34gJBdZ007jXpo', // ad-hoc / unscheduled task
];

enum CalendarLayer {
  calendarEvents,
  absences,
  tasks,
  requests,
  quality,
  scheduledToWork,
  actuallyWorked,
}

/// Layers checked on every app launch â€” the cheap default load.
const Set<CalendarLayer> kDefaultCalendarLayers = {
  CalendarLayer.calendarEvents,
  CalendarLayer.absences,
};

/// `timelineCategory` IDs a layer maps to. Empty for [CalendarLayer.absences],
/// which is queried via the `isAbsence` flag, not a category.
List<String> _categoriesForLayer(CalendarLayer layer) {
  switch (layer) {
    case CalendarLayer.calendarEvents:
      return const [kCalendarEventCategoryId];
    case CalendarLayer.tasks:
      return _kTaskCategoryIds;
    case CalendarLayer.requests:
      return const [_kRequestCategoryId];
    case CalendarLayer.quality:
      return const [_kQualityCategoryId];
    case CalendarLayer.scheduledToWork:
      return const [_kScheduledWorkCategoryId];
    case CalendarLayer.actuallyWorked:
      return const [_kTimecardCategoryId];
    case CalendarLayer.absences:
      return const [];
  }
}

/// Reverse lookup: which layer a fetched doc belongs to, for colouring and
/// tap routing. Defaults to [CalendarLayer.calendarEvents] for unknown IDs.
CalendarLayer _layerForCategory(String categoryId) {
  if (categoryId == kCalendarEventCategoryId) {
    return CalendarLayer.calendarEvents;
  }
  if (_kTaskCategoryIds.contains(categoryId)) return CalendarLayer.tasks;
  if (categoryId == _kRequestCategoryId) return CalendarLayer.requests;
  if (categoryId == _kQualityCategoryId) return CalendarLayer.quality;
  if (categoryId == _kScheduledWorkCategoryId) {
    return CalendarLayer.scheduledToWork;
  }
  if (categoryId == _kTimecardCategoryId) return CalendarLayer.actuallyWorked;
  return CalendarLayer.calendarEvents;
}

String layerLabel(CalendarLayer layer) {
  switch (layer) {
    case CalendarLayer.calendarEvents:
      return 'Calendar events';
    case CalendarLayer.absences:
      return 'Absences';
    case CalendarLayer.tasks:
      return 'Tasks';
    case CalendarLayer.requests:
      return 'Requests';
    case CalendarLayer.quality:
      return 'Quality reports';
    case CalendarLayer.scheduledToWork:
      return 'Scheduled to work';
    case CalendarLayer.actuallyWorked:
      return 'Actually worked';
  }
}

IconData _layerIcon(CalendarLayer layer) {
  switch (layer) {
    case CalendarLayer.calendarEvents:
      return Icons.event_outlined;
    case CalendarLayer.absences:
      return Icons.beach_access_outlined;
    case CalendarLayer.tasks:
      return Icons.task_alt;
    case CalendarLayer.requests:
      return Icons.assignment_outlined;
    case CalendarLayer.quality:
      return Icons.verified_outlined;
    case CalendarLayer.scheduledToWork:
      return Icons.schedule;
    case CalendarLayer.actuallyWorked:
      return Icons.punch_clock_outlined;
  }
}

Color _layerColor(CalendarLayer layer) {
  switch (layer) {
    case CalendarLayer.calendarEvents:
      return const Color(0xFF3949AB); // indigo
    case CalendarLayer.absences:
      return const Color(0xFFEF6C00); // orange
    case CalendarLayer.tasks:
      return const Color(0xFF00838F); // cyan
    case CalendarLayer.requests:
      return const Color(0xFF6A1B9A); // purple
    case CalendarLayer.quality:
      return const Color(0xFF4E342E); // brown
    case CalendarLayer.scheduledToWork:
      return const Color(0xFF1565C0); // blue
    case CalendarLayer.actuallyWorked:
      return const Color(0xFF2E7D32); // green
  }
}

/// Only these layers map back to editable docs reachable from the event
/// form; the rest (tasks, timecards, â€¦) are read-only on the calendar.
bool _isEditableLayer(CalendarLayer layer) =>
    layer == CalendarLayer.calendarEvents || layer == CalendarLayer.absences;

/// Currently-enabled calendar layers. Session-scoped: resets to
/// [kDefaultCalendarLayers] on every app launch, per design.
final calendarLayersProvider = StateProvider<Set<CalendarLayer>>(
  (_) => {...kDefaultCalendarLayers},
);

/// Opens the layer-filter dialog. Wired to the [DetailsAppBar] filter toggle.
Future<void> showCalendarLayerPicker(BuildContext context, WidgetRef ref) {
  return showDialog(
    context: context,
    builder: (_) => _LayerPickerDialog(
      current: ref.read(calendarLayersProvider),
      onSaved: (selected) =>
          ref.read(calendarLayersProvider.notifier).state = selected,
    ),
  );
}

/// Coerces a Firestore field into a String. The `timeline` collection is
/// polymorphic â€” calendar events, absences, equipment telemetry, task/quality
/// reports and legacy docs all share it â€” so a field that is a plain String on
/// one doc-shape may be a [DocumentReference] (surfaced by `data()` as the
/// private `_JsonDocumentReference`) on another, especially older docs written
/// before the `timelineCategory` String / `timelineCategoryId` ref split.
/// A blind `as String?` cast on those throws and takes down the whole calendar.
/// Returns the ref's id for references, the value itself for strings, and null
/// for anything else.
String? _timelineString(Object? raw) {
  if (raw is String) return raw;
  if (raw is DocumentReference) return raw.id;
  return null;
}

/// Firestore-backed timeline event.
class TimelineEvent {
  final String id;
  final DateTime start;
  final DateTime end;
  final String name;
  final String categoryId;

  /// Which calendar layer this event belongs to â€” drives colour, tap
  /// routing, and whether drag/resize persists.
  final CalendarLayer layer;

  /// Absences are categorized by [isAbsence] rather than a `timelineCategory`,
  /// so they need to bypass the category filter to remain visible.
  final bool isAbsence;

  /// True when the event is a date-only entry â€” start/end span whole days,
  /// no time of day. Rendered as a top-of-day bar in time-grid views.
  final bool isAllDay;

  /// One of `none`, `daily`, `weekly`, `monthly`, `annually`, `weekday`.
  final String repeatRule;

  /// ID of the member who owns this event. For absences this is the member
  /// who is absent; for other events it's the creator. Used to decide
  /// whether the current user can edit and to surface the name when not.
  final String? authorMemberId;

  /// Denormalized author name, when available on the doc.
  final String? authorName;

  TimelineEvent({
    required this.id,
    required this.start,
    required this.end,
    required this.name,
    required this.categoryId,
    required this.layer,
    this.isAbsence = false,
    this.isAllDay = false,
    this.repeatRule = 'none',
    this.authorMemberId,
    this.authorName,
  });

  factory TimelineEvent.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    String? authorId = _timelineString(d['createdByMemberId']);
    if (authorId == null || authorId.isEmpty) {
      final memberRaw = d['memberId'];
      if (memberRaw is DocumentReference) {
        authorId = memberRaw.id;
      } else if (memberRaw is String && memberRaw.isNotEmpty) {
        authorId = memberRaw.split('/').last;
      }
    }
    final memberName = _timelineString(d['memberName'])?.trim();
    final rawName = _timelineString(d['name']) ?? '';
    final isAbsence = d['isAbsence'] as bool? ?? false;
    final categoryId = _timelineString(d['timelineCategory']) ?? '';
    // For absences, prefer the denormalized member name (the person who is
    // out) over the generic `name` field â€” which may have been filled with
    // an absence-type label like "Vacation / PTO" if the member record had
    // no name at creation time.
    final displayName = isAbsence && memberName != null && memberName.isNotEmpty
        ? memberName
        : rawName;
    return TimelineEvent(
      id: doc.id,
      start: (d['startTime'] as Timestamp).toDate(),
      end: (d['endTime'] as Timestamp).toDate(),
      name: displayName,
      categoryId: categoryId,
      layer: isAbsence
          ? CalendarLayer.absences
          : _layerForCategory(categoryId),
      isAbsence: isAbsence,
      isAllDay: d['isAllDay'] as bool? ?? false,
      repeatRule: _timelineString(d['repeatRule']) ?? 'none',
      authorMemberId: authorId,
      authorName: memberName?.isNotEmpty == true ? memberName : rawName,
    );
  }

  /// Safe wrapper around [fromDoc]. The `timeline` collection is shared by many
  /// writers with differing doc-shapes; if one can't be parsed, skip it rather
  /// than throwing and blanking the entire calendar (most visible in month
  /// view, whose wider window pulls in more docs).
  static TimelineEvent? tryFromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    try {
      return TimelineEvent.fromDoc(doc);
    } catch (e) {
      debugPrint('[Calendar] skipped unparseable timeline doc ${doc.id}: $e');
      return null;
    }
  }
}

/// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ Calendar screen â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class CalendarContent extends ConsumerStatefulWidget {
  const CalendarContent({super.key});

  @override
  ConsumerState<CalendarContent> createState() => _CalendarContentState();
}

class _CalendarContentState extends ConsumerState<CalendarContent> {
  /* search */
  final _searchCtl = TextEditingController();
  String _search = '';

  /* calendar controller & visible window */
  final _calCtl = sf.CalendarController()..view = sf.CalendarView.week;
  DateTime _winStart = DateTime.now();
  DateTime _winEnd = DateTime.now().add(const Duration(days: 7));

  /* timeline view pinch-zoom state (width of each time interval cell) */
  double _timelineIntervalWidth = 60.0; // px per interval (timeline views)
  double? _scaleStartWidth; // captured at onScaleStart
  // Minimum appointment height for timeline views so text remains readable.
  static const double _timelineApptMinHeight = 36.0;
  static const Duration _timelineInterval = Duration(hours: 1);
  static const Color _timelineGridColor = Color(0xFFDDDDDD);
  static const int _timelineMaxVisibleLanes = 6;
  List<sf.TimeRegion> _timelineGridRegions = const <sf.TimeRegion>[];

  /* company id cached for drag/resize writes */
  String? _companyId;

  /* current member id, used to decide author vs. non-author tap behavior */
  String? _currentMemberId;

  /* â”€â”€ layer subscriptions â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
   * Two streams at most: one `whereIn` over every enabled category-based
   * layer, and one `isAbsence == true` query. Re-subscribed only when the
   * company, the window, or the enabled-layer set actually changes
   * (tracked by [_syncKey]) â€” not on every unrelated rebuild. */
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _catSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _absenceSub;
  List<TimelineEvent> _catEvents = const [];
  List<TimelineEvent> _absenceEvents = const [];
  String _syncKey = '';

  /* doc-id â†’ TimelineEvent for the currently visible window, kept for tap lookups */
  final Map<String, TimelineEvent> _eventsById = {};

  @override
  void dispose() {
    _searchCtl.dispose();
    _catSub?.cancel();
    _absenceSub?.cancel();
    super.dispose();
  }

  /* â”€â”€ layer subscription engine â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ */

  /// Re-subscribes the layer streams when (and only when) the company, the
  /// visible window, or the enabled-layer set has changed. Safe to call from
  /// `build`: it is idempotent across unchanged inputs.
  void _maybeResync(String companyId, Set<CalendarLayer> layers) {
    final categoryIds = <String>[];
    for (final layer in layers) {
      categoryIds.addAll(_categoriesForLayer(layer));
    }
    categoryIds.sort();
    final absencesOn = layers.contains(CalendarLayer.absences);

    final key = [
      companyId,
      _winStart.millisecondsSinceEpoch,
      _winEnd.millisecondsSinceEpoch,
      categoryIds.join(','),
      absencesOn,
    ].join('|');
    if (key == _syncKey) return;
    _syncKey = key;

    _catSub?.cancel();
    _absenceSub?.cancel();
    _catSub = null;
    _absenceSub = null;

    final timeline = FirebaseFirestore.instance
        .collection('company')
        .doc(companyId)
        .collection('timeline');
    // The window query keeps the original semantics: an event overlaps the
    // visible window when it starts before the window ends and ends after
    // the window begins.
    final startBound = Timestamp.fromDate(_winEnd);
    final endBound = Timestamp.fromDate(_winStart);

    if (categoryIds.isEmpty) {
      _catEvents = const [];
    } else {
      _catSub = timeline
          .where('startTime', isLessThanOrEqualTo: startBound)
          .where('endTime', isGreaterThanOrEqualTo: endBound)
          .where('timelineCategory', whereIn: categoryIds)
          .snapshots()
          .listen(
        (snap) {
          if (!mounted) return;
          setState(() {
            _catEvents = snap.docs
                .map(TimelineEvent.tryFromDoc)
                .whereType<TimelineEvent>()
                .toList();
          });
        },
        onError: (Object e) {
          debugPrint('[Calendar] category layer stream error: $e');
          if (mounted) setState(() => _catEvents = const []);
        },
      );
    }

    if (!absencesOn) {
      _absenceEvents = const [];
    } else {
      _absenceSub = timeline
          .where('startTime', isLessThanOrEqualTo: startBound)
          .where('endTime', isGreaterThanOrEqualTo: endBound)
          .where('isAbsence', isEqualTo: true)
          .snapshots()
          .listen(
        (snap) {
          if (!mounted) return;
          setState(() {
            _absenceEvents = snap.docs
                .map(TimelineEvent.tryFromDoc)
                .whereType<TimelineEvent>()
                .toList();
          });
        },
        onError: (Object e) {
          debugPrint('[Calendar] absence layer stream error: $e');
          if (mounted) setState(() => _absenceEvents = const []);
        },
      );
    }
  }

  /* helpers -------------------------------------------------------- */
  void _onViewChanged(sf.ViewChangedDetails d) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (d.visibleDates.isEmpty) {
        return;
      }
      final s = d.visibleDates.first;
      final e = d.visibleDates.last;
      final view = _calCtl.view ?? sf.CalendarView.week;
      final shouldShowGrid = _isTimelineView(view);
      final newRegions = shouldShowGrid
          ? buildTimelineGridRegions(
              visibleDates: d.visibleDates,
              interval: _timelineInterval,
              color: _timelineGridColor,
            )
          : const <sf.TimeRegion>[];

      final windowChanged = s != _winStart || e != _winEnd;
      final regionsChanged = !timelineRegionsEqual(
        _timelineGridRegions,
        newRegions,
      );

      if (!windowChanged && !regionsChanged) {
        return;
      }

      setState(() {
        if (windowChanged) {
          _winStart = s;
          _winEnd = e;
        }
        if (regionsChanged) {
          _timelineGridRegions = newRegions;
        }
      });
    });
  }

  /// Renders appointments as compact pills. Padding and font are kept tight
  /// so single-day all-day bars (e.g. absences stacked on one weekday) can
  /// still fit a recognizable name; longer bars get more room automatically.
  Widget _appointmentBuilder(
      BuildContext context, sf.CalendarAppointmentDetails details) {
    final appt = details.appointments.first as sf.Appointment;
    return SizedBox.fromSize(
      size: details.bounds.size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: appt.color,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              appt.subject,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              softWrap: true,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 11,
                height: 1.15,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Show a Material date-picker.
  Future<void> _showDatePicker() async {
    final initial = _calCtl.displayDate ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(initial.year - 5),
      lastDate: DateTime(initial.year + 5),
    );
    if (picked != null) {
      setState(() {
        _calCtl.displayDate = picked;
      });
    }
  }

  /* â”€â”€ tap handling â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ */
  void _onTap(sf.CalendarTapDetails d) {
    // 1) Month/year header â†’ date picker
    if (d.targetElement == sf.CalendarElement.header) {
      _showDatePicker();
      return;
    }
    // 2) Week-view day header â†’ switch to day view for that date
    if (d.targetElement == sf.CalendarElement.viewHeader) {
      setState(() {
        _calCtl.view = sf.CalendarView.day;
        _calCtl.displayDate = d.date;
      });
      return;
    }
    // 3) Appointment tapped â†’ edit (if author) or info snackbar (if not)
    if (d.appointments != null && d.appointments!.isNotEmpty) {
      final id = (d.appointments!.first as sf.Appointment).id as String;
      _handleAppointmentTap(context, id);
      return;
    }
    // 4) Calendar cell tapped
    if (d.targetElement == sf.CalendarElement.calendarCell) {
      // Month view â†’ drill into day view
      if (_calCtl.view == sf.CalendarView.month) {
        setState(() {
          _calCtl.view = sf.CalendarView.day;
          _calCtl.displayDate = d.date;
        });
      }
      // Other views â†’ create new event stub
      else if (d.appointments == null || d.appointments!.isEmpty) {
        _create(context, d.date!);
      }
    }
  }

  /* â”€â”€ Firestore write helpers for drag / resize â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ */
  Future<void> _updateEventTime({
    required String id,
    required DateTime start,
    required DateTime end,
  }) async {
    if (_companyId == null) return;
    await FirebaseFirestore.instance
        .collection('company')
        .doc(_companyId)
        .collection('timeline')
        .doc(id)
        .update({
      'startTime': Timestamp.fromDate(start),
      'endTime': Timestamp.fromDate(end),
    });
  }

  /* Open the edit form (editable layer + author) or surface an info snackbar. */
  void _handleAppointmentTap(BuildContext ctx, String docId) {
    final ev = _eventsById[docId];
    final myId = _currentMemberId;
    final editable = ev != null && _isEditableLayer(ev.layer);
    final isAuthor =
        ev != null && myId != null && ev.authorMemberId == myId;
    if (editable && isAuthor) {
      ctx.push('${AppRoutes.drawerCalendarForm}?docId=$docId');
      return;
    }
    // Non-editable layer, or not the author: surface a read-only info label.
    final String label;
    if (ev == null) {
      label = 'Event';
    } else if (ev.isAbsence) {
      label = ev.authorName?.trim().isNotEmpty == true
          ? '${ev.authorName} (absence)'
          : 'Absence';
    } else {
      final name = ev.name.trim();
      label = name.isNotEmpty
          ? '$name Â· ${layerLabel(ev.layer)}'
          : layerLabel(ev.layer);
    }
    SnackbarService.instance.showSnackBar(
      SnackBar(duration: const Duration(seconds: 5), content: Text(label)),
    );
  }

  void _create(BuildContext ctx, DateTime at) {
    final iso = Uri.encodeQueryComponent(at.toIso8601String());
    ctx.push('${AppRoutes.drawerCalendarForm}?date=$iso');
  }

  /// Persists a drag/resize only for editable layers; for read-only layers
  /// (tasks, timecards, â€¦) it rebuilds so the appointment snaps back.
  void _handleTimeChange(sf.Appointment? appt, DateTime? start, DateTime? end) {
    if (appt == null || start == null || end == null) return;
    final id = appt.id as String;
    final ev = _eventsById[id];
    if (ev == null || !_isEditableLayer(ev.layer)) {
      setState(() {}); // snap read-only appointments back to source data
      return;
    }
    _updateEventTime(id: id, start: start, end: end);
  }

  /* â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ UI â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ */
  @override
  Widget build(BuildContext context) {
    _currentMemberId = ref.watch(memberDocRefProvider).value?.id;
    final layers = ref.watch(calendarLayersProvider);
    return ref.watch(userDocumentProvider).when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('User error: $e')),
          data: (user) {
            final companyRef = user['companyId'] as DocumentReference?;
            if (companyRef == null) {
              return const Center(child: Text('No company assigned.'));
            }
            _companyId = companyRef.id;
            _maybeResync(companyRef.id, layers);

            final showSearch = ref.watch(calendarSearchVisibleProvider);

            // Merge the two layer streams. The category and absence queries
            // are disjoint (absences carry no `timelineCategory`), so no
            // dedup is needed.
            final filtered = <TimelineEvent>[
              ..._catEvents,
              ..._absenceEvents,
            ].where((e) => e.name.toLowerCase().contains(_search)).toList();
            _eventsById
              ..clear()
              ..addEntries(filtered.map((e) => MapEntry(e.id, e)));

            final appts = filtered.map((e) {
              final subject = e.isAbsence
                  ? (e.name.trim().isNotEmpty
                      ? e.name
                      : (e.authorName ?? 'Absence'))
                  : (e.name.trim().isNotEmpty
                      ? e.name
                      : layerLabel(e.layer));
              return sf.Appointment(
                id: e.id,
                startTime: e.start,
                endTime: e.end,
                subject: subject,
                isAllDay: e.isAllDay,
                recurrenceRule: _rruleFor(e.repeatRule, e.start),
                color: _layerColor(e.layer),
              );
            }).toList();

            final currentView = _calCtl.view ?? sf.CalendarView.week;
            final isTimeline = _isTimelineView(currentView);

            List<sf.Appointment> dataAppointments = appts;
            List<sf.CalendarResource>? laneResources;
            var visibleResourceCount = -1;
            if (isTimeline) {
              final layout = buildTimelineLaneLayout(appts);
              dataAppointments = layout.appointments;
              if (layout.resources.isNotEmpty) {
                laneResources = layout.resources;
                if (layout.laneCount > 1) {
                  visibleResourceCount =
                      layout.laneCount > _timelineMaxVisibleLanes
                          ? _timelineMaxVisibleLanes
                          : layout.laneCount;
                }
              }
            }

            final cellBorderColor = isTimeline
                ? Colors.transparent
                : const Color(0xFFBDBDBD);

            final cal = GestureDetector(
              // Only react to two-finger pinch gestures; avoids interfering
              // with single-finger drag/resize in calendar.
              onScaleStart: (details) {
                final v = _calCtl.view ?? sf.CalendarView.week;
                if (_isTimelineView(v)) {
                  _scaleStartWidth = _timelineIntervalWidth;
                } else {
                  _scaleStartWidth = null;
                }
              },
              onScaleUpdate: (details) {
                if (_scaleStartWidth != null && details.scale != 1.0) {
                  // Clamp width to a sensible range.
                  final newWidth = (_scaleStartWidth! * details.scale)
                      .clamp(30.0, 300.0);
                  if (newWidth != _timelineIntervalWidth) {
                    setState(() => _timelineIntervalWidth = newWidth);
                  }
                }
              },
              onScaleEnd: (_) => _scaleStartWidth = null,
              child: sf.SfCalendar(
                controller: _calCtl,
                dataSource: _EventDataSource(
                  dataAppointments,
                  resources: laneResources,
                ),
                view: currentView,
                allowedViews: const [
                  sf.CalendarView.day,
                  sf.CalendarView.workWeek,
                  sf.CalendarView.week,
                  sf.CalendarView.month,
                  sf.CalendarView.timelineWeek,
                  sf.CalendarView.schedule,
                ],
                cellBorderColor: cellBorderColor,
                specialRegions: isTimeline ? _timelineGridRegions : null,
                showDatePickerButton: true,
                showNavigationArrow: true,
                showCurrentTimeIndicator: true,
                allowDragAndDrop: true,
                allowAppointmentResize: true,
                resourceViewSettings: sf.ResourceViewSettings(
                  size: 0,
                  showAvatar: false,
                  visibleResourceCount: visibleResourceCount,
                ),
                timeSlotViewSettings: sf.TimeSlotViewSettings(
                  // Affects timeline views: width per interval (pinch-zoomed)
                  timeIntervalWidth: _timelineIntervalWidth,
                  // Ensure readable minimum height for appointments in
                  // timeline views
                  timelineAppointmentHeight: _timelineApptMinHeight,
                  timeInterval: _timelineInterval,
                ),
                appointmentBuilder: _appointmentBuilder,
                monthViewSettings: const sf.MonthViewSettings(
                  showAgenda: true,
                  agendaViewHeight: 150,
                  appointmentDisplayMode:
                      sf.MonthAppointmentDisplayMode.appointment,
                ),
                scheduleViewSettings: const sf.ScheduleViewSettings(
                  hideEmptyScheduleWeek: true,
                ),
                onViewChanged: _onViewChanged,
                onTap: _onTap,
                onDragEnd: (d) {
                  final appt = d.appointment as sf.Appointment?;
                  _handleTimeChange(appt, appt?.startTime, appt?.endTime);
                },
                onAppointmentResizeEnd: (d) {
                  final appt = d.appointment as sf.Appointment?;
                  _handleTimeChange(appt, d.startTime, d.endTime);
                },
              ),
            );

            return Column(
              children: [
                if (showSearch)
                  SearchControlStrip(
                    controller: _searchCtl,
                    hintText: 'Search events',
                    onChanged: (t) =>
                        setState(() => _search = t.toLowerCase()),
                    trailingActions: [
                      SearchStripAction(
                        icon: Icons.filter_list,
                        tooltip: 'Filter layers',
                        onTap: () => showCalendarLayerPicker(context, ref),
                      ),
                    ],
                  ),
                Expanded(child: cal),
              ],
            );
          },
        );
  }

  /// Translates the persisted `repeatRule` enum into an RFC 5545 RRULE
  /// string for Syncfusion. Returns null for non-repeating events.
  String? _rruleFor(String rule, DateTime start) {
    switch (rule) {
      case 'daily':
        return 'FREQ=DAILY;INTERVAL=1';
      case 'weekly':
        const days = ['SU', 'MO', 'TU', 'WE', 'TH', 'FR', 'SA'];
        final wd = start.weekday == 7 ? 0 : start.weekday; // Mon=1..Sun=7
        return 'FREQ=WEEKLY;INTERVAL=1;BYDAY=${days[wd]}';
      case 'monthly':
        return 'FREQ=MONTHLY;INTERVAL=1;BYMONTHDAY=${start.day}';
      case 'annually':
        return 'FREQ=YEARLY;INTERVAL=1;BYMONTH=${start.month};BYMONTHDAY=${start.day}';
      case 'weekday':
        return 'FREQ=WEEKLY;INTERVAL=1;BYDAY=MO,TU,WE,TH,FR';
      default:
        return null;
    }
  }

  bool _isTimelineView(sf.CalendarView? view) {
    switch (view) {
      case sf.CalendarView.timelineDay:
      case sf.CalendarView.timelineWeek:
      case sf.CalendarView.timelineWorkWeek:
        return true;
      default:
        return false;
    }
  }
}

/* basic datasource wrapper */
class _EventDataSource extends sf.CalendarDataSource {
  _EventDataSource(
    List<sf.Appointment> src, {
    List<sf.CalendarResource>? resources,
  }) {
    appointments = src;
    if (resources != null && resources.isNotEmpty) {
      this.resources = resources;
    }
  }
}

/// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ Layer picker â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class _LayerPickerDialog extends StatefulWidget {
  const _LayerPickerDialog({
    required this.current,
    required this.onSaved,
  });
  final Set<CalendarLayer> current;
  final ValueChanged<Set<CalendarLayer>> onSaved;

  @override
  State<_LayerPickerDialog> createState() => _LayerPickerDialogState();
}

class _LayerPickerDialogState extends State<_LayerPickerDialog> {
  late Set<CalendarLayer> _picked;

  @override
  void initState() {
    super.initState();
    _picked = {...widget.current};
  }

  @override
  Widget build(BuildContext context) {
    return DialogAction(
      title: 'Calendar layers',
      cancelText: 'Cancel',
      onCancel: () => Navigator.pop(context),
      actionText: 'Apply',
      showActionButton: true,
      onAction: () {
        widget.onSaved({..._picked});
        Navigator.pop(context);
      },
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: CalendarLayer.values.map((layer) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: TextInfoCheckbox(
                leadingIcon: _layerIcon(layer),
                text: layerLabel(layer),
                value: _picked.contains(layer),
                onChanged: (v) {
                  setState(() {
                    if (v == true) {
                      _picked.add(layer);
                    } else {
                      _picked.remove(layer);
                    }
                  });
                },
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

