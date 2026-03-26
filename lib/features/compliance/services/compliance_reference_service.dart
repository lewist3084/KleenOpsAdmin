// lib/features/compliance/services/compliance_reference_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';

/// Reads top-level compliance reference data shared across all companies.
///
/// Collections:
///   federalRule/{year}          — federal tax rates, FICA, FMLA, OSHA, etc.
///   stateRule/{stateCode}       — per-state employment, tax, licensing rules
///   insuranceRequirement/{type} — required insurance types for cleaning businesses
///   businessFormation/{type}    — entity type guidance (LLC, Corp, etc.)
class ComplianceReferenceService {
  final _db = FirebaseFirestore.instance;

  // ─── Federal ───

  /// Returns the federal rule document for the given [year], or the current year.
  Future<Map<String, dynamic>?> getFederalRule({int? year}) async {
    final effectiveYear = year ?? DateTime.now().year;
    final snap =
        await _db.collection('federalRule').doc('$effectiveYear').get();
    return snap.exists ? snap.data() : null;
  }

  /// Stream of the current year's federal rule.
  Stream<DocumentSnapshot<Map<String, dynamic>>> watchFederalRule({int? year}) {
    final effectiveYear = year ?? DateTime.now().year;
    return _db.collection('federalRule').doc('$effectiveYear').snapshots();
  }

  // ─── State ───

  /// Returns the state rule document for a specific state code (e.g., 'AZ').
  Future<Map<String, dynamic>?> getStateRule(String stateCode) async {
    final snap =
        await _db.collection('stateRule').doc(stateCode.toUpperCase()).get();
    return snap.exists ? snap.data() : null;
  }

  /// Stream of a single state rule.
  Stream<DocumentSnapshot<Map<String, dynamic>>> watchStateRule(
      String stateCode) {
    return _db
        .collection('stateRule')
        .doc(stateCode.toUpperCase())
        .snapshots();
  }

  /// Returns all state rules ordered by stateName.
  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
      getAllStateRules() async {
    final snap =
        await _db.collection('stateRule').orderBy('stateName').get();
    return snap.docs;
  }

  /// Stream of all state rules ordered by stateName.
  Stream<QuerySnapshot<Map<String, dynamic>>> watchAllStateRules() {
    return _db.collection('stateRule').orderBy('stateName').snapshots();
  }

  // ─── Insurance Requirements ───

  /// Returns all insurance requirement docs (general liability, workers comp, etc.).
  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
      getInsuranceRequirements() async {
    final snap = await _db
        .collection('insuranceRequirement')
        .orderBy('position')
        .get();
    return snap.docs;
  }

  /// Stream of insurance requirements.
  Stream<QuerySnapshot<Map<String, dynamic>>> watchInsuranceRequirements() {
    return _db
        .collection('insuranceRequirement')
        .orderBy('position')
        .snapshots();
  }

  // ─── Business Formation ───

  /// Returns all business formation guidance docs (LLC, Corp, etc.).
  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
      getBusinessFormations() async {
    final snap = await _db
        .collection('businessFormation')
        .orderBy('position')
        .get();
    return snap.docs;
  }

  /// Returns a single business formation doc by entity type.
  Future<Map<String, dynamic>?> getBusinessFormation(String entityType) async {
    final snap =
        await _db.collection('businessFormation').doc(entityType).get();
    return snap.exists ? snap.data() : null;
  }

  /// Stream of business formation docs.
  Stream<QuerySnapshot<Map<String, dynamic>>> watchBusinessFormations() {
    return _db
        .collection('businessFormation')
        .orderBy('position')
        .snapshots();
  }

  // ─── US States List ───

  /// Full list of US states and territories with codes.
  static const List<({String code, String name})> usStates = [
    (code: 'AL', name: 'Alabama'),
    (code: 'AK', name: 'Alaska'),
    (code: 'AZ', name: 'Arizona'),
    (code: 'AR', name: 'Arkansas'),
    (code: 'CA', name: 'California'),
    (code: 'CO', name: 'Colorado'),
    (code: 'CT', name: 'Connecticut'),
    (code: 'DE', name: 'Delaware'),
    (code: 'DC', name: 'District of Columbia'),
    (code: 'FL', name: 'Florida'),
    (code: 'GA', name: 'Georgia'),
    (code: 'HI', name: 'Hawaii'),
    (code: 'ID', name: 'Idaho'),
    (code: 'IL', name: 'Illinois'),
    (code: 'IN', name: 'Indiana'),
    (code: 'IA', name: 'Iowa'),
    (code: 'KS', name: 'Kansas'),
    (code: 'KY', name: 'Kentucky'),
    (code: 'LA', name: 'Louisiana'),
    (code: 'ME', name: 'Maine'),
    (code: 'MD', name: 'Maryland'),
    (code: 'MA', name: 'Massachusetts'),
    (code: 'MI', name: 'Michigan'),
    (code: 'MN', name: 'Minnesota'),
    (code: 'MS', name: 'Mississippi'),
    (code: 'MO', name: 'Missouri'),
    (code: 'MT', name: 'Montana'),
    (code: 'NE', name: 'Nebraska'),
    (code: 'NV', name: 'Nevada'),
    (code: 'NH', name: 'New Hampshire'),
    (code: 'NJ', name: 'New Jersey'),
    (code: 'NM', name: 'New Mexico'),
    (code: 'NY', name: 'New York'),
    (code: 'NC', name: 'North Carolina'),
    (code: 'ND', name: 'North Dakota'),
    (code: 'OH', name: 'Ohio'),
    (code: 'OK', name: 'Oklahoma'),
    (code: 'OR', name: 'Oregon'),
    (code: 'PA', name: 'Pennsylvania'),
    (code: 'RI', name: 'Rhode Island'),
    (code: 'SC', name: 'South Carolina'),
    (code: 'SD', name: 'South Dakota'),
    (code: 'TN', name: 'Tennessee'),
    (code: 'TX', name: 'Texas'),
    (code: 'UT', name: 'Utah'),
    (code: 'VT', name: 'Vermont'),
    (code: 'VA', name: 'Virginia'),
    (code: 'WA', name: 'Washington'),
    (code: 'WV', name: 'West Virginia'),
    (code: 'WI', name: 'Wisconsin'),
    (code: 'WY', name: 'Wyoming'),
  ];

  /// Lookup state name from code.
  static String stateNameFromCode(String code) {
    final match = usStates.where((s) => s.code == code.toUpperCase());
    return match.isNotEmpty ? match.first.name : code;
  }
}
