/* ---------------------------------------------------------------------------
 * Scheduling > Blackouts Form
 * Admin port: top-level `task` collection; AI canvas wrappers stripped.
 * ---------------------------------------------------------------------------*/
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/details_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/home_navbar_adapter.dart';
import 'package:kleenops_admin/widgets/layout/bookended_canvas.dart';

import 'package:shared_widgets/containers/container_action.dart';
import 'package:shared_widgets/lists/standardView.dart';
import 'package:shared_widgets/dialogs/dialog_action.dart';
import 'package:kleenops_admin/widgets/fields/multi_select/day_multi_select.dart';

class SchedulingBlackoutsDetailsContent extends ConsumerStatefulWidget {
  final String routineId;
  const SchedulingBlackoutsDetailsContent({
    super.key,
    required this.routineId,
  });

  @override
  ConsumerState<SchedulingBlackoutsDetailsContent> createState() =>
      _SchedulingBlackoutsFormState();
}

class _SchedulingBlackoutsFormState
    extends ConsumerState<SchedulingBlackoutsDetailsContent> {
  late final DocumentReference<Map<String, dynamic>> _routineRef;
  late final Stream<DocumentSnapshot<Map<String, dynamic>>> _routineStream;

  @override
  void initState() {
    super.initState();
    // Admin top-level `task` collection.
    _routineRef = FirebaseFirestore.instance
        .collection('task')
        .doc(widget.routineId)
        .withConverter<Map<String, dynamic>>(
          fromFirestore: (snap, _) => snap.data() ?? {},
          toFirestore: (data, _) => data,
        );
    _routineStream = _routineRef.snapshots();
  }

  List<String> _extractDays(dynamic raw) {
    if (raw == null) return [];
    if (raw is List) return raw.cast<String>();
    if (raw is Map) {
      return raw.entries
          .where((e) => e.value == true)
          .map((e) => e.key.toString())
          .toList();
    }
    return [];
  }

  Future<void> _addOrEditInterval({
    Map<String, dynamic>? initial,
    required bool isDate,
  }) async {
    final DateFormat df = DateFormat('yyyy-MM-dd');

    List<String> selDays = _extractDays(initial?['day']);
    DateTime? selDate = (initial?['date'] as Timestamp?)?.toDate();
    TimeOfDay? start = initial == null
        ? null
        : TimeOfDay.fromDateTime(
            (initial['startTime'] as Timestamp).toDate());
    TimeOfDay? end = initial == null
        ? null
        : TimeOfDay.fromDateTime(
            (initial['endTime'] as Timestamp).toDate());

    bool? saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => DialogAction(
        title: initial == null ? 'New Blackout' : 'Edit Blackout',
        cancelText: 'Cancel',
        actionText: 'Save',
        onCancel: () => Navigator.pop(ctx, false),
        onAction: () {
          if (start == null ||
              end == null ||
              (isDate ? selDate == null : selDays.isEmpty)) {
            return;
          }
          Navigator.pop(ctx, true);
        },
        content: StatefulBuilder(
          builder: (c, setState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Text('One-off date'),
                  Switch(
                    value: isDate,
                    onChanged: (v) => setState(() => isDate = v),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (isDate) ...[
                ListTile(
                  leading: const Icon(Icons.calendar_today),
                  title: Text(
                      selDate == null ? 'Pick a date' : df.format(selDate!)),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: selDate ?? DateTime.now(),
                      firstDate: DateTime(2023),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) setState(() => selDate = picked);
                  },
                ),
              ] else ...[
                DayMultiSelectDropdown(
                  selectedDays:
                      selDays.map((d) => d.substring(0, 3)).toList(),
                  onChanged: (abbrList) => setState(() {
                    const full = {
                      'Mon': 'Monday',
                      'Tue': 'Tuesday',
                      'Wed': 'Wednesday',
                      'Thu': 'Thursday',
                      'Fri': 'Friday',
                      'Sat': 'Saturday',
                      'Sun': 'Sunday',
                    };
                    selDays = abbrList.map((a) => full[a]!).toList();
                  }),
                  options: const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
                ),
              ],
              const SizedBox(height: 12),
              Row(children: [
                const Text('Start:'),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () async {
                    final t = await showTimePicker(
                      context: context,
                      initialTime: start ?? TimeOfDay.now(),
                    );
                    if (t != null) setState(() => start = t);
                  },
                  child: Text(start?.format(context) ?? 'Pick'),
                ),
                const Spacer(),
                const Text('End:'),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () async {
                    final t = await showTimePicker(
                      context: context,
                      initialTime: end ?? TimeOfDay.now(),
                    );
                    if (t != null) setState(() => end = t);
                  },
                  child: Text(end?.format(context) ?? 'Pick'),
                ),
              ]),
            ],
          ),
        ),
      ),
    );

    if (saved != true) return;

    final now = DateTime.now();
    DateTime mkDT(TimeOfDay tod) =>
        DateTime(now.year, now.month, now.day, tod.hour, tod.minute);

    final newInterval = <String, dynamic>{
      if (isDate)
        'date': Timestamp.fromDate(
            DateTime(selDate!.year, selDate!.month, selDate!.day)),
      if (!isDate) 'day': selDays,
      'startTime': Timestamp.fromDate(mkDT(start!)),
      'endTime': Timestamp.fromDate(mkDT(end!)),
    };

    if (initial != null) {
      await _routineRef.update({
        'blackouts.blackoutInterval': FieldValue.arrayRemove([initial])
      });
    }

    await _routineRef.update({
      'blackouts.blackoutInterval': FieldValue.arrayUnion([newInterval])
    });
  }

  Future<void> _deleteInterval(Map<String, dynamic> interval) async {
    await _routineRef.update({
      'blackouts.blackoutInterval': FieldValue.arrayRemove([interval])
    });
  }

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('M/d/yyyy');
    final timeFmt = DateFormat('h:mm a');

    final content = StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _routineStream,
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final data = snap.data!.data() ?? {};
        final List<dynamic> rawList =
            (data['blackouts']?['blackoutInterval'] as List<dynamic>? ?? [])
                .toList();
        final intervals = rawList.cast<Map<String, dynamic>>();

        final recurring = intervals.where((m) => m['day'] != null).toList();
        final oneOff = intervals.where((m) => m['date'] != null).toList();

        String dayLabel(Map<String, dynamic> m) {
          final d = m['day'];
          if (d is List) return d.join(', ');
          if (d is Map) {
            final keys = _extractDays(d);
            return keys.join(', ');
          }
          return '';
        }

        Widget buildRow(Map<String, dynamic> m) {
          final leading = m.containsKey('date')
              ? dateFmt.format((m['date'] as Timestamp).toDate())
              : dayLabel(m);
          final s = timeFmt.format((m['startTime'] as Timestamp).toDate());
          final e = timeFmt.format((m['endTime'] as Timestamp).toDate());
          return ListTile(
            title: Text(leading),
            subtitle: Text('$s - $e'),
          );
        }

        Widget buildList(List<Map<String, dynamic>> list, bool isDate) {
          return StandardView<Map<String, dynamic>>(
            items: list,
            disableGrouping: true,
            groupBy: (_) => null,
            itemBuilder: buildRow,
            onSwipeRight: (m) => _deleteInterval(m),
            onTap: (m) => _addOrEditInterval(initial: m, isDate: isDate),
          );
        }

        return SingleChildScrollView(
          padding: EdgeInsets.only(
            bottom: 16.0 + MediaQuery.of(context).padding.bottom,
          ),
          child: Column(
            children: [
              ContainerActionWidget(
                title: 'Recurring (weekday)',
                content: buildList(recurring, false),
                actionText: 'Add',
                onAction: () => _addOrEditInterval(isDate: false),
              ),
              ContainerActionWidget(
                title: 'One-off (date)',
                content: buildList(oneOff, true),
                actionText: 'Add',
                onAction: () => _addOrEditInterval(isDate: true),
              ),
            ],
          ),
        );
      },
    );

    return Scaffold(
      body: BookendedCanvas(child: content),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const DetailsAppBar(title: 'Blackouts'),
          const HomeNavBarAdapter(),
        ],
      ),
    );
  }
}
