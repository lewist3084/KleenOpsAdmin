// lib/features/admin/services/compliance_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';

/// Service for evaluating employee compliance against state and federal rules.
class ComplianceService {
  /// Checks if an employee's weekly hours exceed the benefits threshold
  /// for their work state.
  ///
  /// Returns `true` if the employee must be offered benefits.
  Future<bool> requiresBenefits({
    required DocumentReference<Map<String, dynamic>> companyRef,
    required double weeklyHours,
    required String workState,
  }) async {
    // Check state-level threshold first
    final stateSnap =
        await FirebaseFirestore.instance.collection('stateRule').doc(workState).get();
    if (stateSnap.exists) {
      final stateData = stateSnap.data();
      if (stateData != null) {
        final threshold =
            (stateData['benefitsThresholdHours'] as num?)?.toDouble() ?? 30;
        if (weeklyHours >= threshold) return true;
      }
    }

    // Fall back to federal ACA threshold
    final fedSnap =
        await FirebaseFirestore.instance.collection('federalRule').doc('current').get();
    if (fedSnap.exists) {
      final fedData = fedSnap.data();
      if (fedData != null) {
        final acaThreshold =
            (fedData['acaBenefitsThreshold'] as num?)?.toDouble() ?? 30;
        return weeklyHours >= acaThreshold;
      }
    }

    // Default ACA: 30 hours
    return weeklyHours >= 30;
  }

  /// Returns the overtime threshold (hours/week) for a given state.
  /// Falls back to federal 40-hour threshold.
  Future<double> overtimeThreshold({
    required DocumentReference<Map<String, dynamic>> companyRef,
    required String workState,
  }) async {
    if (workState.isNotEmpty) {
      final stateSnap =
          await FirebaseFirestore.instance.collection('stateRule').doc(workState).get();
      if (stateSnap.exists) {
        final d = stateSnap.data();
        if (d != null && d['overtimeThreshold'] != null) {
          return (d['overtimeThreshold'] as num).toDouble();
        }
      }
    }

    final fedSnap =
        await FirebaseFirestore.instance.collection('federalRule').doc('current').get();
    if (fedSnap.exists) {
      final d = fedSnap.data();
      if (d != null && d['overtimeThresholdWeekly'] != null) {
        return (d['overtimeThresholdWeekly'] as num).toDouble();
      }
    }

    return 40;
  }

  /// Returns the overtime pay multiplier for a given state (default 1.5x).
  Future<double> overtimeMultiplier({
    required DocumentReference<Map<String, dynamic>> companyRef,
    required String workState,
  }) async {
    if (workState.isNotEmpty) {
      final stateSnap =
          await FirebaseFirestore.instance.collection('stateRule').doc(workState).get();
      if (stateSnap.exists) {
        final d = stateSnap.data();
        if (d != null && d['overtimeMultiplier'] != null) {
          return (d['overtimeMultiplier'] as num).toDouble();
        }
      }
    }
    return 1.5;
  }

  /// Returns the effective minimum wage for an employee's state.
  /// Uses the higher of state or federal minimum wage.
  Future<double> effectiveMinimumWage({
    required DocumentReference<Map<String, dynamic>> companyRef,
    required String workState,
  }) async {
    double federalMin = 7.25;
    double stateMin = 0;

    final fedSnap =
        await FirebaseFirestore.instance.collection('federalRule').doc('current').get();
    if (fedSnap.exists) {
      final d = fedSnap.data();
      if (d != null && d['federalMinimumWage'] != null) {
        federalMin = (d['federalMinimumWage'] as num).toDouble();
      }
    }

    if (workState.isNotEmpty) {
      final stateSnap =
          await FirebaseFirestore.instance.collection('stateRule').doc(workState).get();
      if (stateSnap.exists) {
        final d = stateSnap.data();
        if (d != null && d['minimumWage'] != null) {
          stateMin = (d['minimumWage'] as num).toDouble();
        }
      }
    }

    return stateMin > federalMin ? stateMin : federalMin;
  }

  /// Returns the flat state tax rate for a given state, or null if
  /// the state uses graduated brackets (or has no income tax).
  Future<double?> stateTaxRate({
    required DocumentReference<Map<String, dynamic>> companyRef,
    required String workState,
  }) async {
    if (workState.isEmpty) return null;
    final stateSnap =
        await FirebaseFirestore.instance.collection('stateRule').doc(workState).get();
    if (!stateSnap.exists) return null;
    final d = stateSnap.data();
    if (d == null) return null;
    final rate = d['stateTaxRate'];
    if (rate == null) return null;
    return (rate as num).toDouble();
  }

  /// Returns the full federal rules document, or null if not configured.
  Future<Map<String, dynamic>?> federalRules({
    required DocumentReference<Map<String, dynamic>> companyRef,
  }) async {
    final snap =
        await FirebaseFirestore.instance.collection('federalRule').doc('current').get();
    return snap.data();
  }

  /// Returns the state rules for a given state, or null if not configured.
  Future<Map<String, dynamic>?> stateRules({
    required DocumentReference<Map<String, dynamic>> companyRef,
    required String workState,
  }) async {
    if (workState.isEmpty) return null;
    final snap =
        await FirebaseFirestore.instance.collection('stateRule').doc(workState).get();
    return snap.data();
  }

  /// Validates that an employee's pay rate meets minimum wage requirements.
  /// Returns null if valid, or an error message if below minimum.
  Future<String?> validatePayRate({
    required DocumentReference<Map<String, dynamic>> companyRef,
    required String workState,
    required double hourlyRate,
  }) async {
    final minWage = await effectiveMinimumWage(
      companyRef: companyRef,
      workState: workState,
    );
    if (hourlyRate < minWage) {
      return 'Hourly rate \$${hourlyRate.toStringAsFixed(2)} is below the '
          'effective minimum wage of \$${minWage.toStringAsFixed(2)} '
          '${workState.isNotEmpty ? 'for $workState' : '(federal)'}';
    }
    return null;
  }
}
