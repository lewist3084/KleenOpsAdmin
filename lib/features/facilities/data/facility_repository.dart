// Admin port of the facilities data layer.
//
// kleenops scopes everything under `company/{id}/...` via `companyDoc(id)`.
// Admin reads from TOP-LEVEL collections (property, building, floor,
// location, locationFunction, objectInventory, gateway, propertyType).
//
// To keep the kleenops API shape identical and minimize call-site churn,
// this repository accepts (but ignores) the `companyId` argument and
// returns top-level collection refs.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class FacilityRepository {
  FacilityRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  // ─────────────── Company ───────────────
  // Admin: still expose the company doc (top-level `company` collection
  // exists in admin) so call sites that need it for cross-cutting reads
  // keep working.
  DocumentReference<Map<String, dynamic>> companyDoc(String companyId) =>
      _firestore.collection('company').doc(companyId);

  // ─────────────── Property ───────────────

  CollectionReference<Map<String, dynamic>> propertyCollection(
          [String? companyId]) =>
      _firestore.collection('property');

  DocumentReference<Map<String, dynamic>> propertyDoc(
          dynamic companyIdOrUnused, String propertyId) =>
      propertyCollection().doc(propertyId);

  Query<Map<String, dynamic>> watchProperties(
    String? companyId, {
    bool active = true,
  }) =>
      propertyCollection()
          .where('active', isEqualTo: active)
          .orderBy('name');

  // ─────────────── Building ───────────────

  CollectionReference<Map<String, dynamic>> buildingCollection(
          [String? companyId]) =>
      _firestore.collection('building');

  DocumentReference<Map<String, dynamic>> buildingDoc(
          dynamic companyIdOrUnused, String buildingId) =>
      buildingCollection().doc(buildingId);

  // ─────────────── Floor ───────────────

  CollectionReference<Map<String, dynamic>> floorCollection(
          [String? companyId]) =>
      _firestore.collection('floor');

  DocumentReference<Map<String, dynamic>> floorDoc(
          dynamic companyIdOrUnused, String floorId) =>
      floorCollection().doc(floorId);

  // ─────────────── Location (rooms) ───────────────

  CollectionReference<Map<String, dynamic>> locationCollection(
          [String? companyId]) =>
      _firestore.collection('location');

  DocumentReference<Map<String, dynamic>> locationDoc(
          dynamic companyIdOrUnused, String locationId) =>
      locationCollection().doc(locationId);

  DocumentReference<Map<String, dynamic>> newLocationDoc(
          [String? companyId]) =>
      locationCollection().doc();

  // ─────────────── Location functions ───────────────

  CollectionReference<Map<String, dynamic>> locationFunctionCollection(
          [String? companyId]) =>
      _firestore.collection('locationFunction');

  CollectionReference<Map<String, dynamic>> locationReservationCollection(
          [String? companyId]) =>
      _firestore.collection('locationReservation');

  DocumentReference<Map<String, dynamic>> locationFunctionDoc(
          dynamic companyIdOrUnused, String functionId) =>
      locationFunctionCollection().doc(functionId);

  // ─────────────── Object inventory ───────────────

  CollectionReference<Map<String, dynamic>> objectInventoryCollection(
          [String? companyId]) =>
      _firestore.collection('objectInventory');

  Query<Map<String, dynamic>> objectInventoryGroup() =>
      _firestore.collectionGroup('objectInventory');

  // ─────────────── IoT gateways ───────────────

  CollectionReference<Map<String, dynamic>> gatewayCollection(
          [String? companyId]) =>
      _firestore.collection('gateway');

  // ─────────────── Shared property types ───────────────

  CollectionReference<Map<String, dynamic>> propertyTypeCollection() =>
      _firestore.collection('propertyType');

  DocumentReference<Map<String, dynamic>> propertyTypeDoc(String typeId) =>
      propertyTypeCollection().doc(typeId);

  // ─────────────── Write & utility helpers ───────────────

  WriteBatch batch() => _firestore.batch();

  String newId() => _firestore.collection('_ids').doc().id;

  DocumentReference<Map<String, dynamic>> docFromPath(String path) =>
      _firestore.doc(path).withConverter<Map<String, dynamic>>(
            fromFirestore: (snap, _) => snap.data() ?? <String, dynamic>{},
            toFirestore: (value, _) => value,
          );

  // ─────────────── Responsible team resolution ───────────────

  Future<({String? teamId, String fromLabel})> resolveInheritedTeam({
    required Map<String, dynamic> startData,
    required HierarchyLevel startLevel,
  }) async {
    DocumentReference<Map<String, dynamic>>? parentRef;
    String parentLevelName;

    switch (startLevel) {
      case HierarchyLevel.location:
        parentRef =
            startData['floorId'] as DocumentReference<Map<String, dynamic>>?;
        parentLevelName = 'Floor';
        break;
      case HierarchyLevel.floor:
        parentRef = startData['buildingId']
            as DocumentReference<Map<String, dynamic>>?;
        parentLevelName = 'Building';
        break;
      case HierarchyLevel.building:
        parentRef = startData['propertyId']
            as DocumentReference<Map<String, dynamic>>?;
        parentLevelName = 'Property';
        break;
      case HierarchyLevel.property:
        return (teamId: null, fromLabel: '');
    }

    while (parentRef != null) {
      final snap = await parentRef.get();
      if (!snap.exists) return (teamId: null, fromLabel: '');
      final data = snap.data() ?? const <String, dynamic>{};
      final id = (data['responsibleTeamId'] as String?)?.trim();
      if (id != null && id.isNotEmpty) {
        final label = (data['name'] as String?)?.trim();
        return (
          teamId: id,
          fromLabel: (label == null || label.isEmpty) ? parentLevelName : label,
        );
      }
      if (parentLevelName == 'Floor') {
        parentRef =
            data['buildingId'] as DocumentReference<Map<String, dynamic>>?;
        parentLevelName = 'Building';
      } else if (parentLevelName == 'Building') {
        parentRef =
            data['propertyId'] as DocumentReference<Map<String, dynamic>>?;
        parentLevelName = 'Property';
      } else {
        parentRef = null;
      }
    }
    return (teamId: null, fromLabel: '');
  }
}

/// Identifies which level of the property hierarchy a doc lives at.
enum HierarchyLevel { property, building, floor, location }

final facilityRepositoryProvider = Provider<FacilityRepository>((ref) {
  return FacilityRepository();
});
