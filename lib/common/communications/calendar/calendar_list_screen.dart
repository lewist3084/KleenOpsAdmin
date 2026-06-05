import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:riverpod/legacy.dart';

import 'package:kleenops_admin/app/routes.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/details_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/home_navbar_adapter.dart';
import 'package:kleenops_admin/common/communications/calendar/calendar.dart';
import 'package:kleenops_admin/app/shared_widgets/search/search_control_strip_adapter.dart';
import 'package:kleenops_admin/features/auth/providers/auth_provider.dart';
import 'package:kleenops_admin/widgets/layout/bookended_canvas.dart';

/// Search query for the calendar list view (matches against event name).
final calendarListSearchProvider = StateProvider<String>((_) => '');

/// List view of every calendar event for the current company. Shares the
/// `'calendar'` HomeNavBar section with [CommunicationsCalendarScreen] so
/// users can swap between the calendar and the agenda-style list.
class CalendarListScreen extends ConsumerWidget {
  const CalendarListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searchActive = ref.watch(calendarSearchVisibleProvider);
    return Scaffold(
      body: const BookendedCanvas(child: _CalendarListBody()),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DetailsAppBar(
            title: 'Calendar',
            showSearchToggle: true,
            searchActive: searchActive,
            onSearchToggle: () {
              final notifier =
                  ref.read(calendarSearchVisibleProvider.notifier);
              notifier.state = !notifier.state;
              if (!notifier.state) {
                ref.read(calendarListSearchProvider.notifier).state = '';
              }
            },
          ),
          const HomeNavBarAdapter(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'calendarListAddFab',
        tooltip: 'Add event',
        onPressed: () => context.push(AppRoutes.drawerCalendarForm),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _CalendarListBody extends ConsumerStatefulWidget {
  const _CalendarListBody();

  @override
  ConsumerState<_CalendarListBody> createState() => _CalendarListBodyState();
}

class _CalendarListBodyState extends ConsumerState<_CalendarListBody> {
  final _searchCtl = TextEditingController();

  @override
  void dispose() {
    _searchCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final showSearch = ref.watch(calendarSearchVisibleProvider);
    final query = ref.watch(calendarListSearchProvider).toLowerCase();
    return Column(
      children: [
        if (showSearch)
          SearchControlStrip(
            controller: _searchCtl,
            hintText: 'Search events',
            onChanged: (t) =>
                ref.read(calendarListSearchProvider.notifier).state = t,
          ),
        Expanded(
          child: ref.watch(userDocumentProvider).when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('User error: $e')),
                data: (user) {
                  final companyRef = user['companyId'] as DocumentReference?;
                  if (companyRef == null) {
                    return const Center(child: Text('No company assigned.'));
                  }
                  final memberRef =
                      ref.watch(memberDocRefProvider).value;
                  return _EventList(
                    companyRef: companyRef,
                    query: query,
                    currentMemberRef: memberRef,
                  );
                },
              ),
        ),
      ],
    );
  }
}

/// Multi-stream calendar list. Firestore rules now restrict timeline reads
/// to docs the caller has visibility on, and rules can only authorize a
/// `list` query when its `where` clauses prove every returned doc matches
/// one of the allow-branches. So we issue one constrained query per
/// visibility branch and merge the results client-side.
class _EventList extends StatefulWidget {
  const _EventList({
    required this.companyRef,
    required this.query,
    required this.currentMemberRef,
  });

  final DocumentReference companyRef;
  final String query;
  final DocumentReference<Map<String, dynamic>>? currentMemberRef;

  @override
  State<_EventList> createState() => _EventListState();
}

class _EventListState extends State<_EventList> {
  /// One entry per active stream, keyed by stream identifier. Each value is
  /// the latest set of docs that stream emitted. The visible event list is
  /// the union of all values, deduped by doc id.
  final Map<String, List<QueryDocumentSnapshot<Map<String, dynamic>>>> _byStream = {};
  final List<StreamSubscription<QuerySnapshot<Map<String, dynamic>>>> _subs = [];
  bool _initializing = true;
  String? _initError;
  String? _attachedKey; // memberRef.id used when streams were attached

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final memberRef = widget.currentMemberRef;
    if (memberRef == null) return;
    if (_attachedKey == memberRef.id) return;
    _attachStreams(memberRef);
  }

  @override
  void dispose() {
    _cancelAll();
    super.dispose();
  }

  void _cancelAll() {
    for (final s in _subs) {
      s.cancel();
    }
    _subs.clear();
    _byStream.clear();
  }

  Future<void> _attachStreams(
    DocumentReference<Map<String, dynamic>> memberRef,
  ) async {
    _cancelAll();
    _attachedKey = memberRef.id;
    setState(() {
      _initializing = true;
      _initError = null;
    });

    try {
      final memberSnap = await memberRef.get();
      final memberData = memberSnap.data() ?? <String, dynamic>{};
      final teamAccessRaw = memberData['teamAccess'];
      final myTeamIds = <String>[];
      if (teamAccessRaw is List) {
        for (final entry in teamAccessRaw) {
          if (entry is DocumentReference) myTeamIds.add(entry.id);
          if (entry is String && entry.isNotEmpty) {
            myTeamIds.add(
              entry.contains('/') ? entry.split('/').last : entry,
            );
          }
        }
      }

      final col = FirebaseFirestore.instance
          .collection('company')
          .doc(widget.companyRef.id)
          .collection('timeline');

      void attach(String key, Query<Map<String, dynamic>> q) {
        _byStream[key] = const [];
        final sub = q.snapshots().listen(
          (qs) {
            if (!mounted) return;
            setState(() => _byStream[key] = qs.docs);
          },
          onError: (e) {
            if (!mounted) return;
            setState(() => _initError = e.toString());
          },
        );
        _subs.add(sub);
      }

      // Personal entries (I created)
      attach(
        'createdBy',
        col
            .where('createdByMemberId', isEqualTo: memberRef.id)
            .orderBy('startTime'),
      );

      // Pending or decided absences routed to me as approver
      attach(
        'approver',
        col
            .where('resolvedApproverMemberId', isEqualTo: memberRef.id)
            .orderBy('startTime'),
      );

      // Team-visible absences: split per team so each query is a strict
      // arrayContains on `teamIds` (the new multi-team field written by
      // the calendar form).
      for (final tid in myTeamIds) {
        attach(
          'team-absence-$tid',
          col
              .where('teamIds', arrayContains: tid)
              .where('isAbsence', isEqualTo: true)
              .orderBy('startTime'),
        );
      }

      if (!mounted) return;
      setState(() => _initializing = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _initializing = false;
        _initError = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.currentMemberRef == null || _initializing) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_initError != null) {
      return Center(child: Text('Error: $_initError'));
    }

    final merged = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
    for (final list in _byStream.values) {
      for (final d in list) {
        merged[d.id] = d;
      }
    }
    final events = merged.values
        .map(TimelineEvent.fromDoc)
        .where((e) =>
            widget.query.isEmpty ||
            e.name.toLowerCase().contains(widget.query))
        .toList()
      ..sort((a, b) => a.start.compareTo(b.start));

    if (events.isEmpty) {
      return Center(
        child: Text(
          widget.query.isEmpty
              ? 'No events yet'
              : 'No events match "${widget.query}"',
          style: const TextStyle(color: Colors.black54),
        ),
      );
    }
    return ListView.separated(
      itemCount: events.length,
      separatorBuilder: (_, __) =>
          Divider(height: 1, color: Colors.grey.shade200),
      itemBuilder: (_, i) => _CalendarListTile(event: events[i]),
    );
  }
}

class _CalendarListTile extends StatelessWidget {
  const _CalendarListTile({required this.event});

  final TimelineEvent event;

  @override
  Widget build(BuildContext context) {
    final hue = (event.categoryId.hashCode % 360).toDouble();
    final color = HSVColor.fromAHSV(1, hue, 0.7, 0.9).toColor();
    final dateFmt = DateFormat.yMMMd().add_jm();
    final subtitle = '${dateFmt.format(event.start)}  â†’  '
        '${dateFmt.format(event.end)}';
    return ListTile(
      leading: Container(
        width: 6,
        height: 36,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(3),
        ),
      ),
      title: Text(
        event.name.isEmpty ? '(untitled)' : event.name,
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: Text(subtitle),
      onTap: () => context.push(
        '${AppRoutes.drawerCalendarForm}?docId=${event.id}',
      ),
    );
  }
}

