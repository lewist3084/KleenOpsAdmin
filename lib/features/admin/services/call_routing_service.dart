import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

/// Service for managing call routing: extensions, ring groups, and availability.
class CallRoutingService {
  CallRoutingService._();
  static final instance = CallRoutingService._();

  final _functions = FirebaseFunctions.instance;

  // ── Extensions ────────────────────────────────────────────

  Future<Map<String, dynamic>> manageExtension({
    required String companyId,
    String? targetUid,
    String? extension,
    String? displayName,
  }) async {
    final callable = _functions.httpsCallable('callManageExtension');
    final result = await callable.call<Map<String, dynamic>>({
      'companyId': companyId,
      if (targetUid != null) 'targetUid': targetUid,
      if (extension != null) 'extension': extension,
      if (displayName != null) 'displayName': displayName,
    });
    return Map<String, dynamic>.from(result.data);
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchExtensions(
    DocumentReference<Map<String, dynamic>> companyRef,
  ) {
    return companyRef
        .collection('phoneExtension')
        .orderBy('extension')
        .snapshots();
  }

  // ── Ring Groups ───────────────────────────────────────────

  Future<Map<String, dynamic>> manageRingGroup({
    required String companyId,
    String? groupId,
    required String name,
    required String extension,
    List<String>? memberUids,
    String ringStrategy = 'simultaneous',
  }) async {
    final callable = _functions.httpsCallable('callManageRingGroup');
    final result = await callable.call<Map<String, dynamic>>({
      'companyId': companyId,
      if (groupId != null) 'groupId': groupId,
      'name': name,
      'extension': extension,
      'memberUids': memberUids ?? [],
      'ringStrategy': ringStrategy,
    });
    return Map<String, dynamic>.from(result.data);
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchRingGroups(
    DocumentReference<Map<String, dynamic>> companyRef,
  ) {
    return companyRef
        .collection('ringGroup')
        .orderBy('extension')
        .snapshots();
  }

  Future<void> deleteRingGroup(
    DocumentReference<Map<String, dynamic>> companyRef,
    String groupId,
  ) {
    return companyRef.collection('ringGroup').doc(groupId).delete();
  }

  // ── Auto-Attendant Toggle ─────────────────────────────────

  Future<void> configureForwarding({
    required String companyId,
    required String phoneDocId,
    String? forwardTo,
    bool autoAttendant = false,
  }) async {
    final callable = _functions.httpsCallable('phoneConfigureForwarding');
    await callable.call({
      'companyId': companyId,
      'phoneDocId': phoneDocId,
      'forwardTo': forwardTo,
      'autoAttendant': autoAttendant,
    });
  }

  // ── Members (for ring group assignment) ───────────────────

  Stream<QuerySnapshot<Map<String, dynamic>>> watchMembers(
    DocumentReference<Map<String, dynamic>> companyRef,
  ) {
    return companyRef
        .collection('memberByUid')
        .where('active', isEqualTo: true)
        .snapshots();
  }
}
