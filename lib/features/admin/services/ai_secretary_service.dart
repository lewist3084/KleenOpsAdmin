import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

/// Service for managing AI secretary configuration and viewing call logs.
///
/// Mirrors the Cloud Functions in aiSecretary.js.
class AiSecretaryService {
  AiSecretaryService._();
  static final instance = AiSecretaryService._();

  final _functions = FirebaseFunctions.instance;

  // ── Configuration ─────────────────────────────────────────

  /// Get the AI secretary configuration for a user.
  Future<Map<String, dynamic>> getConfig({
    required String companyId,
    String? targetUid,
  }) async {
    final callable = _functions.httpsCallable('aiSecretaryGetConfig');
    final result = await callable.call<Map<String, dynamic>>({
      'companyId': companyId,
      if (targetUid != null) 'targetUid': targetUid,
    });
    return Map<String, dynamic>.from(result.data);
  }

  /// Update the AI secretary configuration for a user.
  ///
  /// [mode] must be one of: 'screen', 'message', 'full'.
  /// [vipCallers] is a list of phone numbers to always forward immediately.
  Future<Map<String, dynamic>> updateConfig({
    required String companyId,
    String? targetUid,
    bool? enabled,
    String? greeting,
    String? instructions,
    List<String>? vipCallers,
    String? mode,
    int? maxTurns,
    String? voiceName,
  }) async {
    final callable = _functions.httpsCallable('aiSecretaryUpdateConfig');
    final result = await callable.call<Map<String, dynamic>>({
      'companyId': companyId,
      if (targetUid != null) 'targetUid': targetUid,
      if (enabled != null) 'enabled': enabled,
      if (greeting != null) 'greeting': greeting,
      if (instructions != null) 'instructions': instructions,
      if (vipCallers != null) 'vipCallers': vipCallers,
      if (mode != null) 'mode': mode,
      if (maxTurns != null) 'maxTurns': maxTurns,
      if (voiceName != null) 'voiceName': voiceName,
    });
    return Map<String, dynamic>.from(result.data);
  }

  // ── Call Logs ─────────────────────────────────────────────

  /// List recent AI secretary call logs.
  Future<List<Map<String, dynamic>>> listLogs({
    required String companyId,
    String? extensionUid,
    int limit = 25,
  }) async {
    final callable = _functions.httpsCallable('aiSecretaryListLogs');
    final result = await callable.call<Map<String, dynamic>>({
      'companyId': companyId,
      if (extensionUid != null) 'extensionUid': extensionUid,
      'limit': limit,
    });
    final data = Map<String, dynamic>.from(result.data);
    final logs = data['logs'] as List<dynamic>? ?? [];
    return logs.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  // ── Real-time Watchers ────────────────────────────────────

  /// Watch the AI secretary config for a specific user in real time.
  Stream<DocumentSnapshot<Map<String, dynamic>>> watchConfig(
    DocumentReference<Map<String, dynamic>> companyRef,
    String uid,
  ) {
    return companyRef.collection('aiSecretaryConfig').doc(uid).snapshots();
  }

  /// Watch the aiSecretaryEnabled flag on a user's extension doc.
  Stream<DocumentSnapshot<Map<String, dynamic>>> watchExtension(
    DocumentReference<Map<String, dynamic>> companyRef,
    String uid,
  ) {
    return companyRef.collection('phoneExtension').doc(uid).snapshots();
  }

  /// Watch recent AI secretary logs for a company in real time.
  Stream<QuerySnapshot<Map<String, dynamic>>> watchLogs(
    DocumentReference<Map<String, dynamic>> companyRef, {
    String? extensionUid,
    int limit = 25,
  }) {
    Query<Map<String, dynamic>> query = companyRef
        .collection('aiSecretaryLog')
        .orderBy('startedAt', descending: true)
        .limit(limit);

    if (extensionUid != null) {
      query = query.where('extensionUid', isEqualTo: extensionUid);
    }

    return query.snapshots();
  }
}
