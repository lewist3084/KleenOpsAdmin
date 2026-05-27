// lib/features/occupancy/services/agent_task_trigger_service.dart
//
// Thin wrapper around the `triggerAgentTask` HTTPS callable. The Cloud
// Run runner exposes this so the management UI can fire a task on
// demand ("Run now" button on the form), independent of the weekly
// schedule. Returns the `runId` of the freshly-created
// `agentTaskRuns/{runId}` doc so the caller can deep-link or just rely
// on the auto-surfacer to pick it up the next time the canvas opens.

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AgentTaskTriggerService {
  AgentTaskTriggerService({FirebaseFunctions? functions})
      : _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseFunctions _functions;

  /// Fire the task identified by [taskId] under [companyId]. Returns
  /// the run id when the runner has accepted the request — this does
  /// NOT mean the run has finished, only that it's been queued.
  ///
  /// Throws [AgentTaskTriggerException] on failure with a user-readable
  /// message; callers should surface it via snackbar/dialog.
  Future<String> runNow({
    required String companyId,
    required String taskId,
  }) async {
    try {
      final result = await _functions
          .httpsCallable('triggerAgentTask')
          .call(<String, dynamic>{
        'companyId': companyId,
        'taskId': taskId,
      });
      final data = result.data;
      if (data is Map) {
        final runId = data['runId'];
        if (runId is String && runId.isNotEmpty) return runId;
      }
      throw const AgentTaskTriggerException(
        'Runner accepted the request but did not return a run id.',
      );
    } on FirebaseFunctionsException catch (e) {
      throw AgentTaskTriggerException(
        e.message ?? 'Cloud function error: ${e.code}',
      );
    } catch (e) {
      throw AgentTaskTriggerException('Unexpected error: $e');
    }
  }
}

class AgentTaskTriggerException implements Exception {
  const AgentTaskTriggerException(this.message);
  final String message;
  @override
  String toString() => 'AgentTaskTriggerException: $message';
}

final agentTaskTriggerServiceProvider =
    Provider<AgentTaskTriggerService>((ref) {
  return AgentTaskTriggerService();
});
