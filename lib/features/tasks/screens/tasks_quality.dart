// lib/features/tasks/screens/tasks_quality.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:shared_widgets/lists/standardViewGroup.dart';
import 'package:shared_widgets/tiles/standard_bubble_tile.dart';
import 'package:kleenops_admin/features/auth/providers/auth_provider.dart';

class TasksQualityContent extends ConsumerStatefulWidget {
  const TasksQualityContent({super.key});

  @override
  ConsumerState<TasksQualityContent> createState() =>
      _TasksQualityContentState();
}

class _TasksQualityContentState extends ConsumerState<TasksQualityContent> {
  Query<Map<String, dynamic>> _pendingTimelineQuery({
    required DocumentReference<Map<String, dynamic>> memberRef,
  }) {
    return FirebaseFirestore.instance
        .collection('timeline')
        .where('timelineCategory', isEqualTo: 'VdjzT5izZVSWmrhfRRq0')
        .where('opened', isEqualTo: false)
        .where('memberId', isEqualTo: memberRef)
        .orderBy('createdAt', descending: true);
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateChangesProvider);
    final companyRefAsync = ref.watch(companyIdProvider);

    return authState.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (user) {
        if (user == null) {
          return const Center(child: Text('User not logged in.'));
        }

        final userDocAsync = ref.watch(userDocumentProvider);

        return userDocAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) =>
              Center(child: Text('Error loading profile: $error')),
          data: (userDoc) {
            final memberRef = userDoc['memberRef']
                as DocumentReference<Map<String, dynamic>>?;
            if (memberRef == null) {
              return const Center(child: Text('Member not linked.'));
            }

            return companyRefAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) =>
                  Center(child: Text('Error loading company: $e')),
              data: (companyRef) {
                if (companyRef == null) {
                  return const Center(child: Text('No company found.'));
                }

                final query =
                    _pendingTimelineQuery(memberRef: memberRef);

                String? dayLabel(
                    QueryDocumentSnapshot<Map<String, dynamic>> d) {
                  final ts = d.data()['createdAt'];
                  if (ts is! Timestamp) return null;
                  return DateFormat('M/d/yyyy EEEE').format(ts.toDate());
                }

                return StandardViewGroup.paginated(
                  query: query,
                  pageSize: 100,
                  physics: const ClampingScrollPhysics(),
                  emptyBuilder: (_) => const Center(
                      child: Text('No pending quality issues found.')),
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

                    String? stringField(dynamic value) {
                      if (value is String) {
                        final trimmed = value.trim();
                        if (trimmed.isNotEmpty) return trimmed;
                      }
                      return null;
                    }

                    final displayName = stringField(data['name']) ??
                        stringField(data['title']) ??
                        'Unnamed';
                    final description = stringField(data['description']) ??
                        stringField(data['message']) ??
                        stringField(data['notes']);

                    final Timestamp? createdAtTs =
                        data['createdAt'] as Timestamp?;
                    final createdAtLabel = createdAtTs != null
                        ? DateFormat('M/d/yyyy h:mm a')
                            .format(createdAtTs.toDate().toLocal())
                        : 'Date unavailable';

                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: StandardBubbleTile(
                        title: displayName,
                        description: description,
                        metaLabel: createdAtLabel,
                        leadingIcon: Icons.science_outlined,
                        // Route not yet wired in admin.
                        onTap: () {},
                      ),
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
