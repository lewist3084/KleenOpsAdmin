import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:kleenops_admin/features/auth/providers/auth_provider.dart';
import 'package:kleenops_admin/app/shared_widgets/search/search_control_strip_adapter.dart';
import 'package:shared_widgets/lists/standardViewGroup.dart';
import 'package:kleenops_admin/widgets/tiles/account_item.dart';
import 'package:shared_widgets/services/firestore_service.dart';
import '../dialogs/add_child_account_dialog.dart';
import '../dialogs/add_account_dialog.dart';

/// Displays the Balance Sheet sections for the current company.
///
/// Sections come from the `companyBalanceSheetSection` subcollection under the
/// current `company` document. Each section document contains:
///   - `name`     : String (section title)
///   - `position` : int    (order in the statement)
///   - `active`   : bool   (only active sections are shown)
class FinanceBalanceSheetContent extends ConsumerStatefulWidget {
  const FinanceBalanceSheetContent({super.key, this.searchVisible = false});

  final bool searchVisible;

  @override
  ConsumerState<FinanceBalanceSheetContent> createState() =>
      _FinanceBalanceSheetContentState();
}

class _FinanceBalanceSheetContentState
    extends ConsumerState<FinanceBalanceSheetContent> {
  final TextEditingController _searchController = TextEditingController();

  static final FirestoreService _fs = FirestoreService();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<double> _calcAccountTotal({
    required DocumentReference<Map<String, dynamic>> companyRef,
    required DocumentReference<Map<String, dynamic>> accountRef,
  }) async {
    final categoryRef = FirebaseFirestore.instance
        .collection('timelineCategory')
        .doc('jlXgbQiOKD3VjWd7AztM');

    double total = 0.0;

    // Sum debit entries
    final debitSnap = await FirebaseFirestore.instance
        .collection('timeline')
        .where('timelineCategoryId', isEqualTo: categoryRef)
        .where('debitAccountId', isEqualTo: accountRef)
        .get();
    for (final d in debitSnap.docs) {
      total += (d.data()['amount'] as num?)?.toDouble() ?? 0.0;
    }

    // Sum credit entries
    final creditSnap = await FirebaseFirestore.instance
        .collection('timeline')
        .where('timelineCategoryId', isEqualTo: categoryRef)
        .where('creditAccountId', isEqualTo: accountRef)
        .get();
    for (final d in creditSnap.docs) {
      total += (d.data()['amount'] as num?)?.toDouble() ?? 0.0;
    }

    return total;
  }

  Widget _buildAccountItem({
    required BuildContext context,
    required DocumentReference<Map<String, dynamic>> companyRef,
    required QueryDocumentSnapshot<Map<String, dynamic>> doc,
    double indent = 0.0,
  }) {
    final data = doc.data();
    final name = data['name'] ?? '';
    final accountRef = doc.reference;

    final childrenQuery = FirebaseFirestore.instance
        .collection('account')
        .where('parentAccountId', isEqualTo: accountRef)
        .where('balanceSheet', isEqualTo: true)
        .orderBy('position');

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: childrenQuery.snapshots(),
      builder: (context, childSnap) {
        final childDocs = childSnap.data?.docs ?? [];
        final children = childDocs
            .map((d) => Padding(
                  padding: const EdgeInsets.only(left: 16.0),
                  child: _buildAccountItem(
                    context: context,
                    companyRef: companyRef,
                    doc: d,
                    indent: indent + 16.0,
                  ),
                ))
            .toList();

        return FutureBuilder<double>(
          future: _calcAccountTotal(
            companyRef: companyRef,
            accountRef: accountRef,
          ),
          builder: (context, snap) {
            final amount = snap.data ?? 0.0;
            final amtText = "\$${amount.toStringAsFixed(2)}";
            return Padding(
              padding: EdgeInsets.only(left: indent),
              child: AccountItem(
                leadingicon: Icons.account_balance_wallet_outlined,
                leadingiconAction: () => showAddChildAccountDialog(
                  context: context,
                  companyRef: companyRef,
                  parentAccountRef: accountRef,
                ),
                text: name,
                secondText: amtText,
                hasChildren: childDocs.isNotEmpty,
                initiallyExpanded: childDocs.isNotEmpty,
                children: children,
              ),
            );
          },
        );
      },
    );
  }

  Future<double> _calcSectionTotal({
    required DocumentReference<Map<String, dynamic>> companyRef,
    required DocumentReference<Map<String, dynamic>> sectionRef,
  }) async {
    final accountSnap = await FirebaseFirestore.instance
        .collection('account')
        .where('balanceSheet', isEqualTo: true)
        .where('balanceSheetId', isEqualTo: sectionRef)
        .get();

    final totals = await Future.wait<double>(
      accountSnap.docs.map(
        (doc) => _calcAccountTotal(
          companyRef: companyRef,
          accountRef: doc.reference,
        ),
      ),
    );

    return totals.fold<double>(0.0, (sum, val) => sum + val);
  }

  @override
  Widget build(BuildContext context) {
    final companyAsync = ref.watch(companyIdProvider);

    return companyAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (companyRef) {
        if (companyRef == null) {
          return const Center(child: Text('No company found.'));
        }

        final sectionsFuture = FirebaseFirestore.instance
            .collection('companyBalanceSheetSection')
            .where('active', isEqualTo: true)
            .get();

        return FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
          future: sectionsFuture,
          builder: (context, sectionSnap) {
            final Widget searchField = widget.searchVisible
                ? SearchControlStrip(
                    controller: _searchController,
                    hintText: 'Search Balance Sheet',
                    onChanged: (_) {},
                  )
                : const SizedBox.shrink();

            Widget body;
            if (sectionSnap.connectionState == ConnectionState.waiting) {
              body = const Center(child: CircularProgressIndicator());
            } else if (sectionSnap.hasError) {
              body = Center(child: Text('Error: ${sectionSnap.error}'));
            } else {
              final posByPath = <String, int>{};
              for (final doc in sectionSnap.data?.docs ?? []) {
                final pos = doc.data()['position'] as int? ?? 0;
                posByPath[doc.reference.path] = pos;
              }

              // Only accounts flagged for the Balance Sheet are displayed.
              final query = FirebaseFirestore.instance
                  .collection('account')
                  .where('balanceSheet', isEqualTo: true)
                  .where('parentAccountId', isNull: true)
                  .orderBy('position');

              body = StandardViewGroup(
                queryStream: query.snapshots(),
                groupBy: (doc) =>
                    doc.data()['balanceSheetId'] as DocumentReference?,
                itemSort: (a, b) {
                  final posA = (a.data()['position'] as num?) ?? 0;
                  final posB = (b.data()['position'] as num?) ?? 0;
                  return posA.compareTo(posB);
                },
                groupSort: (a, b) {
                  final p1 = posByPath[a] ?? 0;
                  final p2 = posByPath[b] ?? 0;
                  return p1.compareTo(p2);
                },
                headerIcon: null,
                headerLeadingBuilder: (key) {
                  if (key is DocumentReference<Map<String, dynamic>>) {
                    return IconButton(
                      icon: const Icon(Icons.account_balance_wallet_outlined, size: 18),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => showAddAccountDialog(
                        context: context,
                        companyRef: companyRef,
                        balanceSheetRef: key,
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
                headerTrailingBuilder: (key) {
                  if (key is DocumentReference<Map<String, dynamic>>) {
                    return FutureBuilder<double>(
                      future: _calcSectionTotal(
                        companyRef: companyRef,
                        sectionRef: key,
                      ),
                      builder: (context, snap) {
                        final amt = snap.data ?? 0.0;
                        final amtText = "\$${amt.toStringAsFixed(2)}";
                        return Text(
                          amtText,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        );
                      },
                    );
                  }
                  return const SizedBox.shrink();
                },
                itemBuilder: (doc) {
                  return _buildAccountItem(
                    context: context,
                    companyRef: companyRef,
                    doc: doc,
                  );
                },
              );
            }

            return Column(
              children: [
                searchField,
                Expanded(child: body),
              ],
            );
          },
        );
      },
    );
  }
}

