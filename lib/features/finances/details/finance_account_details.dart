// lib/features/finances/details/finance_account_details.dart
//
// Account detail: the account name + type (header), its current balance as a
// plain inline label inside a ContainerActionWidget, then a second
// ContainerActionWidget listing the account's ledger transactions with the same
// tile used on the Ledger — each tappable through to the entry detail (which has
// its own edit FAB for changing the debit/credit assignment).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import 'package:kleenops_admin/app/shared_widgets/navigation/details_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/home_navbar_adapter.dart';
import 'package:kleenops_admin/features/finances/forms/finance_account_form.dart';
import 'package:kleenops_admin/features/finances/details/ledger_entry_details.dart';
import 'package:kleenops_admin/app/shared_widgets/drawers/appbar_logout_adapter.dart';
import 'package:shared_widgets/containers/canvas_top_bookend.dart';
import 'package:shared_widgets/containers/container_action.dart';
import 'package:shared_widgets/containers/container_header.dart';
import 'package:shared_widgets/containers/standard_canvas.dart';
import 'package:shared_widgets/drawers/menu_drawer.dart';
import 'package:shared_widgets/finance/account_math.dart';
import 'package:shared_widgets/finance/finance_books_root.dart';
import 'package:shared_widgets/finance/ledger_entry_tile.dart';
import 'package:shared_widgets/labels/text_value_inline.dart';
import 'package:shared_widgets/lists/standardViewGroup.dart';

class FinanceAccountDetailsScreen extends StatelessWidget {
  final DocumentReference<Map<String, dynamic>> companyRef;
  final String docId;

  const FinanceAccountDetailsScreen({
    super.key,
    required this.companyRef,
    required this.docId,
  });

  Widget _wrapCanvas(Widget child) {
    return StandardCanvas(
      child: SafeArea(
        top: true,
        bottom: false,
        child: Stack(
          children: [
            Positioned.fill(child: child),
            const Positioned(
              left: 0, right: 0, top: 0,
              child: CanvasTopBookend(),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: null,
      drawer: const UserDrawer(),
      body: _wrapCanvas(
        _AccountDetailsContent(companyRef: companyRef, docId: docId),
      ),
      bottomNavigationBar: Consumer(
        builder: (context, ref, _) {
          final menuSections = MenuDrawerSections(
            actions: [
              ContentMenuItem(
                icon: Icons.edit_outlined,
                label: 'Edit Account',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => FinanceAccountForm(
                        companyRef: companyRef,
                        docId: docId,
                      ),
                    ),
                  );
                },
              ),
            ],
          );
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DetailsAppBar(
                title: 'Account Details',
                menuSections: menuSections,
              ),
              const HomeNavBarAdapter(),
            ],
          );
        },
      ),
    );
  }
}

class _AccountDetailsContent extends StatefulWidget {
  final DocumentReference<Map<String, dynamic>> companyRef;
  final String docId;

  const _AccountDetailsContent({
    required this.companyRef,
    required this.docId,
  });

  @override
  State<_AccountDetailsContent> createState() => _AccountDetailsContentState();
}

class _AccountDetailsContentState extends State<_AccountDetailsContent> {
  static final NumberFormat _money = NumberFormat.currency(symbol: '\$');

  Stream<DocumentSnapshot<Map<String, dynamic>>>? _accountStream;
  LedgerBalances _balances = LedgerBalances.empty;

  @override
  void initState() {
    super.initState();
    _loadBalances();
  }

  Future<void> _loadBalances() async {
    final balances = await LedgerBalances.load(OverlordBooksRoot());
    if (!mounted) return;
    setState(() => _balances = balances);
  }

  @override
  Widget build(BuildContext context) {
    final accountRef =
        FirebaseFirestore.instance.collection('account').doc(widget.docId);

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _accountStream ??= accountRef.snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final data = snap.data!.data() ?? {};
        final name = (data['name'] ?? 'Unnamed').toString();
        final type = (data['type'] ?? '').toString();
        // Computed from the posted ledger (the stored `balance` field is never
        // maintained); falls back to 0 while balances are still loading.
        final balance = _balances.balanceFor(accountRef.path) ??
            (data['balance'] as num?)?.toDouble() ??
            0.0;

        return SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 120),
          child: Column(
            children: [
              ContainerHeader(
                showImage: false,
                titleHeader: 'Account',
                title: name,
                descriptionHeader: 'Type',
                description: type.isEmpty ? '—' : type,
              ),
              ContainerActionWidget(
                actionText: '',
                content: TextValueInline(
                  header: 'Balance',
                  value: _money.format(balance),
                  icon: Icons.account_balance_wallet_outlined,
                  boldValue: true,
                  color: balance >= 0
                      ? Colors.green.shade700
                      : Colors.red.shade700,
                ),
              ),
              _AccountTransactions(
                accountRef: accountRef,
                balances: _balances,
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Lists the ledger entries that touch [accountRef] (on either the debit or the
/// credit side) using the shared ledger tile, grouped by date, inside a
/// ContainerActionWidget. Tapping an entry opens its detail screen.
class _AccountTransactions extends StatefulWidget {
  final DocumentReference<Map<String, dynamic>> accountRef;
  final LedgerBalances balances;

  const _AccountTransactions({
    required this.accountRef,
    required this.balances,
  });

  @override
  State<_AccountTransactions> createState() => _AccountTransactionsState();
}

class _AccountTransactionsState extends State<_AccountTransactions> {
  Stream<QuerySnapshot<Map<String, dynamic>>>? _debitStream;
  Stream<QuerySnapshot<Map<String, dynamic>>>? _creditStream;

  @override
  Widget build(BuildContext context) {
    final timeline = FirebaseFirestore.instance.collection('timeline');
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _debitStream ??= timeline
          .where('debitAccountId', isEqualTo: widget.accountRef)
          .orderBy('createdAt', descending: true)
          .limit(100)
          .snapshots(),
      builder: (context, debitSnap) {
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _creditStream ??= timeline
              .where('creditAccountId', isEqualTo: widget.accountRef)
              .orderBy('createdAt', descending: true)
              .limit(100)
              .snapshots(),
          builder: (context, creditSnap) {
            Widget content;
            if (debitSnap.hasError || creditSnap.hasError) {
              content = Text(
                'Couldn\'t load transactions: '
                '${debitSnap.error ?? creditSnap.error}',
              );
            } else if (!debitSnap.hasData || !creditSnap.hasData) {
              content = const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(),
                ),
              );
            } else {
              // Merge + de-dupe the two sides into one list (an entry can never
              // touch the same account on both sides, but de-dupe defensively).
              final seen = <String>{};
              final docs = [
                ...debitSnap.data!.docs,
                ...creditSnap.data!.docs,
              ].where((d) => seen.add(d.id)).toList();

              content = docs.isEmpty
                  ? const Text('No transactions found.')
                  : StandardViewGroup.buildViewFromDocs(
                      docs: docs,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      groupBy: (doc) {
                        final ts = doc.data()['createdAt'] as Timestamp?;
                        return ts == null
                            ? 'Undated'
                            : DateFormat('yMMMd').format(ts.toDate());
                      },
                      groupSort: (a, b) {
                        try {
                          return DateFormat('yMMMd')
                              .parse(b)
                              .compareTo(DateFormat('yMMMd').parse(a));
                        } catch (_) {
                          return b.compareTo(a);
                        }
                      },
                      itemSort: (a, b) {
                        final ta = a.data()['createdAt'] as Timestamp?;
                        final tb = b.data()['createdAt'] as Timestamp?;
                        if (ta == null || tb == null) return 0;
                        return tb.compareTo(ta);
                      },
                      onTap: (doc) => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => LedgerEntryDetailsScreen(
                            docId: doc.id,
                            data: doc.data(),
                            balances: widget.balances,
                          ),
                        ),
                      ),
                      itemBuilder: (doc) => LedgerEntryTile(
                        data: doc.data(),
                        balances: widget.balances,
                        entryId: doc.id,
                      ),
                    );
            }

            return ContainerActionWidget(
              title: 'Transactions',
              actionText: '',
              content: content,
            );
          },
        );
      },
    );
  }
}
