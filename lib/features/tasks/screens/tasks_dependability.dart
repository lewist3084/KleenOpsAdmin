// lib/features/tasks/screens/tasks_dependability.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import 'package:kleenops_admin/features/auth/providers/auth_provider.dart';
import 'package:shared_widgets/lists/standardViewGroup.dart';
import 'package:shared_widgets/tiles/standard_tile_small.dart';

final Map<String, Future<DocumentSnapshot>> _perfObservationCache =
    <String, Future<DocumentSnapshot>>{};

Future<DocumentSnapshot> _cachedPerfObservation(DocumentReference ref) {
  final cached = _perfObservationCache[ref.path];
  if (cached != null) return cached;
  final f = ref.get();
  _perfObservationCache[ref.path] = f;
  if (_perfObservationCache.length > 64) {
    _perfObservationCache.remove(_perfObservationCache.keys.first);
  }
  return f;
}

class TasksDependabilityContent extends ConsumerWidget {
  const TasksDependabilityContent({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final companyAsync = ref.watch(companyIdProvider);
    final memberAsync = ref.watch(memberDocRefProvider);
    return companyAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) =>
          Center(child: Text('Error loading company: $error')),
      data: (companyRef) {
        if (companyRef == null) {
          return const Center(child: Text('No company found.'));
        }

        return memberAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) =>
              Center(child: Text('Error loading member: $error')),
          data: (memberRef) {
            if (memberRef == null) {
              return const Center(child: Text('Member not linked.'));
            }

            final query = FirebaseFirestore.instance
                .collection('timeline')
                .where('timelineCategory', isEqualTo: 'tduBfySxxvZulBq6Qqv6')
                .where('memberId', isEqualTo: memberRef)
                .orderBy('createdAt', descending: true);

            String? dayLabel(QueryDocumentSnapshot<Map<String, dynamic>> d) {
              final ts = d.data()['createdAt'];
              if (ts is! Timestamp) return null;
              return DateFormat('M/d/yyyy EEEE').format(ts.toDate());
            }

            return StandardViewGroup.paginated(
              query: query,
              pageSize: 100,
              physics: const ClampingScrollPhysics(),
              emptyBuilder: (_) => const Center(
                  child: Text('No performance observations found.')),
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
                final perfRefValue = data['performanceObservationId'];

                Widget buildTile(String name) {
                  return StandardTileSmallDart.iconText(
                    leadingicon: Icons.warning_amber,
                    leadingiconColor: Colors.red,
                    text: name,
                  );
                }

                final fallbackName =
                    (data['title'] as String?) ?? 'Dependability Observation';

                if (perfRefValue is! DocumentReference) {
                  return buildTile(fallbackName);
                }

                final DocumentReference perfRef =
                    perfRefValue;

                return FutureBuilder<DocumentSnapshot>(
                  future: _cachedPerfObservation(perfRef),
                  builder: (context, snap) {
                    var name = fallbackName;
                    if (snap.connectionState == ConnectionState.waiting) {
                      name = 'Loading...';
                    } else if (snap.hasError) {
                      name = 'Error';
                    } else if (snap.hasData && snap.data!.exists) {
                      final perfData =
                          snap.data!.data() as Map<String, dynamic>?;
                      name = perfData?['name'] as String? ?? name;
                    }
                    return buildTile(name);
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
