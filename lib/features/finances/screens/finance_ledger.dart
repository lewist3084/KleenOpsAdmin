//  finance_ledger.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:shared_widgets/lists/standardViewGroup.dart';
import 'package:shared_widgets/finance/account_math.dart';
import 'package:shared_widgets/finance/finance_books_root.dart';
import 'package:shared_widgets/finance/ledger_duplicates.dart';
import 'package:shared_widgets/finance/ledger_entry_tile.dart';
import 'package:kleenops_admin/app/routes.dart' show AppRoutePaths;
import 'package:go_router/go_router.dart';
import 'package:kleenops_admin/app/shared_widgets/search/search_control_strip_adapter.dart';
import 'package:kleenops_admin/features/auth/providers/auth_provider.dart';
import 'package:kleenops_admin/features/finances/details/ledger_entry_details.dart';
import '../forms/finance_ledger_form.dart';

class FinanceLedgerContent extends ConsumerStatefulWidget {
  const FinanceLedgerContent({super.key, this.searchVisible = false});

  final bool searchVisible;

  @override
  _FinanceLedgerContentState createState() => _FinanceLedgerContentState();
}

class _FinanceLedgerContentState extends ConsumerState<FinanceLedgerContent> {
  String _search = '';
  final TextEditingController _searchCtrl = TextEditingController();
  LedgerBalances _balances = LedgerBalances.empty;

  /// doc id → `'high'`/`'medium'` for entries that look like a duplicate of
  /// another. Computed once on open; drives the list-row duplicate badge.
  Map<String, String> _dupConfidenceById = {};

  @override
  void initState() {
    super.initState();
    _loadBalances();
    _loadDuplicateFlags();
  }

  Future<void> _loadBalances() async {
    final balances = await LedgerBalances.load(OverlordBooksRoot());
    if (!mounted) return;
    setState(() => _balances = balances);
  }

  /// Scans the posted ledger once and records which entries look like the same
  /// money recorded twice, so the list can badge them without a per-row query.
  /// Uses the shared [scanLedgerDuplicates] scan (same matcher as the detail
  /// screen, the server observer, and the cleanup script).
  Future<void> _loadDuplicateFlags() async {
    final fs = FirebaseFirestore.instance;
    final categoryRef = fs
        .collection('timelineCategory')
        .doc('jlXgbQiOKD3VjWd7AztM');
    QuerySnapshot<Map<String, dynamic>> snap;
    try {
      snap = await fs
          .collection('timeline')
          .where('timelineCategoryId', isEqualTo: categoryRef)
          .get();
    } catch (_) {
      return;
    }

    final confidence = scanLedgerDuplicates(
      snap.docs.map((d) => MapEntry(d.id, d.data())),
    );

    if (!mounted) return;
    setState(() => _dupConfidenceById = confidence);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final companyAsync = ref.watch(companyIdProvider);
    const bottomInset = 16.0;

    return companyAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (companyRef) {
        if (companyRef == null) {
          return const Center(child: Text('No company found.'));
        }

        final categoryRef = FirebaseFirestore.instance
            .collection('timelineCategory')
            .doc('jlXgbQiOKD3VjWd7AztM');

        final postedQuery = FirebaseFirestore.instance
            .collection('timeline')
            .where('timelineCategoryId', isEqualTo: categoryRef)
            .orderBy('createdAt', descending: true)
            .snapshots();

        final uncategorizedQuery = FirebaseFirestore.instance
            .collection('bankTransaction')
            .where('reconciled', isEqualTo: false)
            .orderBy('date', descending: true)
            .snapshots();

        return Stack(
          children: [
            Column(
              children: [
                if (widget.searchVisible)
                  SearchControlStrip(
                    controller: _searchCtrl,
                    hintText: 'Search Ledger',
                    onChanged: (t) => setState(() => _search = t.trim()),
                  ),
                // Uncategorized banner (raw imports awaiting AI categorization).
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: uncategorizedQuery,
                  builder: (context, snap) {
                    final n = snap.data?.docs.length ?? 0;
                    if (n == 0) return const SizedBox.shrink();
                    return Container(
                      width: double.infinity,
                      color: Colors.orange.shade50,
                      padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '$n imported transaction(s) awaiting categorization',
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                          FilledButton.icon(
                            onPressed: () => context
                                .push(AppRoutePaths.financeAiBookkeeper),
                            icon: const Icon(Icons.auto_awesome_outlined, size: 18),
                            label: const Text('Categorize with AI'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                Expanded(
                  child: StandardViewGroup(
                    queryStream: postedQuery,
                    padding: EdgeInsets.only(bottom: bottomInset),
                    emptyMessage: _search.isEmpty
                        ? 'No ledger entries.'
                        : 'No entries match "$_search".',
                    itemFilter: (doc) {
                      final d = doc.data();
                      // Voided entries (e.g. confirmed duplicates) are hidden
                      // from the ledger and excluded from balances.
                      if (d['voided'] == true) return false;
                      if (_search.isEmpty) return true;
                      final s = (d['name'] ?? d['memo'] ?? '')
                          .toString()
                          .toLowerCase();
                      return s.contains(_search.toLowerCase());
                    },
                    groupBy: (doc) {
                      final ts = doc.data()['createdAt'] as Timestamp?;
                      if (ts == null) return 'Undated';
                      return DateFormat('yMMMd').format(ts.toDate());
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
                    groupCollapsible: true,
                    initialGroupExpanded: true,
                    onTap: (doc) => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => LedgerEntryDetailsScreen(
                          docId: doc.id,
                          data: doc.data(),
                          balances: _balances,
                        ),
                      ),
                    ),
                    itemBuilder: (doc) => LedgerEntryTile(
                        data: doc.data(),
                        balances: _balances,
                        entryId: doc.id,
                        duplicateConfidence: _dupConfidenceById[doc.id]),
                  ),
                ),
              ],
            ),
            Positioned(
              right: 16,
              bottom: 16,
              child: FloatingActionButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => FinanceLedgerForm(companyId: companyRef),
                    ),
                  );
                },
                child: const Icon(Icons.add),
              ),
            ),
          ],
        );
      },
    );
  }
}
