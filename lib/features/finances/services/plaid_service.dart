// plaid_service.dart

import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:plaid_flutter/plaid_flutter.dart';

class PlaidService {
  PlaidService({required this.companyRef});

  final DocumentReference<Map<String, dynamic>> companyRef;

  String get _companyId => companyRef.id;

  /// Creates a Plaid Link token via Cloud Functions.
  Future<String> createLinkToken() async {
    final callable =
        FirebaseFunctions.instance.httpsCallable('financeCreateLinkToken');
    final result = await callable.call({'companyId': _companyId});
    return result.data['linkToken'] as String;
  }

  /// Exchanges the public token after successful Plaid Link.
  Future<Map<String, dynamic>> exchangePublicToken({
    required String publicToken,
    String? institutionId,
    String? institutionName,
  }) async {
    final callable =
        FirebaseFunctions.instance.httpsCallable('financeExchangePublicToken');
    final result = await callable.call({
      'companyId': _companyId,
      'publicToken': publicToken,
      'institutionId': institutionId ?? '',
      'institutionName': institutionName ?? '',
    });
    return Map<String, dynamic>.from(result.data as Map);
  }

  /// Syncs transactions for a given Plaid Item.
  Future<Map<String, dynamic>> syncTransactions(String plaidItemId) async {
    final callable =
        FirebaseFunctions.instance.httpsCallable('financeSyncTransactions');
    final result = await callable.call({
      'companyId': _companyId,
      'plaidItemId': plaidItemId,
    });
    return Map<String, dynamic>.from(result.data as Map);
  }

  /// Refreshes balances for a given Plaid Item.
  Future<Map<String, dynamic>> getBalances(String plaidItemId) async {
    final callable =
        FirebaseFunctions.instance.httpsCallable('financeGetBalances');
    final result = await callable.call({
      'companyId': _companyId,
      'plaidItemId': plaidItemId,
    });
    return Map<String, dynamic>.from(result.data as Map);
  }

  /// Removes a connected institution.
  Future<void> removeInstitution(String plaidItemId) async {
    final callable =
        FirebaseFunctions.instance.httpsCallable('financeRemoveInstitution');
    await callable.call({
      'companyId': _companyId,
      'plaidItemId': plaidItemId,
    });
  }

  /// Opens Plaid Link and handles the result.
  /// Returns true if an institution was successfully connected.
  Future<bool> openPlaidLink() async {
    try {
      final linkToken = await createLinkToken();
      final linkConfig = LinkTokenConfiguration(token: linkToken);

      // Create the Link handler
      await PlaidLink.create(configuration: linkConfig);

      // Set up stream listeners before opening
      final completer = Completer<bool>();

      final successSub = PlaidLink.onSuccess.listen((success) async {
        try {
          await exchangePublicToken(
            publicToken: success.publicToken,
            institutionId: success.metadata.institution?.id ?? '',
            institutionName: success.metadata.institution?.name ?? '',
          );
          if (!completer.isCompleted) completer.complete(true);
        } catch (e) {
          debugPrint('PlaidService exchange error: $e');
          if (!completer.isCompleted) completer.complete(false);
        }
      });

      final exitSub = PlaidLink.onExit.listen((exit) {
        if (!completer.isCompleted) {
          completer.complete(false);
        }
      });

      // Open the Link flow
      await PlaidLink.open();

      // Wait for result
      final result = await completer.future;

      // Clean up subscriptions
      await successSub.cancel();
      await exitSub.cancel();

      return result;
    } catch (e) {
      debugPrint('PlaidService.openPlaidLink error: $e');
      return false;
    }
  }

  /// Stream of connected Plaid Items for this company.
  Stream<QuerySnapshot<Map<String, dynamic>>> watchPlaidItems() {
    return FirebaseFirestore.instance
        .collection('plaidItem')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  /// Stream of bank accounts for this company.
  Stream<QuerySnapshot<Map<String, dynamic>>> watchBankAccounts() {
    return FirebaseFirestore.instance
        .collection('bankAccount')
        .where('active', isEqualTo: true)
        .snapshots();
  }

  /// Designates a bank account as the payroll disbursement account.
  /// Clears any previous payroll designation first.
  Future<void> setPayrollAccount(String bankAccountId) async {
    // Clear existing payroll designations
    final existing = await FirebaseFirestore.instance
        .collection('bankAccount')
        .where('isPayrollAccount', isEqualTo: true)
        .get();
    final batch = FirebaseFirestore.instance.batch();
    for (final doc in existing.docs) {
      batch.update(doc.reference, {'isPayrollAccount': false});
    }
    // Set the new one
    batch.update(
      FirebaseFirestore.instance.collection('bankAccount').doc(bankAccountId),
      {'isPayrollAccount': true},
    );
    await batch.commit();
  }

  /// Gets the designated payroll account, if any.
  Future<DocumentSnapshot<Map<String, dynamic>>?> getPayrollAccount() async {
    final snap = await FirebaseFirestore.instance
        .collection('bankAccount')
        .where('isPayrollAccount', isEqualTo: true)
        .where('active', isEqualTo: true)
        .limit(1)
        .get();
    return snap.docs.isNotEmpty ? snap.docs.first : null;
  }

  /// Stream of bank transactions for a specific account.
  Stream<QuerySnapshot<Map<String, dynamic>>> watchBankTransactions(
      String bankAccountId) {
    return FirebaseFirestore.instance
        .collection('bankTransaction')
        .where('bankAccountId', isEqualTo: bankAccountId)
        .orderBy('date', descending: true)
        .limit(100)
        .snapshots();
  }
}
