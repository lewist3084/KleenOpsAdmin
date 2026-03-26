// lib/features/hr/services/open_enrollment_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';

/// Manages open enrollment periods for benefits.
///
/// Firestore: company/{id}/openEnrollment/{periodId}
///
/// Open enrollment restricts when employees can enroll/change benefits
/// outside of qualifying life events (marriage, birth, etc.).
class OpenEnrollmentService {
  /// Creates a new open enrollment period.
  Future<String> createPeriod({
    required DocumentReference<Map<String, dynamic>> companyRef,
    required String name,
    required DateTime startDate,
    required DateTime endDate,
    required int effectiveYear,
    String? notes,
  }) async {
    final ref = FirebaseFirestore.instance.collection('openEnrollment').doc();
    await ref.set({
      'name': name,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'effectiveYear': effectiveYear,
      'status': 'upcoming', // upcoming, active, closed
      'notes': notes ?? '',
      'createdAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  /// Checks if there is an active open enrollment period right now.
  Future<Map<String, dynamic>?> getActivePeriod({
    required DocumentReference<Map<String, dynamic>> companyRef,
  }) async {
    final now = Timestamp.now();
    final snap = await FirebaseFirestore.instance
        .collection('openEnrollment')
        .where('startDate', isLessThanOrEqualTo: now)
        .orderBy('startDate', descending: true)
        .limit(1)
        .get();

    if (snap.docs.isEmpty) return null;
    final data = snap.docs.first.data();
    final endDate = data['endDate'] as Timestamp?;
    if (endDate != null && endDate.toDate().isBefore(DateTime.now())) {
      return null; // Period ended
    }
    return {'id': snap.docs.first.id, ...data};
  }

  /// Checks if an employee can enroll in benefits right now.
  ///
  /// Returns true if:
  ///   1. There is an active open enrollment period, OR
  ///   2. The employee has a qualifying life event within 30 days, OR
  ///   3. The employee is within their new-hire enrollment window
  Future<({bool canEnroll, String reason})> checkEnrollmentEligibility({
    required DocumentReference<Map<String, dynamic>> companyRef,
    required Map<String, dynamic> memberData,
  }) async {
    // Check open enrollment
    final activePeriod = await getActivePeriod(companyRef: companyRef);
    if (activePeriod != null) {
      return (
        canEnroll: true,
        reason: 'Open enrollment: ${activePeriod['name']}',
      );
    }

    // Check new-hire window (typically 30-60 days from start date)
    final startDate = memberData['startDate'];
    if (startDate is Timestamp) {
      final hireDate = startDate.toDate();
      final daysSinceHire = DateTime.now().difference(hireDate).inDays;
      if (daysSinceHire <= 60) {
        return (
          canEnroll: true,
          reason: 'New hire enrollment window (within 60 days of hire)',
        );
      }
    }

    // Check qualifying life events
    final lifeEvents =
        memberData['qualifyingLifeEvents'] as List<dynamic>? ?? [];
    for (final event in lifeEvents) {
      if (event is! Map) continue;
      final eventDate = event['date'];
      if (eventDate is Timestamp) {
        final daysSinceEvent =
            DateTime.now().difference(eventDate.toDate()).inDays;
        if (daysSinceEvent <= 30) {
          return (
            canEnroll: true,
            reason:
                'Qualifying life event: ${event['type'] ?? 'life event'} (within 30 days)',
          );
        }
      }
    }

    return (
      canEnroll: false,
      reason:
          'No active open enrollment period. Enrollment is available during open enrollment, '
          'within 60 days of hire, or within 30 days of a qualifying life event.',
    );
  }

  /// Stream of all enrollment periods for a company.
  Stream<QuerySnapshot<Map<String, dynamic>>> watchPeriods({
    required DocumentReference<Map<String, dynamic>> companyRef,
  }) {
    return FirebaseFirestore.instance
        .collection('openEnrollment')
        .orderBy('startDate', descending: true)
        .snapshots();
  }

  /// Updates an enrollment period status.
  Future<void> updateStatus({
    required DocumentReference<Map<String, dynamic>> companyRef,
    required String periodId,
    required String status,
  }) async {
    await FirebaseFirestore.instance.collection('openEnrollment').doc(periodId).update({
      'status': status,
    });
  }

  /// Qualifying life event types.
  static const qualifyingLifeEventTypes = [
    'marriage',
    'divorce',
    'birth_adoption',
    'death_of_dependent',
    'loss_of_coverage',
    'relocation',
    'change_in_employment',
  ];

  /// Human-readable labels for life event types.
  static String lifeEventLabel(String type) {
    switch (type) {
      case 'marriage':
        return 'Marriage';
      case 'divorce':
        return 'Divorce / Legal Separation';
      case 'birth_adoption':
        return 'Birth or Adoption of a Child';
      case 'death_of_dependent':
        return 'Death of a Dependent';
      case 'loss_of_coverage':
        return 'Loss of Other Coverage';
      case 'relocation':
        return 'Relocation to New Coverage Area';
      case 'change_in_employment':
        return "Change in Spouse's Employment";
      default:
        return type;
    }
  }
}
