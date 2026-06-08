import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/setup_wizard_data.dart';

class SetupWizardService {
  SetupWizardService._();
  static final instance = SetupWizardService._();

  CollectionReference<Map<String, dynamic>> get _col =>
      FirebaseFirestore.instance.collection('setupWizard');

  DocumentReference<Map<String, dynamic>> get _doc => _col.doc('current');

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchProgress() =>
      _doc.snapshots();

  Future<Map<String, dynamic>?> getProgress() async {
    final snap = await _doc.get();
    return snap.data();
  }

  Future<void> initializeIfNeeded() async {
    final snap = await _doc.get();
    if (snap.exists) return;

    final items = <String, Map<String, dynamic>>{};
    for (final cat in kSetupWizardCategories) {
      for (final item in cat.items) {
        items[item.key] = {
          'categoryKey': cat.key,
          'position': item.position,
          'status': 'not_started',
          'completedAt': null,
          'data': <String, dynamic>{},
          'aiAssisted': false,
          'notes': null,
        };
      }
    }

    final categories = <String, Map<String, dynamic>>{};
    for (final cat in kSetupWizardCategories) {
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

  /// Reconciles a connection step's status with whether it is actually
  /// connected (a matching bank/card account exists). Writes only when the
  /// status differs, so it's safe to call repeatedly from a stream listener.
  /// This makes "Connect Your Bank Account" / "Connect a Credit Card" reflect
  /// reality: linking both in one Plaid session checks both; disconnecting
  /// unchecks them.
  Future<void> syncConnectionStep(String itemKey, bool connected) async {
    final snap = await _doc.get();
    final items = (snap.data()?['items'] as Map<String, dynamic>?) ?? {};
    final item = items[itemKey] as Map<String, dynamic>?;
    if (item == null) return;
    final current = item['status'] as String?;
    final desired = connected ? 'complete' : 'not_started';
    if (current == desired) return;
    await updateItemStatus(
      itemKey,
      connected ? WizardItemStatus.complete : WizardItemStatus.notStarted,
    );
  }

  /// Hide the wizard from auto-display surfaces. The wizard remains
  /// reachable from the side menu.
  Future<void> dismiss() async {
    await _doc.set({
      'dismissed': true,
      'dismissedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _recalculateProgress() async {
    final snap = await _doc.get();
    final wizardData = snap.data();
    if (wizardData == null) return;

    final items =
        (wizardData['items'] as Map<String, dynamic>?) ?? {};
    final categories =
        (wizardData['categories'] as Map<String, dynamic>?) ?? {};

    int totalDone = 0;
    int totalItems = 0;

    // Count per category.
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
      final catStatus =
          done >= total ? 'complete' : (done > 0 ? 'in_progress' : 'not_started');
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
