import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kleenops_admin/features/admin/models/setup_wizard_data.dart';
import '../models/finance_setup_wizard_data.dart';

class FinanceSetupWizardService {
  final DocumentReference<Map<String, dynamic>> companyRef;

  FinanceSetupWizardService({required this.companyRef});

  DocumentReference<Map<String, dynamic>> get _doc =>
      FirebaseFirestore.instance.collection('financeSetupWizard').doc('current');

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchProgress() =>
      _doc.snapshots();

  Future<void> initializeIfNeeded() async {
    final snap = await _doc.get();
    if (snap.exists) return;

    final items = <String, Map<String, dynamic>>{};
    for (final cat in kFinanceSetupCategories) {
      for (final item in cat.items) {
        items[item.key] = {
          'categoryKey': cat.key,
          'position': item.position,
          'status': 'not_started',
          'completedAt': null,
          'data': <String, dynamic>{},
          'notes': null,
        };
      }
    }

    final categories = <String, Map<String, dynamic>>{};
    for (final cat in kFinanceSetupCategories) {
      categories[cat.key] = {
        'label': cat.label,
        'position': cat.position,
        'status': 'not_started',
        'completedCount': 0,
        'totalCount': cat.items.length,
      };
    }

    await _doc.set({
      'startedAt': FieldValue.serverTimestamp(),
      'lastUpdatedAt': FieldValue.serverTimestamp(),
      'completedAt': null,
      'isComplete': false,
      'overallProgress': 0.0,
      'categories': categories,
      'items': items,
    });
  }

  Future<void> updateItemStatus(
    String itemKey,
    WizardItemStatus status, {
    Map<String, dynamic>? data,
  }) async {
    final updates = <String, dynamic>{
      'items.$itemKey.status': wizardStatusToString(status),
      'lastUpdatedAt': FieldValue.serverTimestamp(),
    };
    if (status == WizardItemStatus.complete) {
      updates['items.$itemKey.completedAt'] = FieldValue.serverTimestamp();
    }
    if (data != null) {
      updates['items.$itemKey.data'] = data;
    }
    await _doc.update(updates);
    await _recalculateProgress();
  }

  Future<void> skipItem(String itemKey) =>
      updateItemStatus(itemKey, WizardItemStatus.skipped);

  Future<void> completeItem(String itemKey, {Map<String, dynamic>? data}) =>
      updateItemStatus(itemKey, WizardItemStatus.complete, data: data);

  Future<void> _recalculateProgress() async {
    final snap = await _doc.get();
    final wizardData = snap.data();
    if (wizardData == null) return;

    final items = (wizardData['items'] as Map<String, dynamic>?) ?? {};
    final categories =
        (wizardData['categories'] as Map<String, dynamic>?) ?? {};

    int totalDone = 0;
    int totalItems = 0;

    final catCounts = <String, int>{};
    for (final entry in items.entries) {
      final itemData = entry.value as Map<String, dynamic>;
      final catKey = itemData['categoryKey'] as String? ?? '';
      final status = parseWizardStatus(itemData['status'] as String?);
      catCounts[catKey] = (catCounts[catKey] ?? 0);
      totalItems++;
      if (status == WizardItemStatus.complete ||
          status == WizardItemStatus.skipped) {
        catCounts[catKey] = (catCounts[catKey] ?? 0) + 1;
        totalDone++;
      }
    }

    final catUpdates = <String, dynamic>{};
    for (final catKey in categories.keys) {
      final total =
          (categories[catKey] as Map<String, dynamic>)['totalCount'] as int? ??
              0;
      final done = catCounts[catKey] ?? 0;
      final catStatus = done >= total
          ? 'complete'
          : (done > 0 ? 'in_progress' : 'not_started');
      catUpdates['categories.$catKey.completedCount'] = done;
      catUpdates['categories.$catKey.status'] = catStatus;
    }

    final progress = totalItems > 0 ? totalDone / totalItems : 0.0;
    catUpdates['overallProgress'] = progress;
    catUpdates['isComplete'] = totalDone >= totalItems;
    if (totalDone >= totalItems) {
      catUpdates['completedAt'] = FieldValue.serverTimestamp();
    }

    await _doc.update(catUpdates);
  }
}
