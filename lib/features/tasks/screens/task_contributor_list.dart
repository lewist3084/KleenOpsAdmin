// lib/features/tasks/screens/task_contributor_list.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import 'package:kleenops_admin/widgets/tiles/icon_text_icon_text.dart';
import 'package:shared_widgets/lists/standardViewGroup.dart';

class TaskContributorList extends ConsumerStatefulWidget {
  final String companyId;
  final String docId;

  const TaskContributorList({
    super.key,
    required this.companyId,
    required this.docId,
  });

  @override
  ConsumerState<TaskContributorList> createState() =>
      _TaskContributorListState();
}

class _TaskContributorListState extends ConsumerState<TaskContributorList> {
  Stream<DocumentSnapshot<Map<String, dynamic>>>? _timelineRefStream;

  String? _entriesKey;
  Query<Map<String, dynamic>>? _entriesQuery;

  @override
  Widget build(BuildContext context) {
    final timelineRef =
        FirebaseFirestore.instance.collection('timeline').doc(widget.docId);

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _timelineRefStream ??= timelineRef.snapshots(),
      builder: (context, tlSnap) {
        if (tlSnap.hasError) {
          return Center(child: Text('Error: ${tlSnap.error}'));
        }
        if (!tlSnap.hasData || !tlSnap.data!.exists) {
          return const Center(child: CircularProgressIndicator());
        }

        final data = tlSnap.data!.data()!;
        final taskRef =
            data['taskId'] as DocumentReference<Map<String, dynamic>>;

        if (_entriesKey != taskRef.path || _entriesQuery == null) {
          _entriesKey = taskRef.path;
          _entriesQuery = FirebaseFirestore.instance
              .collection('timeline')
              .where('taskId', isEqualTo: taskRef)
              .orderBy('completeTimestamp', descending: true);
        }

        String? dayLabel(QueryDocumentSnapshot<Map<String, dynamic>> d) {
          final ts = d.data()['endTime'];
          if (ts is! Timestamp) return null;
          return DateFormat('MMM d, yyyy').format(ts.toDate());
        }

        return StandardViewGroup.paginated(
          query: _entriesQuery!,
          queryKey: _entriesKey,
          pageSize: 100,
          sectionHeaderBuilder: (ctx, doc, prev, _) {
            final label = dayLabel(doc);
            if (label == null) return null;
            if (prev != null && dayLabel(prev) == label) return null;
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(label,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 14)),
            );
          },
          itemBuilder: (ctx, docSnap, _) {
            final contribMap =
                (docSnap.data()['contributors'] as Map<String, dynamic>?) ??
                    {};

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: contribMap.entries.map((entry) {
                final m = entry.value as Map<String, dynamic>;
                final name = m['name'] as String? ?? 'Unknown';
                final duration = m['duration'] as int? ?? 0;
                final allotment = m['taskDurationAllotment'] as int?;

                return IconTextIconTextTile(
                  leftIcon: Icons.person_outlined,
                  leftText: name,
                  rightIcon: Icons.watch_later_outlined,
                  rightText: allotment != null && allotment > 0
                      ? '$duration/$allotment min'
                      : '$duration min',
                  verticalPadding: 8.0,
                );
              }).toList(),
            );
          },
        );
      },
    );
  }
}
