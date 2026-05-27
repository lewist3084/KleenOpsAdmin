// plaid_service.dart

import 'dart:async';
import 'dart:io' show Platform;

import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:plaid_flutter/plaid_flutter.dart';

import 'plaid_oauth_state_io.dart'
    if (dart.library.html) 'plaid_oauth_state_web.dart' as oauth_state;

String _plaidPlatform() {
  if (kIsWeb) return 'web';
  if (Platform.isAndroid) return 'android';
  if (Platform.isIOS) return 'ios';
  return 'web';
}

class PlaidService {
  PlaidService({required this.companyRef});

  final DocumentReference<Map<String, dynamic>> companyRef;

  String get _companyId => companyRef.id;

  /// Creates a Plaid Link token via Cloud Functions.
  /// [language] is the BCP-47 / Plaid language code (en, es, fr, …) used to
  /// render Plaid Link UI. Unsupported codes silently fall back to English.
  Future<String> createLinkToken({String language = 'en'}) async {
    final callable =
        FirebaseFunctions.instance.httpsCallable('financeCreateLinkToken');
    final result = await callable.call({
      'companyId': _companyId,
      'platform': _plaidPlatform(),
      'language': language,
    });
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
  /// [language] is the BCP-47 language code for Plaid Link UI.
  Future<bool> openPlaidLink({String language = 'en'}) async {
    try {
      final linkToken = await createLinkToken(language: language);
      // Persist the link_token on web so resumePlaidOauthIfPending can
      // re-create Link with the same token after the OAuth redirect.
      if (kIsWeb) oauth_state.saveLinkToken(linkToken);

      final linkConfig = LinkTokenConfiguration(token: linkToken);
      return _runPlaidSession(linkConfig);
    } catch (e) {
      debugPrint('PlaidService.openPlaidLink error: $e');
      return false;
    }
  }

  /// Web-only: if the current URL is the Plaid OAuth redirect target with an
  /// `oauth_state_id` query param, re-open Plaid Link with
  /// `receivedRedirectUri` so the session resumes where the user left off.
  /// Returns true if a resume was attempted and succeeded.
  static Future<bool> resumePlaidOauthIfPending({
    DocumentReference<Map<String, dynamic>>? companyRef,
  }) async {
    if (!kIsWeb) return false;
    final redirectUri = oauth_state.readOauthRedirectUri();
    if (redirectUri == null) return false;
    final savedToken = oauth_state.readLinkToken();
    if (savedToken == null) {
      // Stale redirect — nothing we can do, clear and bail.
      oauth_state.clearLinkToken();
      return false;
    }
    try {
      final linkConfig = LinkTokenConfiguration(
        token: savedToken,
        receivedRedirectUri: redirectUri,
      );
      if (companyRef != null) {
        final service = PlaidService(companyRef: companyRef);
        return service._runPlaidSession(linkConfig);
      }
      // No companyRef — at minimum, hand the redirect to Plaid so it can
      // clean up its in-memory state; the caller is responsible for
      // exchanging on success once a companyRef is known.
      await PlaidLink.create(configuration: linkConfig);
      await PlaidLink.open();
      return false;
    } catch (e) {
      debugPrint('PlaidService.resumePlaidOauthIfPending error: $e');
      return false;
    } finally {
      oauth_state.clearLinkToken();
    }
  }

  Future<bool> _runPlaidSession(LinkTokenConfiguration linkConfig) async {
    await PlaidLink.create(configuration: linkConfig);

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
      if (!completer.isCompleted) completer.complete(false);
    });

    await PlaidLink.open();
    final result = await completer.future;

    await successSub.cancel();
    await exitSub.cancel();

    if (kIsWeb) oauth_state.clearLinkToken();
    return result;
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
