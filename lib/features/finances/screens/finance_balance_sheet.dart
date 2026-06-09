import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kleenops_admin/features/auth/providers/auth_provider.dart';
import 'package:kleenops_admin/app/shared_widgets/search/search_control_strip_adapter.dart';
import 'package:shared_widgets/finance/finance_books_root.dart';
import 'package:shared_widgets/finance/profit_loss_statement.dart';
import 'package:kleenops_admin/features/finances/details/finance_account_details.dart';
import 'package:kleenops_admin/services/firebase_ai/gemini_translation_service.dart'
    show localizedAccountName;
import '../dialogs/add_child_account_dialog.dart';
import '../dialogs/add_account_dialog.dart';

/// Balance Sheet for the overlord (top-level) books — Assets, Liabilities and
/// Equity sections, each a collapsible group of accounts (with rolled-up
/// sub-account totals), rendered by [FinancialStatement].
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

  /// Bumped after an account is edited/added so FinancialStatement reloads.
  int _reload = 0;
  void _refresh() => setState(() => _reload++);

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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

        return Column(
          children: [
            if (widget.searchVisible)
              SearchControlStrip(
                controller: _searchController,
                hintText: 'Search Balance Sheet',
                onChanged: (_) {},
              ),
            Expanded(
              child: FinancialStatement(
                books: OverlordBooksRoot(),
                sectionCollection: 'companyBalanceSheetSection',
                flagField: 'balanceSheet',
                sectionIdField: 'balanceSheetId',
                reloadToken: _reload,
                nameOf: (data) => localizedAccountName(
                    data, Localizations.localeOf(context).toLanguageTag()),
                onAddAccount: (sectionRef) async {
                  await showAddAccountDialog(
                    context: context,
                    companyRef: companyRef,
                    balanceSheetRef: sectionRef,
                  );
                  _refresh();
                },
                onAddChild: (parentRef) async {
                  await showAddChildAccountDialog(
                    context: context,
                    companyRef: companyRef,
                    parentAccountRef: parentRef,
                  );
                  _refresh();
                },
                onTapAccount: (accountId) async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => FinanceAccountDetailsScreen(
                        companyRef: companyRef,
                        docId: accountId,
                      ),
                    ),
                  );
                  _refresh();
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
