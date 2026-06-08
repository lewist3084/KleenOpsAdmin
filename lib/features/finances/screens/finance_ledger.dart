//  finance_ledger.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:shared_widgets/lists/standardViewGroup.dart';
import 'package:shared_widgets/theme/app_palette.dart';
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
  final Map<String, String> _accountNames = {}; // ref.path -> name
  final Map<String, String> _accountTypes = {}; // ref.path -> type

  @override
  void initState() {
    super.initState();
    _loadAccounts();
  }

  Future<void> _loadAccounts() async {
    final snap = await FirebaseFirestore.instance.collection('account').get();
    if (!mounted) return;
    setState(() {
      for (final d in snap.docs) {
        _accountNames[d.reference.path] = (d.data()['name'] ?? '').toString();
        _accountTypes[d.reference.path] = (d.data()['type'] ?? '').toString();
      }
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final companyAsync = ref.watch(companyIdProvider);
    final bottomInset =
        kBottomNavigationBarHeight + 16.0 + MediaQuery.of(context).padding.bottom;

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
                      if (_search.isEmpty) return true;
                      final d = doc.data();
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
                          accountNames: _accountNames,
                          accountTypes: _accountTypes,
                        ),
                      ),
                    ),
                    itemBuilder: (doc) => _ledgerEntryTile(context, doc.data()),
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

  Widget _ledgerEntryTile(BuildContext context, Map<String, dynamic> data) {
    final name = (data['name'] ?? data['memo'] ?? '(entry)').toString();
    final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
    final debit = (data['debitAccountId'] as DocumentReference?)?.path;
    final credit = (data['creditAccountId'] as DocumentReference?)?.path;
    final debitType = debit != null ? _accountTypes[debit] : null;
    final creditType = credit != null ? _accountTypes[credit] : null;
    final visual = profitabilityVisual(debitType, creditType);

    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
      // Gold (primary2) leading icon for every ledger entry.
      leading: Icon(Icons.receipt_long,
          color: AppPaletteScope.of(context).primary2),
      title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Row(
        children: [
          Icon(visual.icon, size: 14, color: visual.color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              visual.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: visual.color),
            ),
          ),
        ],
      ),
      trailing: Text(
        '\$${amount.toStringAsFixed(2)}',
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
    );
  }
}

/// Profitability-oriented visual for a double-entry ledger line. Translates
/// debit/credit account types into a plain-language "good/bad" arrow:
///   • income (revenue) up     → green up
///   • expense up               → red up
///   • debt (liability) paid down → green down
///   • debt up                  → red up
class LedgerVisual {
  final IconData icon;
  final Color color;
  final String label;
  const LedgerVisual(this.icon, this.color, this.label);
}

LedgerVisual profitabilityVisual(String? debitType, String? creditType) {
  final green = Colors.green.shade700;
  final red = Colors.red.shade700;
  if (creditType == 'Revenue') {
    return LedgerVisual(Icons.arrow_upward, green, 'Income up');
  }
  if (debitType == 'Expense') {
    return LedgerVisual(Icons.arrow_upward, red, 'Expense up');
  }
  if (debitType == 'Liability') {
    return LedgerVisual(Icons.arrow_downward, green, 'Debt paid down');
  }
  if (creditType == 'Liability') {
    return LedgerVisual(Icons.arrow_upward, red, 'Debt up');
  }
  return LedgerVisual(Icons.swap_horiz, Colors.grey.shade600, 'Transfer');
}
