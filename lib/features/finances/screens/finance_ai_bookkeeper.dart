// finance_ai_bookkeeper.dart
//
// "AI Bookkeeper" review screen (overlord scope). On open it runs one Gemini
// pass over the distinct merchants in the imported (unreconciled) bank
// transactions + the existing chart, proposing an account for each merchant —
// reusing existing accounts and proposing NEW ones where needed. The user
// signs off on the NEW accounts; on approval the accounts are created, every
// transaction is assigned by merchant + posted to the ledger (double-entry),
// and merchant rules are learned for next time.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_widgets/containers/canvas_top_bookend.dart';
import 'package:shared_widgets/containers/standard_canvas.dart';
import 'package:shared_widgets/finance/finance_books_root.dart';
import 'package:shared_widgets/finance/transaction_categorizer_service.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/details_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/home_navbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/drawers/appbar_logout_adapter.dart';
import 'package:kleenops_admin/services/firebase_ai/gemini_bookkeeper_service.dart';
import 'package:kleenops_admin/services/firebase_ai/gemini_translation_service.dart';

class FinanceAiBookkeeperScreen extends StatefulWidget {
  const FinanceAiBookkeeperScreen({super.key});

  @override
  State<FinanceAiBookkeeperScreen> createState() =>
      _FinanceAiBookkeeperScreenState();
}

class _ProposedAccount {
  final String name;
  final String section;
  final String type;
  const _ProposedAccount(this.name, this.section, this.type);
  String get key => '$name|$section';
}

class _FinanceAiBookkeeperScreenState extends State<FinanceAiBookkeeperScreen> {
  final OverlordBooksRoot _books = OverlordBooksRoot();
  final GeminiBookkeeperService _ai = GeminiBookkeeperService();

  bool _loading = true;
  bool _applying = false;
  String? _error;

  int _txnCount = 0;
  List<BookkeeperDecision> _decisions = [];
  // merchant(normalized) -> account name
  final Map<String, String> _merchantToAccount = {};
  List<_ProposedAccount> _newAccounts = [];

  // section name -> ref + which statement
  final Map<String, DocumentReference<Map<String, dynamic>>> _plSectionByName = {};
  final Map<String, DocumentReference<Map<String, dynamic>>> _bsSectionByName = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _runProposal());
  }

  String _norm(String s) => s.toLowerCase().trim();
  String _docKey(String s) =>
      s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_');

  Future<void> _runProposal() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final txnSnap = await _books.bankTransactions
          .where('reconciled', isEqualTo: false)
          .get();
      _txnCount = txnSnap.docs.length;
      if (_txnCount == 0) {
        setState(() => _loading = false);
        return;
      }

      // Distinct merchants (one representative per name).
      final merchants = <String, BookkeeperMerchant>{};
      for (final d in txnSnap.docs) {
        final data = d.data();
        final name = (data['merchantName'] ?? data['name'] ?? '').toString().trim();
        if (name.isEmpty) continue;
        merchants.putIfAbsent(name, () {
          final amount = (data['amount'] as num?)?.toDouble() ?? 0;
          return BookkeeperMerchant(
            name: name,
            isIncome: amount < 0,
            plaidCategory: data['category']?.toString(),
            plaidCategoryDetailed: data['categoryDetailed']?.toString(),
          );
        });
      }

      // Sections.
      final db = FirebaseFirestore.instance;
      final plSecs = await db.collection('companyProfitLossSection').get();
      final bsSecs = await db.collection('companyBalanceSheetSection').get();
      final plByPath = <String, String>{};
      for (final s in plSecs.docs) {
        final name = (s.data()['name'] ?? '').toString();
        _plSectionByName[name] = s.reference;
        plByPath[s.reference.path] = name;
      }
      final bsByPath = <String, String>{};
      for (final s in bsSecs.docs) {
        final name = (s.data()['name'] ?? '').toString();
        _bsSectionByName[name] = s.reference;
        bsByPath[s.reference.path] = name;
      }
      final sectionNames = [..._plSectionByName.keys, ..._bsSectionByName.keys];

      // Existing accounts (name, section, type).
      final acctSnap =
          await _books.accounts.where('active', isEqualTo: true).get();
      final existing = <BookkeeperAccount>[];
      for (final a in acctSnap.docs) {
        final data = a.data();
        final name = (data['name'] ?? '').toString();
        if (name.isEmpty) continue;
        final plRef = data['profitLossId'] as DocumentReference?;
        final bsRef = data['balanceSheetId'] as DocumentReference?;
        final section = plRef != null
            ? (plByPath[plRef.path] ?? 'Uncategorized')
            : bsRef != null
                ? (bsByPath[bsRef.path] ?? 'Uncategorized')
                : 'Uncategorized';
        existing.add(BookkeeperAccount(
          name: name,
          section: section,
          type: (data['type'] ?? '').toString(),
        ));
      }

      // One Gemini pass.
      final decisions = await _ai.propose(
        merchants: merchants.values.toList(),
        sectionNames: sectionNames,
        existingAccounts: existing,
      );

      _decisions = decisions;
      _merchantToAccount.clear();
      final newByKey = <String, _ProposedAccount>{};
      for (final d in decisions) {
        _merchantToAccount[_norm(d.merchant)] = d.accountName;
        if (d.isNew && d.section != null && d.section!.isNotEmpty) {
          final pa = _ProposedAccount(
              d.accountName, d.section!, d.type ?? 'Expense');
          newByKey[pa.key] = pa;
        }
      }
      _newAccounts = newByKey.values.toList()
        ..sort((a, b) => a.section.compareTo(b.section));

      setState(() => _loading = false);
    } catch (e) {
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _approveAndPost() async {
    setState(() => _applying = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      // 1. Create approved new accounts; map name -> ref.
      final acctColl = _books.accounts;
      final nameToRef = <String, DocumentReference<Map<String, dynamic>>>{};
      // existing accounts first
      final existingSnap = await acctColl.get();
      for (final a in existingSnap.docs) {
        final n = (a.data()['name'] ?? '').toString();
        if (n.isNotEmpty) nameToRef[_norm(n)] = a.reference;
      }
      // Translate the new account names into all supported locales so they
      // display localized everywhere.
      Map<String, Map<String, String>> translations = {};
      final newNames =
          _newAccounts.map((a) => a.name).toSet().toList();
      if (newNames.isNotEmpty) {
        try {
          translations =
              await GeminiTranslationService().translateNames(newNames);
        } catch (_) {
          translations = {};
        }
      }

      for (final pa in _newAccounts) {
        if (nameToRef.containsKey(_norm(pa.name))) continue; // already exists
        final plRef = _plSectionByName[pa.section];
        final bsRef = _bsSectionByName[pa.section];
        final isPL = plRef != null;
        final ref = acctColl.doc();
        await ref.set({
          'name': pa.name,
          'nameLocalized': translations[pa.name] ?? {'en': pa.name},
          'type': pa.type,
          'profitLoss': isPL,
          'balanceSheet': !isPL,
          'parentAccountId': null,
          if (isPL) 'profitLossId': plRef,
          if (!isPL && bsRef != null) 'balanceSheetId': bsRef,
          'balance': 0,
          'position': 999,
          'active': true,
          'createdAt': FieldValue.serverTimestamp(),
        });
        nameToRef[_norm(pa.name)] = ref;
      }

      final txnSnap = await _books.bankTransactions
          .where('reconciled', isEqualTo: false)
          .get();

      // 2. Resolve each distinct merchant to a canonical top-level `merchant`
      //    (cross-company registry, keyed by Plaid merchant_entity_id when
      //    available) + a per-books `vendor` that references it.
      final db = FirebaseFirestore.instance;
      final merchantMeta = <String, Map<String, dynamic>>{};
      for (final d in txnSnap.docs) {
        final data = d.data();
        final m =
            (data['merchantName'] ?? data['name'] ?? '').toString().trim();
        if (m.isEmpty) continue;
        merchantMeta.putIfAbsent(
            _norm(m),
            () => {
                  'name': m,
                  'entityId': (data['merchantEntityId'] ?? '').toString(),
                  'logo': (data['logoUrl'] ?? '').toString(),
                  'website': (data['website'] ?? '').toString(),
                });
      }
      final vendorByMerchant = <String, DocumentReference>{};
      final merchantByMerchant = <String, DocumentReference>{};
      for (final entry in merchantMeta.entries) {
        final norm = entry.key;
        final meta = entry.value;
        final entityId = meta['entityId'] as String;
        final mKey = _docKey(entityId.isNotEmpty ? 'eid_$entityId' : 'name_$norm');
        final merchantRef = db.collection('merchant').doc(mKey);
        await merchantRef.set({
          'name': meta['name'],
          'nameNormalized': norm,
          if (entityId.isNotEmpty) 'plaidMerchantEntityId': entityId,
          if ((meta['logo'] as String).isNotEmpty) 'logoUrl': meta['logo'],
          if ((meta['website'] as String).isNotEmpty) 'website': meta['website'],
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        merchantByMerchant[norm] = merchantRef;

        final vendorRef = _books.collection('vendor').doc(_docKey(norm));
        await vendorRef.set({
          'name': meta['name'],
          'merchantRef': merchantRef,
          'source': 'bank_import',
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        vendorByMerchant[norm] = vendorRef;
      }

      // 3. Assign every unreconciled transaction: account + vendor + merchant,
      //    and learn a merchant rule (with the vendor link).
      var assigned = 0;
      final rulesWritten = <String>{};
      for (final d in txnSnap.docs) {
        final data = d.data();
        final merchant =
            (data['merchantName'] ?? data['name'] ?? '').toString().trim();
        final accountName = _merchantToAccount[_norm(merchant)];
        if (accountName == null) continue;
        final accountRef = nameToRef[_norm(accountName)];
        if (accountRef == null) continue;
        final vendorRef = vendorByMerchant[_norm(merchant)];
        final merchantRef = merchantByMerchant[_norm(merchant)];
        await d.reference.update({
          'suggestedAccountId': accountRef,
          'categorizationSource': 'ai',
          'categorizationConfidence': 'high',
          if (vendorRef != null) 'vendorId': vendorRef,
          if (merchantRef != null) 'merchantId': merchantRef,
        });
        assigned++;
        final ruleKey =
            merchant.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_');
        if (merchant.isNotEmpty && !rulesWritten.contains(ruleKey)) {
          rulesWritten.add(ruleKey);
          await _books.categorizationRules.doc(ruleKey).set({
            'merchantName': merchant,
            'merchantNameNormalized': ruleKey,
            'accountRef': accountRef,
            if (vendorRef != null) 'vendorRef': vendorRef,
            'updatedAt': FieldValue.serverTimestamp(),
            'usageCount': FieldValue.increment(1),
          }, SetOptions(merge: true));
        }
      }

      // 3. Post everything that now has a suggestion.
      final categorizer = TransactionCategorizerService(books: _books);
      final posted = await categorizer.approveAllSuggested();

      if (!mounted) return;
      messenger.showSnackBar(SnackBar(
        duration: const Duration(seconds: 5),
        backgroundColor: Colors.green,
        content: Text(
            'Created ${_newAccounts.length} account(s), categorized $assigned '
            'and posted $posted transaction(s) to the ledger.'),
      ));
      Navigator.of(context).maybePop();
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(
        duration: const Duration(seconds: 6),
        content: Text('Bookkeeping failed: $e'),
      ));
    } finally {
      if (mounted) setState(() => _applying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      drawer: const UserDrawer(),
      body: StandardCanvas(
        child: SafeArea(
          top: true,
          bottom: false,
          child: Stack(
            children: [
              Positioned.fill(child: _buildBody()),
              const Positioned(left: 0, right: 0, top: 0, child: CanvasTopBookend()),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DetailsAppBar(title: 'AI Bookkeeper'),
          HomeNavBarAdapter(),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('AI is reviewing your transactions…'),
          ],
        ),
      );
    }
    if (_error != null) {
      return Center(child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text('Could not run the AI review:\n$_error',
            textAlign: TextAlign.center),
      ));
    }
    if (_txnCount == 0) {
      return const Center(child: Text('No transactions to categorize.'));
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Ready to post',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(
                    'AI reviewed $_txnCount transaction(s) across '
                    '${_decisions.length} merchant(s). It will reuse your '
                    'existing accounts and create ${_newAccounts.length} new '
                    'account(s) below. Approve to post everything to the ledger.'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (_newAccounts.isNotEmpty) ...[
          Text('New accounts to create',
              style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          ..._newAccounts.map((a) => Card(
                child: ListTile(
                  dense: true,
                  leading: const Icon(Icons.add_circle_outline),
                  title: Text(a.name),
                  subtitle: Text('${a.section} · ${a.type}'),
                ),
              )),
        ] else
          const Text('No new accounts needed — everything maps to your '
              'existing chart.'),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: _applying ? null : _approveAndPost,
          icon: _applying
              ? const SizedBox(
                  width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.check),
          label: Text(_applying ? 'Posting…' : 'Approve & Post'),
        ),
      ],
    );
  }
}
