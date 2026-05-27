// lib/features/tasks/screens/tasks_timecard.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';

import 'package:kleenops_admin/features/auth/providers/auth_provider.dart';
import 'package:shared_widgets/lists/standardViewGroup.dart';
import 'package:kleenops_admin/app/router.dart'; // For CompanyWrapper

class TasksTimecardContent extends ConsumerWidget {
  const TasksTimecardContent({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final memberRef = ref.watch(memberDocRefProvider).value;
    if (memberRef == null) {
      return const Center(child: Text('User not logged in.'));
    }

    return CompanyWrapper(
      builder: (companyRef) {
        final categoryRef = FirebaseFirestore.instance
            .collection('timelineCategory')
            .doc('X8yZRs8e8xXyHPl4VNAN');

        // Admin uses TOP-LEVEL `timeline` collection.
        final timelineQuery = FirebaseFirestore.instance
            .collection('timeline')
            .where('timelineCategoryId', isEqualTo: categoryRef)
            .where('memberId', isEqualTo: memberRef)
            .orderBy('startTime', descending: true);

        String? dayLabel(QueryDocumentSnapshot<Map<String, dynamic>> d) {
          final ts = d.data()['startTime'];
          if (ts is! Timestamp) return null;
          return DateFormat('M/d/yyyy EEEE').format(ts.toDate());
        }

        return StandardViewGroup.paginated(
          query: timelineQuery,
          pageSize: 100,
          physics: const ClampingScrollPhysics(),
          emptyBuilder: (_) =>
              const Center(child: Text('No timecards found.')),
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
          itemBuilder: (ctx, doc, _) {
            final data = doc.data();
            final actualStartTs = (data['startTime'] as Timestamp?) ??
                (data['clockInTime'] as Timestamp?);
            final actualEndTs = (data['endTime'] as Timestamp?) ??
                (data['clockOutTime'] as Timestamp?);
            final scheduledStartTs = data['scheduledStart'] as Timestamp?;
            final scheduledEndTs = data['scheduledEnd'] as Timestamp?;
            final forcedClockout = data['forcedClockout'] == true;

            String fmt(DateTime? value) =>
                value == null ? '' : DateFormat('h:mm a').format(value);

            final actualStart = actualStartTs?.toDate();
            final dayLabel = actualStart != null
                ? DateFormat('EEEE').format(actualStart)
                : '';

            // DegradationFallback: admin has no DependabilityTile yet.
            return InkWell(
              onTap: forcedClockout
                  ? () {
                      // Route not yet wired in admin; preserve URL shape.
                      context.push(
                        '/tasks/timecard/form?cid=${companyRef.id}&docId=${doc.id}',
                      );
                    }
                  : null,
              child: ListTile(
                leading: Icon(
                  forcedClockout
                      ? Icons.lock_open
                      : Icons.lock_clock_outlined,
                  color: forcedClockout ? Colors.red : null,
                ),
                title: Text(dayLabel),
                subtitle: Text(
                  'Scheduled: ${fmt(scheduledStartTs?.toDate())} - ${fmt(scheduledEndTs?.toDate())}\n'
                  'Actual: ${fmt(actualStart)} - ${fmt(actualEndTs?.toDate())}',
                ),
                isThreeLine: true,
              ),
            );
          },
        );
      },
    );
  }
}
