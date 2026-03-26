// lib/features/finances/services/local_tax_lookup_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:kleenops_admin/features/finances/services/tax_calculation_service.dart';

/// Looks up local income tax jurisdictions by ZIP code and calculates
/// all applicable local taxes for payroll.
///
/// Architecture:
///   zipTaxMap/{zipCode}         — maps ZIP to jurisdiction list
///   taxJurisdiction/{id}        — full jurisdiction details with rates
///
/// One Firestore read for ZIP lookup, +1 per graduated jurisdiction.
class LocalTaxLookupService {
  final _db = FirebaseFirestore.instance;
  final _tax = TaxCalculationService();

  // ─── ZIP Lookup ───

  /// Looks up a ZIP code and returns all applicable local tax jurisdictions.
  ///
  /// Returns:
  ///   found: bool
  ///   stateCode: String
  ///   countyName: String
  ///   countyFips: String
  ///   ambiguous: bool (true if ZIP spans multiple municipalities)
  ///   jurisdictions: List<Map> with jurisdictionId, name, type, rate
  Future<Map<String, dynamic>> lookupByZip(String zip) async {
    final clean = zip.trim().split('-').first; // Handle ZIP+4
    if (clean.length != 5) {
      return {'found': false, 'jurisdictions': <Map<String, dynamic>>[]};
    }

    // ── Fast path: check Firestore cache ──
    final snap = await _db.collection('zipTaxMap').doc(clean).get();
    if (snap.exists) {
      final data = snap.data()!;
      return {
        'found': true,
        'zip': clean,
        'stateCode': data['stateCode'] ?? '',
        'countyName': data['countyName'] ?? '',
        'countyFips': data['countyFips'] ?? '',
        'cityName': data['cityName'] ?? '',
        'ambiguous': data['ambiguous'] ?? false,
        'jurisdictions':
            (data['jurisdictions'] as List<dynamic>?)
                ?.map((j) => Map<String, dynamic>.from(j as Map))
                .toList() ??
            <Map<String, dynamic>>[],
      };
    }

    // ── Slow path: call Cloud Function to resolve via HUD/Census ──
    try {
      final callable = FirebaseFunctions.instance
          .httpsCallable('complianceResolveZip');
      final result = await callable.call({'zip': clean});
      final data = Map<String, dynamic>.from(result.data as Map);
      return {
        'found': data['found'] ?? false,
        'zip': clean,
        'stateCode': data['stateCode'] ?? '',
        'countyName': data['countyName'] ?? '',
        'countyFips': data['countyFips'] ?? '',
        'cityName': data['cityName'] ?? '',
        'ambiguous': data['ambiguous'] ?? false,
        'jurisdictions':
            (data['jurisdictions'] as List<dynamic>?)
                ?.map((j) => Map<String, dynamic>.from(j as Map))
                .toList() ??
            <Map<String, dynamic>>[],
      };
    } catch (e) {
      debugPrint('LocalTaxLookupService: Cloud Function fallback failed: $e');
      return {'found': false, 'jurisdictions': <Map<String, dynamic>>[]};
    }
  }

  /// Gets full jurisdiction details (needed for graduated brackets).
  Future<Map<String, dynamic>?> getJurisdiction(
      String jurisdictionId) async {
    final snap =
        await _db.collection('taxJurisdiction').doc(jurisdictionId).get();
    return snap.exists ? snap.data() : null;
  }

  // ─── Tax Calculation ───

  /// Calculates all local taxes for a pay period given resolved jurisdictions.
  ///
  /// [resolvedJurisdictions] — the jurisdiction list stored on the employee
  ///   (from lookupByZip + disambiguation).
  ///
  /// Returns list of tax line items with jurisdictionId, name, type, amount.
  Future<List<Map<String, dynamic>>> calculateAllLocalTaxes({
    required double periodGross,
    required String payFrequency,
    required List<Map<String, dynamic>> resolvedJurisdictions,
  }) async {
    final results = <Map<String, dynamic>>[];

    for (final j in resolvedJurisdictions) {
      final jurisdictionId = (j['jurisdictionId'] ?? '').toString();
      final name = (j['name'] ?? '').toString();
      final type = (j['type'] ?? '').toString();

      // Determine tax data — use denormalized rate for flat, fetch full for graduated
      Map<String, dynamic> taxData;
      final taxType = (j['taxType'] ?? 'flat').toString();

      if (taxType == 'graduated' || j['brackets'] != null) {
        // Need full jurisdiction doc for bracket data
        final fullDoc = await getJurisdiction(jurisdictionId);
        taxData = fullDoc ?? j;
      } else {
        taxData = j;
      }

      // Handle PA EIT special case (municipalRate + schoolDistrictRate)
      if (type == 'eit') {
        final munRate =
            (taxData['municipalRate'] as num?)?.toDouble() ?? 0;
        final sdRate =
            (taxData['schoolDistrictRate'] as num?)?.toDouble() ?? 0;
        final totalRate = munRate + sdRate;
        if (totalRate > 0) {
          final periods = _periodsPerYear(payFrequency);
          final tax = (periodGross * periods * totalRate) / periods;
          results.add({
            'jurisdictionId': jurisdictionId,
            'name': name,
            'type': type,
            'municipalRate': munRate,
            'schoolDistrictRate': sdRate,
            'amount': _round(tax),
          });
        }
        continue;
      }

      // Standard local tax calculation
      final tax = _tax.calculateLocalIncomeTax(
        periodGross: periodGross,
        payFrequency: payFrequency,
        localTaxData: taxData,
      );

      if (tax > 0) {
        results.add({
          'jurisdictionId': jurisdictionId,
          'name': name,
          'type': type,
          'amount': _round(tax),
        });
      }
    }

    return results;
  }

  /// Convenience: total local tax from a jurisdiction list.
  Future<double> calculateTotalLocalTax({
    required double periodGross,
    required String payFrequency,
    required List<Map<String, dynamic>> resolvedJurisdictions,
  }) async {
    final items = await calculateAllLocalTaxes(
      periodGross: periodGross,
      payFrequency: payFrequency,
      resolvedJurisdictions: resolvedJurisdictions,
    );
    return items.fold<double>(
        0, (sum, item) => sum + ((item['amount'] as num?)?.toDouble() ?? 0));
  }

  // ─── Resolution Helpers ───

  /// For ambiguous ZIPs, resolves to a specific set of jurisdictions
  /// based on the user's selection.
  ///
  /// [selectedJurisdictionIds] — the IDs the user selected from the
  ///   disambiguation dialog.
  /// [allCandidates] — the full list from lookupByZip.
  List<Map<String, dynamic>> resolveAmbiguous({
    required List<String> selectedJurisdictionIds,
    required List<Map<String, dynamic>> allCandidates,
  }) {
    return allCandidates
        .where((j) =>
            selectedJurisdictionIds.contains(j['jurisdictionId']) ||
            // Always include county/transit/school (non-ambiguous types)
            j['type'] == 'county' ||
            j['type'] == 'transit' ||
            j['type'] == 'school_district')
        .toList();
  }

  // ─── Helpers ───

  int _periodsPerYear(String frequency) {
    switch (frequency) {
      case 'weekly': return 52;
      case 'biweekly': return 26;
      case 'semimonthly': return 24;
      case 'monthly': return 12;
      default: return 26;
    }
  }

  double _round(double v) => (v * 100).roundToDouble() / 100;
}
