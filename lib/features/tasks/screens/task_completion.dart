// lib/features/tasks/screens/task_completion.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_widgets/charts/column_chart.dart';

/// How to slice our dates
enum ChartInterval { daily, weekly, monthly, annual }

class TaskCompletion extends ConsumerStatefulWidget {
  final String companyId;
  final String docId;

  const TaskCompletion({
    super.key,
    required this.companyId,
    required this.docId,
  });

  @override
  ConsumerState<TaskCompletion> createState() => _TaskCompletionState();
}

class _TaskCompletionState extends ConsumerState<TaskCompletion> {
  ChartInterval _selectedInterval = ChartInterval.monthly;

  String? _dataFutureKey;
  Future<List<ChartData>>? _dataFuture;

  Future<List<ChartData>> _ensureDataFuture(ChartInterval interval) {
    final key = '${widget.companyId}|${widget.docId}|${interval.name}';
    if (_dataFutureKey == key && _dataFuture != null) return _dataFuture!;
    _dataFutureKey = key;
    _dataFuture = _loadAndGroupData(widget.docId, interval);
    return _dataFuture!;
  }

  void _selectInterval(ChartInterval next) {
    if (next == _selectedInterval) return;
    setState(() {
      _selectedInterval = next;
      _dataFutureKey = null;
      _dataFuture = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: DropdownButton<ChartInterval>(
            value: _selectedInterval,
            items: const [
              DropdownMenuItem(
                  value: ChartInterval.daily, child: Text('Daily')),
              DropdownMenuItem(
                  value: ChartInterval.weekly, child: Text('Weekly')),
              DropdownMenuItem(
                  value: ChartInterval.monthly, child: Text('Monthly')),
              DropdownMenuItem(
                  value: ChartInterval.annual, child: Text('Annual')),
            ],
            onChanged: (v) {
              if (v != null) _selectInterval(v);
            },
          ),
        ),
        Expanded(
          child: FutureBuilder<List<ChartData>>(
            future: _ensureDataFuture(_selectedInterval),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snap.hasError) {
                return Center(child: Text('Error: ${snap.error}'));
              }
              final data = snap.data!;
              if (data.isEmpty) {
                return const Center(child: Text('No data to display.'));
              }
              return Padding(
                padding: const EdgeInsets.all(16.0),
                child: ColumnChart(
                  data: data,
                  column1: 'Completed',
                  column2: 'Total Runs',
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Future<List<ChartData>> _loadAndGroupData(
    String timelineDocId,
    ChartInterval interval,
  ) async {
    final firestore = FirebaseFirestore.instance;

    // 1) Get the selected timeline doc to find its taskId.
    final tlSnap =
        await firestore.collection('timeline').doc(timelineDocId).get();
    final tlData = tlSnap.data();
    if (tlData == null || tlData['taskId'] == null) return [];

    final taskRef = tlData['taskId'] as DocumentReference<Map<String, dynamic>>;

    final cutoff = Timestamp.fromDate(
      DateTime.now().subtract(const Duration(days: 365)),
    );
    final runSnap = await firestore
        .collection('timeline')
        .where('timelineCategory', isEqualTo: 'kG9DMLORk88VrZIGD7x3')
        .where('taskId', isEqualTo: taskRef)
        .where('startTime', isGreaterThanOrEqualTo: cutoff)
        .get();

    final Map<DateTime, double> totalMap = {};
    final Map<DateTime, double> completedMap = {};

    for (final doc in runSnap.docs) {
      final data = doc.data();

      final startTs = data['startTime'] as Timestamp?;
      final completeTs = data['completeTimestamp'] as Timestamp?;
      if (startTs == null) continue;

      final d = startTs.toDate();
      DateTime bucket;
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

      totalMap[bucket] = (totalMap[bucket] ?? 0) + 1;
      if (completeTs != null) {
        completedMap[bucket] = (completedMap[bucket] ?? 0) + 1;
      }
    }

    final allBuckets = {...totalMap.keys, ...completedMap.keys}.toList()
      ..sort();
    return allBuckets
        .map((b) => ChartData(
              b,
              completedMap[b] ?? 0,
              totalMap[b] ?? 0,
            ))
        .toList();
  }
}
