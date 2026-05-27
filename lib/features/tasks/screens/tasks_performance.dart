// lib/features/tasks/screens/tasks_performance.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:shared_widgets/lists/standardViewGroup.dart';
import 'package:shared_widgets/tiles/standard_bubble_tile.dart';
import 'package:kleenops_admin/features/auth/providers/auth_provider.dart';

final Map<String, Future<DocumentSnapshot<Map<String, dynamic>>>>
    _perfObservationCache =
    <String, Future<DocumentSnapshot<Map<String, dynamic>>>>{};

Future<DocumentSnapshot<Map<String, dynamic>>> _cachedPerfObservation(
    DocumentReference<Map<String, dynamic>> ref) {
  final cached = _perfObservationCache[ref.path];
  if (cached != null) return cached;
  final f = ref.get();
  _perfObservationCache[ref.path] = f;
  if (_perfObservationCache.length > 64) {
    _perfObservationCache.remove(_perfObservationCache.keys.first);
  }
  return f;
}

DocumentReference<Map<String, dynamic>> _typedDoc(String path) {
  return FirebaseFirestore.instance
      .doc(path)
      .withConverter<Map<String, dynamic>>(
        fromFirestore: (snap, _) => snap.data() ?? <String, dynamic>{},
        toFirestore: (value, _) => value,
      );
}

class TasksPerformanceContent extends ConsumerStatefulWidget {
  const TasksPerformanceContent({super.key});

  @override
  ConsumerState<TasksPerformanceContent> createState() =>
      _TasksPerformanceContentState();
}

class _TasksPerformanceContentState
    extends ConsumerState<TasksPerformanceContent> {
  static const List<String> _timestampFallbackKeys = [
    'openedAt',
    'acknowledgedAt',
    'updatedAt',
    'timestamp',
    'created',
  ];

  Query<Map<String, dynamic>> _pendingTimelineQuery({
    required String categoryId,
    required DocumentReference<Map<String, dynamic>> memberRef,
  }) {
    return FirebaseFirestore.instance
        .collection('timeline')
        .where('timelineCategory', isEqualTo: categoryId)
        .where('memberId', isEqualTo: memberRef)
        .where('opened', isEqualTo: false)
        .orderBy('createdAt', descending: true);
  }

  Timestamp? _parseTimestampValue(dynamic value) {
    if (value is Timestamp) return value;
    if (value is num) {
      return Timestamp.fromMillisecondsSinceEpoch(value.toInt());
    }
    if (value is String) {
      final parsed = DateTime.tryParse(value);
      if (parsed != null) {
        return Timestamp.fromDate(parsed);
      }
    }
    return null;
  }

  Timestamp? _extractCreatedAt(Map<String, dynamic> data) {
    final direct = _parseTimestampValue(data['createdAt']);
    if (direct != null) return direct;

    for (final key in _timestampFallbackKeys) {
      final fallback = _parseTimestampValue(data[key]);
      if (fallback != null) return fallback;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateChangesProvider);
    final companyRefAsync = ref.watch(companyIdProvider);
    final memberRefAsync = ref.watch(memberDocRefProvider);

    return authState.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(child: Text('Error: $error')),
      data: (user) {
        if (user == null) {
          return const Center(child: Text('User not logged in.'));
        }
        return companyRefAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) =>
              Center(child: Text('Error loading company: $error')),
          data: (companyRef) {
            if (companyRef == null) {
              return const Center(child: Text('No company found.'));
            }

            return memberRefAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) =>
                  Center(child: Text('Error loading member: $error')),
              data: (memberRef) {
                if (memberRef == null) {
                  return const Center(child: Text('Member not linked.'));
                }

                final query = _pendingTimelineQuery(
                  categoryId: 'tduBfySxxvZulBq6Qqv6',
                  memberRef: memberRef,
                );

                return StandardViewGroup.paginated(
                  query: query,
                  pageSize: 100,
                  physics: const ClampingScrollPhysics(),
                  emptyBuilder: (_) => const Center(
                      child: Text(
                          'No pending performance observations found.')),
                  itemBuilder: (ctx, doc, _) {
                    final data = doc.data();
                    final perfRefValue = data['performanceObservationId'];

                    String? stringField(dynamic value) {
                      if (value is String) {
                        final trimmed = value.trim();
                        if (trimmed.isNotEmpty) return trimmed;
                      }
                      return null;
                    }

                    final createdAtTs = _extractCreatedAt(data);

                    final createdAtLabel = createdAtTs != null
                        ? DateFormat('M/d/yyyy h:mm a')
                            .format(createdAtTs.toDate().toLocal())
                        : 'Date unavailable';

                    final description = stringField(data['notes']) ??
                        stringField(data['description']) ??
                        stringField(data['message']);

                    final fallbackTitle = stringField(data['title']) ??
                        stringField(data['name']) ??
                        'Performance Observation';

                    Widget buildTile(String performanceName) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        child: StandardBubbleTile(
                          title: performanceName,
                          description: description,
                          metaLabel: createdAtLabel,
                          leadingIcon: Icons.door_front_door_outlined,
                          // Admin port: read-only — performance form not
                          // ported (depends on signature widget etc).
                          onTap: () {},
                        ),
                      );
                    }

                    if (perfRefValue is! DocumentReference) {
                      return buildTile(fallbackTitle);
                    }

                    final perfRef = _typedDoc(perfRefValue.path);

                    return FutureBuilder<
                        DocumentSnapshot<Map<String, dynamic>>>(
                      future: _cachedPerfObservation(perfRef),
                      builder: (context, snapshot) {
                        var performanceName = fallbackTitle;
                        if (snapshot.connectionState ==
                                ConnectionState.waiting &&
                            !snapshot.hasData) {
                          performanceName = 'Loading...';
                        } else if (snapshot.hasData &&
                            snapshot.data!.exists) {
                          final perfData = snapshot.data!.data();
                          final fetchedName = stringField(perfData?['name']);
                          if (fetchedName != null) {
                            performanceName = fetchedName;
                          }
                        }

                        return buildTile(performanceName);
                      },
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
