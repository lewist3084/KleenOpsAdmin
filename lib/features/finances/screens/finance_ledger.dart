//  finance_ledger.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:shared_widgets/search/search_control_strip.dart';
import 'package:shared_widgets/lists/standardView.dart';
import 'package:kleenops_admin/widgets/tiles/ledger_item.dart';
import 'package:kleenops_admin/features/auth/providers/auth_provider.dart';
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

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final companyAsync = ref.watch(companyIdProvider);
    final bool hideChrome = false;
    final bottomInset =
        (hideChrome ? 16.0 : kBottomNavigationBarHeight + 16.0) +
            MediaQuery.of(context).padding.bottom;

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

        final query = FirebaseFirestore.instance
            .collection('timeline')
            .where('timelineCategoryId', isEqualTo: categoryRef)
            .orderBy('createdAt', descending: true)
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
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: bottomInset),
                    child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: query,
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return Center(
                            child: Text('Error: ${snapshot.error}'),
                          );
                        }
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        final docs = snapshot.data?.docs ?? [];
                        final filtered = docs.where((doc) {
                          final data = doc.data();
                          final memo = (data['memo'] ?? data['name'] ?? '')
                              .toString()
                              .toLowerCase();
                          return memo.contains(_search.toLowerCase());
                        }).toList();

                        if (filtered.isEmpty) {
                          return Center(
                            child: Text(
                              _search.isEmpty
                                  ? 'No ledger entries.'
                                  : 'No entries match "$_search".',
                            ),
                          );
                        }

                        return StandardView<
                            QueryDocumentSnapshot<Map<String, dynamic>>>(
                          items: filtered,
                          groupBy: (doc) {
                            final ts = doc.data()['createdAt'] as Timestamp?;
                            if (ts == null) return 'Unknown';
                            return DateFormat('yMMMd').format(ts.toDate());
                          },
                          groupSort: (a, b) => b.compareTo(a),
                          headerIcon: null,
                          itemBuilder: (doc) {
                            final data = doc.data();
                            final objRef = data['companyObjectId']
                                as DocumentReference<Map<String, dynamic>>?;
                            final memo = data['memo'] ?? '';
                            return LedgerItem(
                              leadingIcon: Icons.list_alt,
                              companyObjectId: objRef,
                              memo: memo,
                            );
                          },
                        );
                      },
                    ),
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
