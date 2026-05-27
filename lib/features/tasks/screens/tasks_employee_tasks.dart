// lib/features/tasks/screens/tasks_employee_tasks.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import 'package:shared_widgets/lists/standardViewGroup.dart';
import 'package:kleenops_admin/widgets/tiles/icon_text_icon_text.dart';
import 'package:kleenops_admin/features/auth/providers/auth_provider.dart';
import 'package:shared_widgets/utils/process_localization_utils.dart';

final Map<String, Future<DocumentSnapshot<Map<String, dynamic>>>>
    _taskDocCache =
    <String, Future<DocumentSnapshot<Map<String, dynamic>>>>{};

Future<DocumentSnapshot<Map<String, dynamic>>> _cachedTaskDoc(
    DocumentReference<Map<String, dynamic>> ref) {
  final cached = _taskDocCache[ref.path];
  if (cached != null) return cached;
  final f = ref.get();
  _taskDocCache[ref.path] = f;
  if (_taskDocCache.length > 256) {
    _taskDocCache.remove(_taskDocCache.keys.first);
  }
  return f;
}

final DateFormat _dayHeaderFormat = DateFormat.yMMMMd();

String _groupKeyForDate(DateTime? date) {
  if (date == null) return '0000000000000#No Date';
  final local = date.toLocal();
  final day = DateTime(local.year, local.month, local.day);
  final millis = day.millisecondsSinceEpoch.toString().padLeft(13, '0');
  return '$millis#${_dayHeaderFormat.format(local)}';
}

class TasksEmployeeTasksContent extends ConsumerWidget {
  const TasksEmployeeTasksContent({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final companyRefAsync = ref.watch(companyIdProvider);

    return companyRefAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) =>
          Center(child: Text('Error loading company: $err')),
      data: (companyRef) {
        if (companyRef == null || companyRef.id.isEmpty) {
          return const Center(child: Text('No company found.'));
        }

        final localeCodeRaw =
            Localizations.localeOf(context).languageCode.trim().toLowerCase();
        final effectiveLocale = localeCodeRaw.isNotEmpty
            ? localeCodeRaw
            : ProcessLocalizationUtils.defaultLocaleCode;

        final memberAsync = ref.watch(memberDocRefProvider);
        return memberAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) =>
              Center(child: Text('Error loading member: $err')),
          data: (memberRef) {
            if (memberRef == null) {
              return const Center(child: Text('Member not linked.'));
            }

            final query = FirebaseFirestore.instance
                .collection('timeline')
                .where('timelineCategory', isEqualTo: 'E2HMUuMUUl4Alttuweba')
                .where('memberId', isEqualTo: memberRef)
                .orderBy('startTime', descending: true);

            return StandardViewGroup(
              queryStream: query.snapshots(),
              emptyMessage: 'No assigned tasks.',
              physics: const AlwaysScrollableScrollPhysics(),
              enableReorder: false,
              groupBy: (doc) {
                final ts = doc.data()['startTime'] as Timestamp?;
                return _groupKeyForDate(ts?.toDate());
              },
              groupSort: (a, b) => b.compareTo(a),
              itemBuilder: (doc) {
                final data = doc.data();
                final taskRef = data['taskId']
                    as DocumentReference<Map<String, dynamic>>?;

                String? trimmedString(dynamic value) {
                  if (value is String) {
                    final trimmed = value.trim();
                    if (trimmed.isNotEmpty) return trimmed;
                  }
                  return null;
                }

                final duration = (data['duration'] as num?)?.toInt() ?? 0;
                final allotment =
                    (data['taskDurationAllotment'] as num?)?.toInt() ?? 0;

                if (taskRef == null) {
                  final resolvedName =
                      ProcessLocalizationUtils.resolveLocalizedText(
                    data['name'],
                    localeCode: effectiveLocale,
                    fallbackLocaleCode:
                        ProcessLocalizationUtils.defaultLocaleCode,
                  );
                  return IconTextIconTextTile(
                    leftIcon: Icons.check_box_outlined,
                    leftText: trimmedString(resolvedName) ??
                        trimmedString(data['name']) ??
                        trimmedString(data['title']) ??
                        'Untitled Task',
                    rightText: '$duration/$allotment min',
                    rightIcon: Icons.timer_outlined,
                  );
                }

                return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  future: _cachedTaskDoc(taskRef),
                  builder: (context, snap) {
                    String title =
                        trimmedString(data['title']) ?? 'Untitled Task';
                    if (snap.connectionState == ConnectionState.done) {
                      if (snap.hasData && snap.data!.exists) {
                        final taskData = snap.data!.data();
                        final resolvedName =
                            ProcessLocalizationUtils.resolveLocalizedText(
                          taskData?['name'],
                          localeCode: effectiveLocale,
                          fallbackLocaleCode:
                              ProcessLocalizationUtils.defaultLocaleCode,
                        );
                        title = trimmedString(resolvedName) ??
                            trimmedString(taskData?['title']) ??
                            title;
                      }
                    }

                    return IconTextIconTextTile(
                      leftIcon: Icons.check_box_outlined,
                      leftText: title,
                      rightText: '$duration/$allotment min',
                      rightIcon: Icons.timer_outlined,
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}
