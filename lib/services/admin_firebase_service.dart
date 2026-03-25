// lib/services/admin_firebase_service.dart
//
// Cross-company Firestore access for the platform admin.
// Queries across all companies rather than scoping to one.

import 'package:cloud_firestore/cloud_firestore.dart';

import '../constants/firestore_paths.dart';

class AdminFirebaseService {
  AdminFirebaseService._();
  static final instance = AdminFirebaseService._();

  FirebaseFirestore get _fs => FirebaseFirestore.instance;

  // ── Company queries ──────────────────────────────────────────────────

  /// Stream of all company documents.
  Stream<QuerySnapshot<Map<String, dynamic>>> allCompanies() {
    return _fs.collection(colCompany).orderBy('name').snapshots();
  }

  /// Single company document.
  DocumentReference<Map<String, dynamic>> companyRef(String companyId) {
    return _fs.collection(colCompany).doc(companyId);
  }

  /// Stream a single company document.
  Stream<DocumentSnapshot<Map<String, dynamic>>> companyStream(
      String companyId) {
    return companyRef(companyId).snapshots();
  }

  // ── Member queries ───────────────────────────────────────────────────

  /// All members for a given company.
  Stream<QuerySnapshot<Map<String, dynamic>>> membersFor(String companyId) {
    return _fs
        .collection(colCompany)
        .doc(companyId)
        .collection(colMember)
        .orderBy('name')
        .snapshots();
  }

  /// Count of active members for a company.
  Future<int> activeMemberCount(String companyId) async {
    final snap = await _fs
        .collection(colCompany)
        .doc(companyId)
        .collection(colMember)
        .where('active', isEqualTo: true)
        .count()
        .get();
    return snap.count ?? 0;
  }

  // ── Cross-company aggregations ───────────────────────────────────────

  /// All users in the platform.
  Stream<QuerySnapshot<Map<String, dynamic>>> allUsers() {
    return _fs.collection(colUser).snapshots();
  }

  /// Timeline events for a company (useful for activity feeds).
  Stream<QuerySnapshot<Map<String, dynamic>>> timelineFor(
    String companyId, {
    int limit = 50,
  }) {
    return _fs
        .collection(colCompany)
        .doc(companyId)
        .collection(colTimeline)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots();
  }

  /// Bank accounts for a company.
  Stream<QuerySnapshot<Map<String, dynamic>>> bankAccountsFor(
      String companyId) {
    return _fs
        .collection(colCompany)
        .doc(companyId)
        .collection(colBankAccount)
        .snapshots();
  }

  // ── Generic sub-collection helper ────────────────────────────────────

  /// Stream any sub-collection under a company.
  Stream<QuerySnapshot<Map<String, dynamic>>> companySubcollection(
    String companyId,
    String subcollection, {
    int? limit,
  }) {
    Query<Map<String, dynamic>> query = _fs
        .collection(colCompany)
        .doc(companyId)
        .collection(subcollection);
    if (limit != null) query = query.limit(limit);
    return query.snapshots();
  }
}
