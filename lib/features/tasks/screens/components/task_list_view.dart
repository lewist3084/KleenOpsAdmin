import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_widgets/buttons/pill_button.dart';
import 'package:shared_widgets/lists/standardViewGroup.dart';
import 'package:shared_widgets/theme/app_palette.dart';

/// Small facade widget to render the filtered task list.
class _TeamDurationTotals {
  double total = 0;
  double completed = 0;
}

const TextStyle _scheduleHoverLabelStyle = TextStyle(
  color: Colors.white,
  fontSize: 12,
  fontWeight: FontWeight.w600,
);
const double _scheduleHoverLabelHorizontalPadding = 10;
const double _scheduleHoverLabelVerticalPadding = 6;
const double _scheduleHoverLabelGap = 10;
const double _scheduleHoverLabelRadius = 8;
const Duration _scheduleHoverFadeDuration = Duration(milliseconds: 150);

class TaskListView extends StatefulWidget {
  const TaskListView({
    super.key,
    required this.allDocs,
    required this.filteredDocs,
    required this.collapse,
    required this.startForDoc,
    required this.builder,
    required this.companyRef,
    this.onSwipeLeft,
    this.onSwipeRight,
    this.leftSwipeBackground,
    this.rightSwipeBackground,
    this.teamRefs = const [],
    this.indentGroupedItems = true,
    this.padding = EdgeInsets.zero,
    this.primaryTeamRef,
  });

  final List<QueryDocumentSnapshot<Map<String, dynamic>>> allDocs;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> filteredDocs;
  final bool collapse;
  final DateTime Function(QueryDocumentSnapshot<Map<String, dynamic>>)
      startForDoc;
  final Widget Function(QueryDocumentSnapshot<Map<String, dynamic>>) builder;
  final Future<void> Function(QueryDocumentSnapshot<Map<String, dynamic>>)?
      onSwipeLeft;
  final Future<void> Function(QueryDocumentSnapshot<Map<String, dynamic>>)?
      onSwipeRight;
  final Widget? leftSwipeBackground;
  final Widget? rightSwipeBackground;
  final List<DocumentReference<Map<String, dynamic>>> teamRefs;
  final bool indentGroupedItems;
  final EdgeInsets padding;
  final DocumentReference<Map<String, dynamic>> companyRef;
  final DocumentReference<Map<String, dynamic>>? primaryTeamRef;

  @override
  State<TaskListView> createState() => _TaskListViewState();
}

class _TaskListViewState extends State<TaskListView> {
  /// Cached duration totals keyed by `allDocs` identity. Skips re-walking the
  /// task list on rebuilds that don't actually change the source data
  /// (parent ticks, search keystrokes that only affect filteredDocs).
  Map<String, _TeamDurationTotals>? _totalsCache;
  List<QueryDocumentSnapshot<Map<String, dynamic>>>? _totalsCacheKey;

  // Convenience accessors so the migrated build() body keeps reading
  // `teamRefs`, `companyRef`, etc. without the `widget.` prefix everywhere.
  List<QueryDocumentSnapshot<Map<String, dynamic>>> get allDocs =>
      widget.allDocs;
  List<QueryDocumentSnapshot<Map<String, dynamic>>> get filteredDocs =>
      widget.filteredDocs;
  bool get collapse => widget.collapse;
  DateTime Function(QueryDocumentSnapshot<Map<String, dynamic>>)
      get startForDoc => widget.startForDoc;
  Widget Function(QueryDocumentSnapshot<Map<String, dynamic>>) get builder =>
      widget.builder;
  Future<void> Function(QueryDocumentSnapshot<Map<String, dynamic>>)?
      get onSwipeLeft => widget.onSwipeLeft;
  Future<void> Function(QueryDocumentSnapshot<Map<String, dynamic>>)?
      get onSwipeRight => widget.onSwipeRight;
  Widget? get leftSwipeBackground => widget.leftSwipeBackground;
  Widget? get rightSwipeBackground => widget.rightSwipeBackground;
  List<DocumentReference<Map<String, dynamic>>> get teamRefs => widget.teamRefs;
  bool get indentGroupedItems => widget.indentGroupedItems;
  EdgeInsets get padding => widget.padding;
  DocumentReference<Map<String, dynamic>> get companyRef => widget.companyRef;
  DocumentReference<Map<String, dynamic>>? get primaryTeamRef =>
      widget.primaryTeamRef;

  // One company-wide listener for active members and one for today's
  // schedules — used by every team header pill instead of opening 2
  // listeners per team. With N visible teams this drops 2N listeners to 2.
  Stream<QuerySnapshot<Map<String, dynamic>>>? _membersStream;
  Stream<QuerySnapshot<Map<String, dynamic>>>? _scheduleStream;
  String? _membersStreamKey;
  String? _scheduleStreamKey;

  Stream<QuerySnapshot<Map<String, dynamic>>> _activeMembersStream() {
    final key = companyRef.path;
    if (_membersStreamKey != key || _membersStream == null) {
      _membersStreamKey = key;
      _membersStream = companyRef
          .collection('member')
          .where('active', isEqualTo: true)
          .snapshots();
    }
    return _membersStream!;
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _todayScheduleStream(
    String dayLabel,
  ) {
    final key = '${companyRef.path}|$dayLabel';
    if (_scheduleStreamKey != key || _scheduleStream == null) {
      _scheduleStreamKey = key;
      _scheduleStream = companyRef
          .collection('employeeSchedule')
          .where('weekDay', isEqualTo: dayLabel)
          .snapshots();
    }
    return _scheduleStream!;
  }

  Map<String, _TeamDurationTotals> _resolveTotals(Set<String> teamPaths) {
    if (identical(_totalsCacheKey, allDocs) && _totalsCache != null) {
      return _totalsCache!;
    }
    final Map<String, _TeamDurationTotals> totalsByTeamPath = {};
    for (final doc in allDocs) {
      final data = doc.data();
      final rawTeam = data['teamId'];
      String? teamPath;
      if (rawTeam is DocumentReference) {
        teamPath = rawTeam.path;
      } else if (rawTeam is String && rawTeam.trim().isNotEmpty) {
        teamPath = rawTeam;
      }
      if (teamPath == null) continue;
      if (teamPaths.isNotEmpty && !teamPaths.contains(teamPath)) {
        continue;
      }
      final duration = (data['duration'] as num?)?.toDouble() ?? 0.0;
      if (duration <= 0) continue;
      final totals =
          totalsByTeamPath.putIfAbsent(teamPath, () => _TeamDurationTotals());
      totals.total += duration;
      if (data['completeTimestamp'] != null) {
        totals.completed += duration;
      }
    }
    _totalsCacheKey = allDocs;
    _totalsCache = totalsByTeamPath;
    return totalsByTeamPath;
  }

  @override
  Widget build(BuildContext context) {
    final timeLabelFormat = DateFormat('h:mm a');
    final teamPaths = teamRefs.map((ref) => ref.path).toSet();
    final bool groupByTeam = teamPaths.isNotEmpty;

    String normalizedNameForDoc(
      QueryDocumentSnapshot<Map<String, dynamic>> doc,
    ) {
      final raw = doc.data()['name'];
      if (raw == null) return '';
      return raw.toString().trim().toLowerCase();
    }

    final totalsByTeamPath = _resolveTotals(teamPaths);

    // Pre-index the two shared streams ONCE per build, then look up per-team
    // slices below.
    final now = DateTime.now();
    final dayLabel = DateFormat('EEEE').format(now);

    String? teamPathOfMemberDoc(QueryDocumentSnapshot<Map<String, dynamic>> d) {
      final raw = d.data()['primaryTeamId'];
      if (raw is DocumentReference) return raw.path;
      if (raw is String && raw.isNotEmpty) {
        return raw.contains('/')
            ? raw
            : companyRef.collection('team').doc(raw).path;
      }
      return null;
    }

    String? teamPathOfScheduleDoc(QueryDocumentSnapshot<Map<String, dynamic>> d) {
      final raw = d.data()['teamId'];
      if (raw is DocumentReference) return raw.path;
      if (raw is String && raw.isNotEmpty) {
        return raw.contains('/')
            ? raw
            : companyRef.collection('team').doc(raw).path;
      }
      return null;
    }

    Widget? buildTeamPercentPill(
      dynamic key,
      AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> memberSnap,
      AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> scheduleSnap,
    ) {
      if (key is! DocumentReference) return null;
      final String teamPath = key.path;
      final totals = totalsByTeamPath[teamPath];
      final totalDuration = totals?.total ?? 0;
      final completedDuration = totals?.completed ?? 0;
      final tasksPercentLabel = totalDuration > 0
          ? _formatPercentFromDoubles(completedDuration, totalDuration)
          : '--';

      // Filter shared member-stream docs down to this team.
      var activeCount = 0;
      final memberClocked = <String, bool>{};
      final memberNames = <String, String>{};
      if (memberSnap.hasData) {
        for (final doc in memberSnap.data!.docs) {
          if (teamPathOfMemberDoc(doc) != teamPath) continue;
          final data = doc.data();
          final memberId = _refOrStringId(data['memberId']) ?? doc.id;
          final name = (data['name'] ?? '').toString().trim();
          if (memberId.isNotEmpty && name.isNotEmpty) {
            memberNames[memberId] = name;
          }
          final clocked = data['clockedIn'] == true;
          memberClocked[memberId] = clocked;
          if (clocked) activeCount += 1;
        }
      }

      int scheduledCount = 0;
      int scheduledWorking = 0;
      List<String> nonWorkingNames = const [];
      if (scheduleSnap.hasData) {
        final scheduledIds = <String>{};
        for (final doc in scheduleSnap.data!.docs) {
          if (teamPathOfScheduleDoc(doc) != teamPath) continue;
          if (!_isScheduledNow(doc.data(), now)) continue;
          final memberId = _refOrStringId(doc.data()['memberId']);
          if (memberId == null || memberId.isEmpty) continue;
          if (!memberClocked.containsKey(memberId)) continue;
          scheduledIds.add(memberId);
        }
        scheduledCount = scheduledIds.length;
        for (final id in scheduledIds) {
          if (memberClocked[id] == true) scheduledWorking += 1;
        }
        if (scheduledCount > 0 && scheduledWorking < scheduledCount) {
          final missing = scheduledIds
              .where((id) => memberClocked[id] != true)
              .map((id) => memberNames[id] ?? id)
              .toList(growable: false)
            ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
          nonWorkingNames = missing;
        }
      }

      final percentLabel = scheduleSnap.hasData
          ? _formatPercent(scheduledWorking, scheduledCount)
          : '--';
      final palette = AppPaletteScope.of(context);
      final valueColor = palette.primary2;
      final iconColor = palette.primary2;

      final pill = PillButtonDart(
        height: 22,
        borderWidth: 0.75,
        dividerWidth: 0.75,
        iconSize: 11,
        iconSpacing: 3,
        sectionPadding: const EdgeInsets.symmetric(
          horizontal: 4,
          vertical: 2,
        ),
        textStyle: Theme.of(context)
            .textTheme
            .labelSmall
            ?.copyWith(fontSize: 11, fontWeight: FontWeight.w600),
        sections: [
          PillButtonSection(
            icon: Icons.group_outlined,
            value: '$activeCount',
            textColor: valueColor,
            iconColor: iconColor,
            digits: 2,
          ),
          PillButtonSection(
            icon: Icons.access_time_outlined,
            value: percentLabel,
            textColor: valueColor,
            iconColor: iconColor,
            placeholder: '888%',
          ),
          PillButtonSection(
            icon: Icons.view_timeline_outlined,
            value: tasksPercentLabel,
            textColor: valueColor,
            iconColor: iconColor,
            placeholder: '888%',
          ),
        ],
      );

      return _ScheduleMissingHoverPill(
        scheduledCount: scheduledCount,
        scheduledWorking: scheduledWorking,
        missingNames: nonWorkingNames,
        child: pill,
      );
    }

    String timeKeyForDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
      final dt = startForDoc(doc);
      final key = dt.hour * 60 + dt.minute;
      final label = timeLabelFormat.format(dt);
      return '$key#$label';
    }

    String? teamPathForDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
      final rawTeam = doc.data()['teamId'];
      if (rawTeam is DocumentReference) return rawTeam.path;
      if (rawTeam is String && rawTeam.trim().isNotEmpty) return rawTeam;
      return null;
    }

    // Ensure tasks are alphabetical within their time slot (and within team
    // groups when present).
    final sortedDocs = filteredDocs.toList(growable: false)
      ..sort((a, b) {
        if (groupByTeam) {
          final ta = teamPathForDoc(a) ?? '';
          final tb = teamPathForDoc(b) ?? '';
          final teamCmp = ta.compareTo(tb);
          if (teamCmp != 0) return teamCmp;
        }

        final aStart = startForDoc(a);
        final bStart = startForDoc(b);
        final timeCmp = aStart.compareTo(bStart);
        if (timeCmp != 0) return timeCmp;

        final nameCmp = normalizedNameForDoc(a).compareTo(
          normalizedNameForDoc(b),
        );
        if (nameCmp != 0) return nameCmp;

        return a.id.compareTo(b.id);
      });

    // Wrap the view in the two shared streams so headerCenterBuilder can
    // pull from pre-computed snapshots instead of opening 2 listeners per
    // team header. Doing the StreamBuilders here (not inside buildTeamPercentPill)
    // keeps the listener count constant: 2 regardless of group count.
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: groupByTeam ? _activeMembersStream() : const Stream.empty(),
      builder: (context, memberSnap) {
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: groupByTeam
              ? _todayScheduleStream(dayLabel)
              : const Stream.empty(),
          builder: (context, scheduleSnap) {
            return StandardViewGroup.buildViewFromDocs(
      docs: sortedDocs,
      padding: padding,
      shrinkWrap: false,
      physics: const ClampingScrollPhysics(),
      headerIcon: null,
      groupCollapsible: groupByTeam,
      subgroupCollapsible: groupByTeam,
      onSwipeLeft: onSwipeLeft,
      onSwipeRight: onSwipeRight,
      itemKey: (doc) => ValueKey(doc.id),
      leftSwipeBackground: leftSwipeBackground,
      rightSwipeBackground: rightSwipeBackground,
      indentGroupedItems: indentGroupedItems,
      headerCenterBuilder: groupByTeam
          ? (key) => buildTeamPercentPill(key, memberSnap, scheduleSnap)
          : null,
      groupBy: (d) {
        if (!groupByTeam) {
          return timeKeyForDoc(d);
        }
        final rawTeam = d.data()['teamId'];
        if (rawTeam is DocumentReference && teamPaths.contains(rawTeam.path)) {
          return rawTeam;
        }
        return null;
      },
      subgroupBy: groupByTeam ? (d) => timeKeyForDoc(d) : null,
      initialGroupExpanded: !groupByTeam,
      initialGroupExpandedCallback: groupByTeam && primaryTeamRef != null
          ? (key) {
              if (key is DocumentReference) {
                return key.path == primaryTeamRef!.path;
              }
              return false;
            }
          : null,
      groupSort: groupByTeam
          ? null
          : (a, b) {
              final ka = int.parse(a.split('#')[0]);
              final kb = int.parse(b.split('#')[0]);
              return ka.compareTo(kb);
            },
      subgroupSort: groupByTeam
          ? (a, b) {
              final ka = int.parse(a.split('#')[0]);
              final kb = int.parse(b.split('#')[0]);
              return ka.compareTo(kb);
            }
          : null,
      itemBuilder: builder,
      // preserve existing collapse behavior via callback if needed later
    );
          },
        );
      },
    );
  }
}

String? _refOrStringId(dynamic value) {
  if (value is DocumentReference) return value.id;
  if (value is String && value.isNotEmpty) {
    return value.contains('/') ? value.split('/').last : value;
  }
  return null;
}

DateTime _mergeDateWithTime(DateTime date, DateTime template) {
  return DateTime(
    date.year,
    date.month,
    date.day,
    template.hour,
    template.minute,
    template.second,
    template.millisecond,
    template.microsecond,
  );
}

bool _isScheduledNow(
  Map<String, dynamic> data,
  DateTime now,
) {
  final startTs = data['startTime'] as Timestamp?;
  final endTs = data['endTime'] as Timestamp?;

  DateTime? start;
  DateTime? end;

  if (startTs != null) {
    start = _mergeDateWithTime(now, startTs.toDate());
  }
  if (endTs != null) {
    end = _mergeDateWithTime(now, endTs.toDate());
  }

  if (start != null && end != null && end.isBefore(start)) {
    end = end.add(const Duration(days: 1));
  }

  if (start != null && end != null) {
    return !now.isBefore(start) && !now.isAfter(end);
  }
  if (start != null) {
    return !now.isBefore(start);
  }
  if (end != null) {
    return !now.isAfter(end);
  }
  return false;
}

String _formatPercent(int numerator, int denominator) {
  if (denominator <= 0) return '0%';
  final percent = ((numerator / denominator) * 100).round();
  return '$percent%';
}

String _formatPercentFromDoubles(double numerator, double denominator) {
  if (denominator <= 0) return '0%';
  final percent = ((numerator / denominator) * 100).round();
  return '$percent%';
}

class _ScheduleMissingHoverPill extends StatefulWidget {
  const _ScheduleMissingHoverPill({
    required this.scheduledCount,
    required this.scheduledWorking,
    required this.missingNames,
    required this.child,
  });

  final int scheduledCount;
  final int scheduledWorking;
  final List<String> missingNames;
  final Widget child;

  @override
  State<_ScheduleMissingHoverPill> createState() =>
      _ScheduleMissingHoverPillState();
}

class _ScheduleMissingHoverPillState extends State<_ScheduleMissingHoverPill> {
  bool _hovered = false;

  void _setHovered(bool value) {
    if (_hovered == value) return;
    setState(() => _hovered = value);
  }

  @override
  Widget build(BuildContext context) {
    final hasMissing = widget.scheduledCount > 0 &&
        widget.scheduledWorking < widget.scheduledCount &&
        widget.missingNames.isNotEmpty;
    if (!hasMissing) {
      return widget.child;
    }

    final missingCount = widget.missingNames.length;
    final header =
        'Not clocked in: $missingCount/${widget.scheduledCount}';
    final text = ([header, ...widget.missingNames]).join('\n');
    final bubbleOffset = _scheduleHoverLabelGap + 22;

    return MouseRegion(
      cursor: SystemMouseCursors.basic,
      onEnter: (_) => _setHovered(true),
      onExit: (_) => _setHovered(false),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          widget.child,
          Positioned(
            bottom: bubbleOffset,
            child: IgnorePointer(
              child: AnimatedOpacity(
                opacity: _hovered ? 1 : 0,
                duration: _scheduleHoverFadeDuration,
                child: _HoverBubble(text: text),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HoverBubble extends StatelessWidget {
  const _HoverBubble({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: _scheduleHoverLabelHorizontalPadding,
        vertical: _scheduleHoverLabelVerticalPadding,
      ),
      decoration: BoxDecoration(
        color: const Color(0xCC000000),
        borderRadius: BorderRadius.circular(_scheduleHoverLabelRadius),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        text,
        style: _scheduleHoverLabelStyle,
        textAlign: TextAlign.center,
      ),
    );
  }
}
