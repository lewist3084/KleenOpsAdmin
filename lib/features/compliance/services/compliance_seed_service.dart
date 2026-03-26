// lib/features/compliance/services/compliance_seed_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kleenops_admin/features/compliance/seed/federal_seed_data.dart';
import 'package:kleenops_admin/features/compliance/seed/state_seed_data.dart';
import 'package:kleenops_admin/features/compliance/seed/state_tax_brackets_data.dart';
import 'package:kleenops_admin/features/compliance/seed/local_tax_jurisdictions_oh.dart';
import 'package:kleenops_admin/features/compliance/seed/local_tax_jurisdictions_other.dart';
import 'package:kleenops_admin/features/compliance/seed/zip_tax_map_data.dart';
import 'package:kleenops_admin/features/compliance/seed/insurance_seed_data.dart';
import 'package:kleenops_admin/features/compliance/seed/business_formation_seed_data.dart';
// Comprehensive jurisdiction rate files
import 'package:kleenops_admin/features/compliance/seed/jurisdictions/indiana_county_rates.dart';
import 'package:kleenops_admin/features/compliance/seed/jurisdictions/maryland_county_rates.dart';
import 'package:kleenops_admin/features/compliance/seed/jurisdictions/michigan_city_rates.dart';
import 'package:kleenops_admin/features/compliance/seed/jurisdictions/ohio_city_rates.dart';
import 'package:kleenops_admin/features/compliance/seed/jurisdictions/pennsylvania_eit_rates.dart';
import 'package:kleenops_admin/features/compliance/seed/jurisdictions/other_local_rates.dart';
import 'package:kleenops_admin/features/compliance/seed/jurisdictions/fips_to_jurisdiction_map.dart';

/// Seeds top-level Firestore collections with compliance reference data.
///
/// Collections written:
///   federalRule/{year}
///   stateRule/{stateCode}
///   insuranceRequirement/{type}
///   businessFormation/{entityType}
///
/// This is idempotent — calling it again overwrites with latest data.
class ComplianceSeedService {
  final _db = FirebaseFirestore.instance;

  /// Seeds ALL reference data (federal + all 51 states + insurance + formations).
  /// Returns a summary of what was written.
  Future<Map<String, int>> seedAll({
    void Function(String message)? onProgress,
  }) async {
    final counts = <String, int>{};

    onProgress?.call('Seeding federal rules...');
    counts['federalRule'] = await seedFederalRules();

    onProgress?.call('Seeding state rules (51 states + DC)...');
    counts['stateRule'] = await seedStateRules(onProgress: onProgress);

    onProgress?.call('Seeding insurance requirements...');
    counts['insuranceRequirement'] = await seedInsuranceRequirements();

    onProgress?.call('Seeding business formation guidance...');
    counts['businessFormation'] = await seedBusinessFormations();

    onProgress?.call('Seeding local tax jurisdictions...');
    counts['taxJurisdiction'] = await seedTaxJurisdictions(onProgress: onProgress);

    onProgress?.call('Seeding ZIP-to-tax maps...');
    counts['zipTaxMap'] = await seedZipTaxMaps(onProgress: onProgress);

    onProgress?.call('Seeding FIPS-to-jurisdiction mappings...');
    counts['fipsToJurisdiction'] = await seedFipsMappings(onProgress: onProgress);

    onProgress?.call('Done! Seeded ${counts.values.fold(0, (a, b) => a + b)} documents.');
    return counts;
  }

  /// Seeds the federal rule for 2026.
  Future<int> seedFederalRules() async {
    final data = {
      ...kFederalRule2026,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': 'seed',
    };
    await _db.collection('federalRule').doc('2026').set(data);
    return 1;
  }

  /// Seeds all 51 state rules. Uses batched writes (max 500 per batch).
  Future<int> seedStateRules({
    void Function(String message)? onProgress,
  }) async {
    int count = 0;
    WriteBatch batch = _db.batch();
    int batchCount = 0;

    for (final entry in kStateRules.entries) {
      final stateCode = entry.key;
      final data = {
        ...entry.value,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': 'seed',
      };

      // Merge in tax brackets if the state is graduated and doesn't already have them
      if (data['stateTaxType'] == 'graduated' &&
          data['taxBrackets'] == null &&
          kStateTaxBrackets.containsKey(stateCode)) {
        data['taxBrackets'] = kStateTaxBrackets[stateCode];
      }

      // Attach any local income taxes for this state
      final localTaxes = kLocalIncomeTaxes.entries
          .where((e) => e.value['stateCode'] == stateCode)
          .map((e) => {'localityKey': e.key, ...e.value})
          .toList();
      if (localTaxes.isNotEmpty) {
        data['localIncomeTaxes'] = localTaxes;
      }
      batch.set(
        _db.collection('stateRule').doc(stateCode),
        data,
      );
      count++;
      batchCount++;

      // Firestore batch limit is 500 writes
      if (batchCount >= 450) {
        await batch.commit();
        onProgress?.call('  Written $count states...');
        batch = _db.batch();
        batchCount = 0;
      }
    }

    if (batchCount > 0) {
      await batch.commit();
    }

    return count;
  }

  /// Seeds insurance requirement documents.
  Future<int> seedInsuranceRequirements() async {
    final batch = _db.batch();
    int count = 0;

    for (final entry in kInsuranceRequirements.entries) {
      final data = {
        ...entry.value,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': 'seed',
      };
      batch.set(
        _db.collection('insuranceRequirement').doc(entry.key),
        data,
      );
      count++;
    }

    await batch.commit();
    return count;
  }

  /// Seeds business formation guidance documents.
  Future<int> seedBusinessFormations() async {
    final batch = _db.batch();
    int count = 0;

    for (final entry in kBusinessFormations.entries) {
      final data = {
        ...entry.value,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': 'seed',
      };
      batch.set(
        _db.collection('businessFormation').doc(entry.key),
        data,
      );
      count++;
    }

    await batch.commit();
    return count;
  }

  /// Seeds local tax jurisdiction documents (OH cities, PA EIT, IN/MD counties, etc.).
  /// Includes comprehensive data from all jurisdiction files.
  Future<int> seedTaxJurisdictions({
    void Function(String message)? onProgress,
  }) async {
    int count = 0;
    WriteBatch batch = _db.batch();
    int batchCount = 0;

    // Combine all jurisdiction maps — comprehensive coverage
    final allJurisdictions = <String, Map<String, dynamic>>{
      // Legacy data (original smaller sets)
      ...kOhioJurisdictions,
      ...kOtherStateJurisdictions,
      // Comprehensive jurisdiction files (override legacy where overlapping)
      ...kIndianaCountyRates,
      ...kMarylandCountyRates,
      ...kMichiganCityRates,
      ...kOhioCityRates,
      ...kPennsylvaniaEitRates,
      ...kKentuckyLocalRates,
      ...kAlabamaLocalRates,
      ...kMissouriLocalRates,
      ...kColoradoLocalRates,
      ...kDelawareLocalRates,
      ...kNewYorkLocalRates,
      ...kOregonLocalRates,
      ...kWestVirginiaLocalRates,
      ...kNewJerseyPayrollTaxes,
    };

    for (final entry in allJurisdictions.entries) {
      final data = {
        ...entry.value,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': 'seed',
      };
      batch.set(
        _db.collection('taxJurisdiction').doc(entry.key),
        data,
      );
      count++;
      batchCount++;

      if (batchCount >= 450) {
        await batch.commit();
        onProgress?.call('  Written $count jurisdictions...');
        batch = _db.batch();
        batchCount = 0;
      }
    }

    if (batchCount > 0) {
      await batch.commit();
    }

    onProgress?.call('  Seeded $count total tax jurisdictions');
    return count;
  }

  /// Seeds FIPS-to-jurisdiction mapping documents.
  /// Maps county FIPS codes to lists of applicable jurisdiction IDs.
  Future<int> seedFipsMappings({
    void Function(String message)? onProgress,
  }) async {
    int count = 0;
    WriteBatch batch = _db.batch();
    int batchCount = 0;

    for (final entry in kFipsToJurisdiction.entries) {
      final data = {
        'fips': entry.key,
        'jurisdictionIds': entry.value,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': 'seed',
      };
      batch.set(
        _db.collection('fipsToJurisdiction').doc(entry.key),
        data,
      );
      count++;
      batchCount++;

      if (batchCount >= 450) {
        await batch.commit();
        onProgress?.call('  Written $count FIPS mappings...');
        batch = _db.batch();
        batchCount = 0;
      }
    }

    if (batchCount > 0) {
      await batch.commit();
    }

    onProgress?.call('  Seeded $count FIPS-to-jurisdiction mappings');
    return count;
  }

  /// Seeds ZIP-to-jurisdiction mapping documents.
  Future<int> seedZipTaxMaps({
    void Function(String message)? onProgress,
  }) async {
    int count = 0;
    WriteBatch batch = _db.batch();
    int batchCount = 0;

    for (final entry in kZipTaxMap.entries) {
      final data = {
        ...entry.value,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': 'seed',
      };
      batch.set(
        _db.collection('zipTaxMap').doc(entry.key),
        data,
      );
      count++;
      batchCount++;

      if (batchCount >= 450) {
        await batch.commit();
        onProgress?.call('  Written $count ZIP maps...');
        batch = _db.batch();
        batchCount = 0;
      }
    }

    if (batchCount > 0) {
      await batch.commit();
    }
    return count;
  }

  /// Checks whether the seed data already exists.
  Future<bool> isFederalRuleSeeded() async {
    final snap = await _db.collection('federalRule').doc('2026').get();
    return snap.exists;
  }

  /// Gets counts of existing reference data.
  Future<Map<String, int>> getExistingCounts() async {
    final results = await Future.wait([
      _db.collection('federalRule').count().get(),
      _db.collection('stateRule').count().get(),
      _db.collection('insuranceRequirement').count().get(),
      _db.collection('businessFormation').count().get(),
      _db.collection('taxJurisdiction').count().get(),
      _db.collection('fipsToJurisdiction').count().get(),
      _db.collection('zipTaxMap').count().get(),
    ]);
    return {
      'federalRule': results[0].count ?? 0,
      'stateRule': results[1].count ?? 0,
      'insuranceRequirement': results[2].count ?? 0,
      'businessFormation': results[3].count ?? 0,
      'taxJurisdiction': results[4].count ?? 0,
      'fipsToJurisdiction': results[5].count ?? 0,
      'zipTaxMap': results[6].count ?? 0,
    };
  }
}
