// lib/features/occupancy/providers/agent_task_run_provider.dart
//
// Admin port: talks directly to the top-level `agentTaskRuns` collection
// (no AgentTaskRepository in admin). Streams pending/active runs for the
// signed-in user.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kleenops_admin/features/auth/providers/auth_provider.dart';
import 'package:kleenops_admin/features/occupancy/models/agent_task_run.dart';

CollectionReference<Map<String, dynamic>> _runsCollection() =>
    FirebaseFirestore.instance.collection('agentTaskRuns');

/// Streams ready-for-review, not-yet-acknowledged agent task runs owned
/// by the signed-in user. Empty when there are none, including before
/// auth resolves.
final pendingAgentTaskRunsProvider =
    StreamProvider.autoDispose<List<AgentTaskRun>>((ref) {
  final user = ref.watch(authStateChangesProvider).value;
  if (user == null) return Stream.value(const <AgentTaskRun>[]);

  return _runsCollection()
      .where('ownerUid', isEqualTo: user.uid)
      .where('status', isEqualTo: 'ready_for_review')
      .snapshots()
      .map((snap) {
    final runs = snap.docs
        .map(AgentTaskRun.fromSnapshot)
        .where((r) => r.acknowledgedAt == null)
        .toList();
    runs.sort((a, b) {
      final aTime = a.completedAt ?? a.startedAt;
      final bTime = b.completedAt ?? b.startedAt;
      if (aTime == null && bTime == null) return 0;
      if (aTime == null) return 1;
      if (bTime == null) return -1;
      return bTime.compareTo(aTime);
    });
    return runs;
  });
});

/// True when there is at least one pending run waiting for review. The
/// AI button uses this to enable its attention animation.
final hasPendingAgentTaskRunsProvider = Provider.autoDispose<bool>((ref) {
  return ref.watch(pendingAgentTaskRunsProvider).maybeWhen(
        data: (runs) => runs.isNotEmpty,
        orElse: () => false,
      );
});

/// Streams the signed-in user's most recent agent task runs across every
/// status — running, ready, failed.
final activeAgentTaskRunsProvider =
    StreamProvider.autoDispose<List<AgentTaskRun>>((ref) {
  final user = ref.watch(authStateChangesProvider).value;
  if (user == null) return Stream.value(const <AgentTaskRun>[]);

  return _runsCollection()
      .where('ownerUid', isEqualTo: user.uid)
      .orderBy('startedAt', descending: true)
      .limit(25)
      .snapshots()
      .map((snap) =>
          snap.docs.map(AgentTaskRun.fromSnapshot).toList(growable: false));
});

/// True while at least one agent task is actively running.
final hasActiveAgentTaskRunsProvider = Provider.autoDispose<bool>((ref) {
  return ref.watch(activeAgentTaskRunsProvider).maybeWhen(
        data: (runs) =>
            runs.any((r) => r.status == AgentTaskRunStatus.running),
        orElse: () => false,
      );
});

/// The AI button pulses when an agent task needs attention — either it is
/// running right now, or it has finished and is waiting to be reviewed.
final agentTaskAttentionProvider = Provider.autoDispose<bool>((ref) {
  return ref.watch(hasPendingAgentTaskRunsProvider) ||
      ref.watch(hasActiveAgentTaskRunsProvider);
});
