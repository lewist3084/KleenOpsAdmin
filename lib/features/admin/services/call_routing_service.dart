import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

/// Service for managing call routing: extensions, ring groups, and availability.
///
/// Schema note: phoneExtension docs are keyed by the 3-digit extension
/// number (e.g. "100"), with `assignedUid` either null (unassigned pool slot)
/// or set to the member's uid.
class CallRoutingService {
  CallRoutingService._();
  static final instance = CallRoutingService._();

  final _functions = FirebaseFunctions.instance;

  // ── Extension pool ────────────────────────────────────────

  Future<Map<String, dynamic>> seedExtensions({
    required String companyId,
    int count = 10,
  }) async {
    final callable = _functions.httpsCallable('callSeedExtensions');
    final result = await callable.call<Map<String, dynamic>>({
      'companyId': companyId,
      'count': count,
    });
    return Map<String, dynamic>.from(result.data);
  }

  Future<Map<String, dynamic>> assignExtension({
    required String companyId,
    required String extension,
    required String targetUid,
    String? displayName,
    String? label,
  }) async {
    final callable = _functions.httpsCallable('callAssignExtension');
    final result = await callable.call<Map<String, dynamic>>({
      'companyId': companyId,
      'extension': extension,
      'targetUid': targetUid,
      if (displayName != null) 'displayName': displayName,
      if (label != null) 'label': label,
    });
    return Map<String, dynamic>.from(result.data);
  }

  Future<void> unassignExtension({
    required String companyId,
    required String extension,
  }) async {
    final callable = _functions.httpsCallable('callUnassignExtension');
    await callable.call({
      'companyId': companyId,
      'extension': extension,
    });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchExtensions(
    DocumentReference<Map<String, dynamic>> companyRef,
  ) {
    return companyRef
        .collection('phoneExtension')
        .orderBy(FieldPath.documentId)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchUnassigned(
    DocumentReference<Map<String, dynamic>> companyRef,
  ) {
    return companyRef
        .collection('phoneExtension')
        .where('assignedUid', isNull: true)
        .orderBy(FieldPath.documentId)
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
