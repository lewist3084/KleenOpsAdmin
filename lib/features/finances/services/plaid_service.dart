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
  /// Overlord scope — the KleenOps platform's own books, stored in **top-level**
  /// collections beside the `company` collection (the admin app's own business).
  PlaidService.overlord() : companyRef = null;

  /// Per-company scope — a specific company's books under `company/{id}/…`
  /// (used for overlord drill-in into a customer's books).
  PlaidService.forCompany(this.companyRef);

  /// Null in overlord scope; the company doc otherwise.
  final DocumentReference<Map<String, dynamic>>? companyRef;

  bool get _isOverlord => companyRef == null;

  /// Scope selector sent to every finance callable: `{overlord:true}` or
  /// `{companyId: …}`.
  Map<String, dynamic> get _scopeArgs =>
      _isOverlord ? {'overlord': true} : {'companyId': companyRef!.id};

  FirebaseFirestore get _booksDb =>
      companyRef?.firestore ?? FirebaseFirestore.instance;

  /// A collection at the active books root: top-level for overlord, or a
  /// subcollection under the company doc otherwise.
  CollectionReference<Map<String, dynamic>> _col(String name) =>
      _isOverlord ? _booksDb.collection(name) : companyRef!.collection(name);

  /// Creates a Plaid Link token via Cloud Functions.
  /// [language] is the BCP-47 / Plaid language code (en, es, fr, …) used to
  /// render Plaid Link UI. Unsupported codes silently fall back to English.
  Future<String> createLinkToken({String language = 'en'}) async {
    final callable =
        FirebaseFunctions.instance.httpsCallable('financeCreateLinkToken');
    final result = await callable.call({
      ..._scopeArgs,
      'platform': _plaidPlatform(),
      'androidPackageName': 'com.kleenops.kleenops_admin',
      'language': language,
    });
    return result.data['linkToken'] as String;
  }

  /// Creates a Plaid Link token in *update mode* to repair a broken Item.
  Future<String> createUpdateLinkToken(String plaidItemId,
      {String language = 'en', bool accountSelection = false}) async {
    final callable = FirebaseFunctions.instance
        .httpsCallable('financeCreateUpdateLinkToken');
    final result = await callable.call({
      ..._scopeArgs,
      'plaidItemId': plaidItemId,
      'platform': _plaidPlatform(),
      'androidPackageName': 'com.kleenops.kleenops_admin',
      'language': language,
      'accountSelection': accountSelection,
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
      ..._scopeArgs,
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
      ..._scopeArgs,
      'plaidItemId': plaidItemId,
    });
    return Map<String, dynamic>.from(result.data as Map);
  }

  /// Refreshes balances for a given Plaid Item.
  Future<Map<String, dynamic>> getBalances(String plaidItemId) async {
    final callable =
        FirebaseFunctions.instance.httpsCallable('financeGetBalances');
    final result = await callable.call({
      ..._scopeArgs,
      'plaidItemId': plaidItemId,
    });
    return Map<String, dynamic>.from(result.data as Map);
  }

  /// Removes a connected institution.
  Future<void> removeInstitution(String plaidItemId) async {
    final callable =
        FirebaseFunctions.instance.httpsCallable('financeRemoveInstitution');
    await callable.call({
      ..._scopeArgs,
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
      return _runPlaidSession(linkConfig, _exchangeOnSuccess);
    } catch (e) {
      debugPrint('PlaidService.openPlaidLink error: $e');
      return false;
    }
  }

  /// Re-authenticates a broken Item via Plaid Link *update mode*.
  /// On success there is no public-token exchange; instead we run a sync,
  /// which clears the error state (status→active, needsReauth→false) and
  /// pulls any transactions missed while the Item was down.
  /// Returns true if the Item was successfully reconnected.
  Future<bool> reconnectInstitution(String plaidItemId,
      {String language = 'en'}) async {
    try {
      final linkToken =
          await createUpdateLinkToken(plaidItemId, language: language);
      if (kIsWeb) oauth_state.saveLinkToken(linkToken);
      final linkConfig = LinkTokenConfiguration(token: linkToken);
      return _runPlaidSession(linkConfig, (_) async {
        await syncTransactions(plaidItemId);
      });
    } catch (e) {
      debugPrint('PlaidService.reconnectInstitution error: $e');
      return false;
    }
  }

  /// Add-accounts: re-open the existing connection in update mode with account
  /// selection, so the user can add accounts they didn't link the first time
  /// (e.g. a second card/checking) — without creating a duplicate connection.
  /// On success, the new accounts are stored and their transactions synced.
  Future<bool> addAccounts(String plaidItemId, {String language = 'en'}) async {
    try {
      final linkToken = await createUpdateLinkToken(plaidItemId,
          language: language, accountSelection: true);
      if (kIsWeb) oauth_state.saveLinkToken(linkToken);
      final linkConfig = LinkTokenConfiguration(token: linkToken);
      return _runPlaidSession(linkConfig, (_) async {
        await refreshAccounts(plaidItemId);
        await syncTransactions(plaidItemId);
      });
    } catch (e) {
      debugPrint('PlaidService.addAccounts error: $e');
      return false;
    }
  }

  /// Re-fetches + stores any newly-added accounts for an Item.
  Future<Map<String, dynamic>> refreshAccounts(String plaidItemId) async {
    final callable =
        FirebaseFunctions.instance.httpsCallable('financeRefreshAccounts');
    final result = await callable.call({
      ..._scopeArgs,
      'plaidItemId': plaidItemId,
    });
    return Map<String, dynamic>.from(result.data as Map);
  }

  /// Web-only: if the current URL is the Plaid OAuth redirect target with an
  /// `oauth_state_id` query param, re-open Plaid Link with
  /// `receivedRedirectUri` so the session resumes where the user left off.
  /// Returns true if a resume was attempted and succeeded.
  static Future<bool> resumePlaidOauthIfPending() async {
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
      // The admin app's banking is the overlord (platform) scope.
      final service = PlaidService.overlord();
      return service._runPlaidSession(linkConfig, service._exchangeOnSuccess);
    } catch (e) {
      debugPrint('PlaidService.resumePlaidOauthIfPending error: $e');
      return false;
    } finally {
      oauth_state.clearLinkToken();
    }
  }

  /// Exchanges the public token after a successful *initial* Plaid Link.
  Future<void> _exchangeOnSuccess(LinkSuccess success) async {
    await exchangePublicToken(
      publicToken: success.publicToken,
      institutionId: success.metadata.institution?.id ?? '',
      institutionName: success.metadata.institution?.name ?? '',
    );
  }

  /// Drives a Plaid Link session, running [onSuccess] when the user completes
  /// it. Used for both initial connect (exchange) and update-mode re-auth
  /// (sync). Returns true on success, false on exit/error.
  Future<bool> _runPlaidSession(
    LinkTokenConfiguration linkConfig,
    Future<void> Function(LinkSuccess success) onSuccess,
  ) async {
    await PlaidLink.create(configuration: linkConfig);

    final completer = Completer<bool>();

    final successSub = PlaidLink.onSuccess.listen((success) async {
      try {
        await onSuccess(success);
        if (!completer.isCompleted) completer.complete(true);
      } catch (e) {
        debugPrint('PlaidService session onSuccess error: $e');
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

  /// Stream of connected Plaid Items at the active books root (top-level for
  /// the overlord/platform, or `company/{id}/plaidItem` for a company).
  Stream<QuerySnapshot<Map<String, dynamic>>> watchPlaidItems() {
    return _col('plaidItem')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  /// Stream of active bank accounts at the active books root.
  Stream<QuerySnapshot<Map<String, dynamic>>> watchBankAccounts() {
    return _col('bankAccount')
        .where('active', isEqualTo: true)
        .snapshots();
  }

  /// Stream of active bank accounts under a given Plaid Item.
  Stream<QuerySnapshot<Map<String, dynamic>>> watchAccountsForItem(
      String plaidItemId) {
    return _col('bankAccount')
        .where('plaidItemId', isEqualTo: plaidItemId)
        .where('active', isEqualTo: true)
        .snapshots();
  }

  /// Designates a bank account as the payroll disbursement account.
  /// Clears any previous payroll designation first.
  Future<void> setPayrollAccount(String bankAccountId) async {
    final accounts = _col('bankAccount');
    // Clear existing payroll designations
    final existing =
        await accounts.where('isPayrollAccount', isEqualTo: true).get();
    final batch = _booksDb.batch();
    for (final doc in existing.docs) {
      batch.update(doc.reference, {'isPayrollAccount': false});
    }
    // Set the new one
    batch.update(accounts.doc(bankAccountId), {'isPayrollAccount': true});
    await batch.commit();
  }

  /// Gets the designated payroll account, if any.
  Future<DocumentSnapshot<Map<String, dynamic>>?> getPayrollAccount() async {
    final snap = await _col('bankAccount')
        .where('isPayrollAccount', isEqualTo: true)
        .where('active', isEqualTo: true)
        .limit(1)
        .get();
    return snap.docs.isNotEmpty ? snap.docs.first : null;
  }

  /// Stream of bank transactions for a specific account.
  Stream<QuerySnapshot<Map<String, dynamic>>> watchBankTransactions(
      String bankAccountId) {
    return _col('bankTransaction')
        .where('bankAccountId', isEqualTo: bankAccountId)
        .orderBy('date', descending: true)
        .limit(100)
        .snapshots();
  }
}
