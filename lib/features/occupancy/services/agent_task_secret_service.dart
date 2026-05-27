// lib/features/occupancy/services/agent_task_secret_service.dart
//
// Thin wrapper around the `setAgentTaskSecret` HTTPS callable. The form
// calls this when the user submits a password for an external data
// source. The password is sent in the callable payload (encrypted in
// transit by Firebase) and stored in Google Secret Manager. The
// returned `secretRef` is what gets persisted on the agent task doc.

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AgentTaskSecretService {
  AgentTaskSecretService({FirebaseFunctions? functions})
      : _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseFunctions _functions;

  /// Stores [password] in Secret Manager keyed to the given task. The
  /// returned string is the Secret Manager resource name (versions/latest)
  /// that should be saved on `dataSource.secretRef`. The plaintext is
  /// never returned to the client and never lands in Firestore.
  Future<String> storePassword({
    required String companyId,
    required String taskId,
    required String password,
  }) async {
    try {
      final result = await _functions
          .httpsCallable('setAgentTaskSecret')
          .call(<String, dynamic>{
        'companyId': companyId,
        'taskId': taskId,
        'password': password,
      });
      final data = result.data;
      if (data is Map) {
        final secretRef = data['secretRef'];
        if (secretRef is String && secretRef.isNotEmpty) return secretRef;
      }
      throw const AgentTaskSecretException(
        'Cloud function did not return a secretRef.',
      );
    } on FirebaseFunctionsException catch (e) {
      throw AgentTaskSecretException(
        e.message ?? 'Cloud function error: ${e.code}',
      );
    } catch (e) {
      throw AgentTaskSecretException('Unexpected error: $e');
    }
  }
}

class AgentTaskSecretException implements Exception {
  const AgentTaskSecretException(this.message);
  final String message;
  @override
  String toString() => 'AgentTaskSecretException: $message';
}

final agentTaskSecretServiceProvider =
    Provider<AgentTaskSecretService>((ref) {
  return AgentTaskSecretService();
});
