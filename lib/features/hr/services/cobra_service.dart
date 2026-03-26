// lib/features/hr/services/cobra_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';

/// Manages COBRA (Consolidated Omnibus Budget Reconciliation Act)
/// continuation coverage tracking.
///
/// COBRA applies to employers with 20+ employees and requires
/// offering continued health coverage to employees who lose
/// benefits due to qualifying events (termination, hours reduction, etc.).
///
/// Firestore: company/{id}/cobraEvent/{eventId}
class CobraService {
  /// Creates a COBRA qualifying event for an employee.
  ///
  /// The employer has 30 days to notify the plan administrator,
  /// then the employee has 60 days to elect COBRA coverage.
  Future<String> createCobraEvent({
    required DocumentReference<Map<String, dynamic>> companyRef,
    required String memberId,
    required String memberName,
    required String qualifyingEvent,
    required DateTime eventDate,
    required List<String> coveredPlanIds,
  }) async {
    final notificationDeadline = eventDate.add(const Duration(days: 30));
    final electionDeadline =
        notificationDeadline.add(const Duration(days: 60));

    final ref = FirebaseFirestore.instance.collection('cobraEvent').doc();
    await ref.set({
      'memberId': memberId,
      'memberName': memberName,
      'qualifyingEvent': qualifyingEvent,
      'eventDate': Timestamp.fromDate(eventDate),
      'notificationDeadline': Timestamp.fromDate(notificationDeadline),
      'electionDeadline': Timestamp.fromDate(electionDeadline),
      'coveredPlanIds': coveredPlanIds,
      'status': 'pending_notification',
      // Status flow: pending_notification → notified → elected/declined → active/expired
      'notifiedAt': null,
      'electedAt': null,
      'coverageEndDate': null,
      'monthlyPremium': null,
      'notes': '',
      'createdAt': FieldValue.serverTimestamp(),
    });

    return ref.id;
  }

  /// Records that the COBRA notice was sent to the employee.
  Future<void> markNotified({
    required DocumentReference<Map<String, dynamic>> companyRef,
    required String eventId,
  }) async {
    await FirebaseFirestore.instance.collection('cobraEvent').doc(eventId).update({
      'status': 'notified',
      'notifiedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Records the employee's COBRA election.
  Future<void> recordElection({
    required DocumentReference<Map<String, dynamic>> companyRef,
    required String eventId,
    required bool elected,
    double? monthlyPremium,
    DateTime? coverageEndDate,
  }) async {
    final data = <String, dynamic>{
      'status': elected ? 'active' : 'declined',
      'electedAt': FieldValue.serverTimestamp(),
    };

    if (elected) {
      if (monthlyPremium != null) data['monthlyPremium'] = monthlyPremium;
      // COBRA coverage can last up to 18 months (36 for certain events)
      final endDate =
          coverageEndDate ?? DateTime.now().add(const Duration(days: 548));
      data['coverageEndDate'] = Timestamp.fromDate(endDate);
    }

    await FirebaseFirestore.instance.collection('cobraEvent').doc(eventId).update(data);
  }

  /// Terminates active COBRA coverage.
  Future<void> terminateCoverage({
    required DocumentReference<Map<String, dynamic>> companyRef,
    required String eventId,
    required String reason,
  }) async {
    await FirebaseFirestore.instance.collection('cobraEvent').doc(eventId).update({
      'status': 'terminated',
      'terminatedAt': FieldValue.serverTimestamp(),
      'terminationReason': reason,
    });
  }

  /// Stream of all COBRA events for a company.
  Stream<QuerySnapshot<Map<String, dynamic>>> watchEvents({
    required DocumentReference<Map<String, dynamic>> companyRef,
  }) {
    return FirebaseFirestore.instance
        .collection('cobraEvent')
        .orderBy('eventDate', descending: true)
        .snapshots();
  }

  /// Stream of active COBRA events (needing attention).
  Stream<QuerySnapshot<Map<String, dynamic>>> watchActiveEvents({
    required DocumentReference<Map<String, dynamic>> companyRef,
  }) {
    return FirebaseFirestore.instance
        .collection('cobraEvent')
        .where('status', whereIn: [
          'pending_notification',
          'notified',
          'active',
        ])
        .orderBy('eventDate', descending: true)
        .snapshots();
  }

  /// Gets COBRA events for a specific employee.
  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
      getEventsForMember({
    required DocumentReference<Map<String, dynamic>> companyRef,
    required String memberId,
  }) async {
    final snap = await FirebaseFirestore.instance
        .collection('cobraEvent')
        .where('memberId', isEqualTo: memberId)
        .orderBy('eventDate', descending: true)
        .get();
    return snap.docs;
  }

  /// Qualifying events for COBRA.
  static const qualifyingEvents = [
    'voluntary_termination',
    'involuntary_termination',
    'hours_reduction',
    'divorce',
    'death_of_employee',
    'medicare_entitlement',
    'dependent_aging_out',
  ];

  /// Human-readable labels for qualifying events.
  static String eventLabel(String event) {
    switch (event) {
      case 'voluntary_termination':
        return 'Voluntary Termination';
      case 'involuntary_termination':
        return 'Involuntary Termination (not gross misconduct)';
      case 'hours_reduction':
        return 'Reduction in Work Hours';
      case 'divorce':
        return 'Divorce or Legal Separation';
      case 'death_of_employee':
        return 'Death of Covered Employee';
      case 'medicare_entitlement':
        return 'Employee Becomes Entitled to Medicare';
      case 'dependent_aging_out':
        return 'Dependent Child Aging Out of Coverage';
      default:
        return event;
    }
  }

  /// COBRA coverage duration by qualifying event.
  static int coverageMonths(String event) {
    switch (event) {
      case 'divorce':
      case 'death_of_employee':
      case 'medicare_entitlement':
      case 'dependent_aging_out':
        return 36; // 36 months for these events
      default:
        return 18; // 18 months for termination/hours reduction
    }
  }
}
