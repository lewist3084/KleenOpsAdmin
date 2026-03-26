// lib/services/employee_repository.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class EmployeeRepository {
  final FirebaseFirestore _firestore;

  EmployeeRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Fetch team names mapped by teamId
  Future<Map<String, String>> getTeamNames(String companyId) async {
    QuerySnapshot teamSnapshot = await _firestore
        .collection('company')
        .doc(companyId)
        .collection('team')
        .get();

    Map<String, String> teamMap = {};
    for (var doc in teamSnapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      teamMap[doc.id] = data['team'] ?? 'No Team';
    }
    return teamMap;
  }

  /// Fetch role names mapped by roleId
  Future<Map<String, String>> getRoleNames(String companyId) async {
    QuerySnapshot roleSnapshot = await _firestore
        .collection('company')
        .doc(companyId)
        .collection('role')
        .get();

    Map<String, String> roleMap = {};
    for (var doc in roleSnapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      roleMap[doc.id] = data['role'] ?? 'No Role';
    }
    return roleMap;
  }
}
