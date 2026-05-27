// lib/features/supervision/screens/supervision_stats_hours_worked.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:shared_widgets/charts/column_chart.dart';
import 'package:shared_widgets/theme/app_palette.dart';
import 'package:shared_widgets/search/search_field_action.dart';
import 'package:shared_widgets/dialogs/dialog_action.dart';
import 'package:shared_widgets/labels/text_info_checkbox.dart';

enum ChartInterval { daily, weekly, monthly, annual }

class SupervisionStatsHoursWorkedContent extends ConsumerStatefulWidget {
  const SupervisionStatsHoursWorkedContent({super.key});

  @override
  ConsumerState<SupervisionStatsHoursWorkedContent> createState() =>
      _SupervisionStatsHoursWorkedContentState();
}

class _SupervisionStatsHoursWorkedContentState
    extends ConsumerState<SupervisionStatsHoursWorkedContent> {
  ChartInterval _selectedInterval = ChartInterval.weekly;
  final List<DocumentReference<Map<String, dynamic>>> _selectedTeamRefs = [];

  final TextEditingController _dummySearchCtl = TextEditingController();

  @override
  void dispose() {
    _dummySearchCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Center(child: Text('User not logged in'));
    }

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          SearchFieldAction(
            controller: _dummySearchCtl,
            labelText: 'Filters…',
            onChanged: (_) {},
            actionIcon: const Icon(Icons.filter_list),
            actionTooltip: 'Open filters',
            onAction: () async {
              // Admin: top-level team collection.
              final teamSnap =
                  await FirebaseFirestore.instance.collection('team').get();
              final teamDocs = teamSnap.docs;
              final teamRefs = teamDocs
                  .map((d) => d.reference.withConverter<Map<String, dynamic>>(
                        fromFirestore: (s, _) => s.data() ?? {},
                        toFirestore: (m, _) => m,
                      ))
                  .toList();
              final teamNames = teamDocs
                  .map((d) => (d.data()['name'] as String?) ?? '')
                  .toList();

              var tempInterval = _selectedInterval;
              final initialIndices = <int>{
                for (int i = 0; i < teamRefs.length; i++)
                  if (_selectedTeamRefs.contains(teamRefs[i])) i
              };
              final tempSelectedIndices = {...initialIndices};

              await showDialog<void>(
                context: context,
                builder: (context) {
                  return DialogAction(
                    title: 'Filter by Interval & Teams',
                    cancelText: 'Cancel',
                    onCancel: () => Navigator.pop(context),
                    actionText: 'OK',
                    onAction: () {
                      setState(() {
                        _selectedInterval = tempInterval;
                        _selectedTeamRefs
                          ..clear()
                          ..addAll(tempSelectedIndices
                              .map((i) => teamRefs[i]));
                      });
                      Navigator.pop(context);
                    },
                    content: StatefulBuilder(
                      builder: (context, setStateDialog) {
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            DropdownButtonFormField<ChartInterval>(
                              initialValue: tempInterval,
                              decoration: const InputDecoration(
                                  labelText: 'Interval'),
                              items: const [
                                DropdownMenuItem(
                                    value: ChartInterval.daily,
                                    child: Text('Daily')),
                                DropdownMenuItem(
                                    value: ChartInterval.weekly,
                                    child: Text('Weekly')),
                                DropdownMenuItem(
                                    value: ChartInterval.monthly,
                                    child: Text('Monthly')),
                                DropdownMenuItem(
                                    value: ChartInterval.annual,
                                    child: Text('Annual')),
                              ],
                              onChanged: (v) {
                                if (v != null) {
                                  setStateDialog(() {
                                    tempInterval = v;
                                  });
                                }
                              },
                            ),
                            const SizedBox(height: 16),
                            const Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'Teams',
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600),
                              ),
                            ),
                            const SizedBox(height: 8),
                            ...List.generate(teamRefs.length, (i) {
                              return TextInfoCheckbox(
                                leadingIcon: Icons.group,
                                text: teamNames[i],
                                value: tempSelectedIndices.contains(i),
                                onChanged: (checked) {
                                  setStateDialog(() {
                                    if (checked == true) {
                                      tempSelectedIndices.add(i);
                                    } else {
                                      tempSelectedIndices.remove(i);
                                    }
                                  });
                                },
                                onInfoPressed: null,
                                activeColor:
                                    AppPaletteScope.of(context).primary2,
                                boldText: false,
                                greyWhenDisabled: false,
                              );
                            }),
                          ],
                        );
                      },
                    ),
                  );
                },
              );
            },
          ),
          const SizedBox(height: 16),
          Expanded(
            child: FutureBuilder<List<ChartData>>(
              future: _loadAndGroupData(
                _selectedInterval,
                _selectedTeamRefs,
              ),
              builder: (ctx, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Center(child: Text('Error: ${snap.error}'));
                }
                return ColumnChart(
                  data: snap.data!,
                  column1: 'Actual',
                  column2: 'Scheduled',
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<List<ChartData>> _loadAndGroupData(
    ChartInterval interval,
    List<DocumentReference<Map<String, dynamic>>> teamRefs,
  ) async {
    final firestore = FirebaseFirestore.instance;
    final teams = teamRefs.isNotEmpty
        ? teamRefs
        : (await firestore.collection('team').get())
            .docs
            .map((d) => d.reference.withConverter<Map<String, dynamic>>(
                  fromFirestore: (s, _) => s.data() ?? {},
                  toFirestore: (m, _) => m,
                ))
            .toList();

    // Admin: top-level member.
    final memberSnap = await firestore
        .collection('member')
        .where('primaryTeamId', whereIn: teams)
        .where('active', isEqualTo: true)
        .get();
    final members = memberSnap.docs.map((d) => d.reference).toList();

    // Admin: top-level timeline. Chunked whereIn (limit 10).
    final tlCol = firestore.collection('timeline');
    final List<QueryDocumentSnapshot<Map<String, dynamic>>> tlDocs = [];
    const int chunk = 10;
    for (int i = 0; i < members.length; i += chunk) {
      final sub = members.sublist(
          i, i + chunk > members.length ? members.length : i + chunk);
      final qs = await tlCol.where('memberId', whereIn: sub).get();
      tlDocs.addAll(qs.docs);
    }

    final actualMap = <DateTime, double>{};
    final scheduledMap = <DateTime, double>{};

    for (var doc in tlDocs) {
      final data = doc.data();
      final startVal = data['startTime'];
      final endVal = data['endTime'];
      if (startVal is! Timestamp || endVal is! Timestamp) continue;

      final startTs = startVal;
      final endTs = endVal;
      final cat = data['timelineCategory'] as String? ?? '';

      double minutes =
          (data['duration'] is num) ? (data['duration'] as num).toDouble() : 0.0;
      if (minutes <= 0) {
        minutes =
            endTs.toDate().difference(startTs.toDate()).inMinutes.toDouble();
      }
      final hours = minutes / 60.0;
      late DateTime bucket;
      final d = startTs.toDate();
      switch (interval) {
        case ChartInterval.daily:
          bucket = DateTime(d.year, d.month, d.day);
          break;
        case ChartInterval.weekly:
          final monday = d.subtract(Duration(days: d.weekday - 1));
          bucket = DateTime(monday.year, monday.month, monday.day);
          break;
        case ChartInterval.monthly:
          bucket = DateTime(d.year, d.month);
          break;
        case ChartInterval.annual:
          bucket = DateTime(d.year);
          break;
      }

      if (cat == 'X8yZRs8e8xXyHPl4VNAN') {
        actualMap[bucket] = (actualMap[bucket] ?? 0) + hours;
      } else if (cat == 'ZLAjjDKp3hgRankr4sQ8') {
        scheduledMap[bucket] = (scheduledMap[bucket] ?? 0) + hours;
      }
    }

    final allBuckets = {...actualMap.keys, ...scheduledMap.keys}.toList()
      ..sort();
    return allBuckets
        .map((b) => ChartData(b, actualMap[b] ?? 0, scheduledMap[b] ?? 0))
        .toList();
  }
}
