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

/// Profit & Loss statement for the overlord (top-level) books.
///
/// Account-group sections (Revenue, COGS, Operating Expenses, Other Income/
/// Expenses) hold accounts; the subtotal/total sections (Gross Profit,
/// Operating Income/EBIT, Net Income Before Tax, Net Income) are computed
/// running totals rendered by [ProfitLossStatement].
class FinanceProfitLossContent extends ConsumerStatefulWidget {
  const FinanceProfitLossContent({super.key, this.searchVisible = false});

  final bool searchVisible;

  @override
  ConsumerState<FinanceProfitLossContent> createState() =>
      _FinanceProfitLossContentState();
}

class _FinanceProfitLossContentState
    extends ConsumerState<FinanceProfitLossContent> {
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
                hintText: 'Search Profit & Loss',
                onChanged: (_) {},
              ),
            Expanded(
              child: FinancialStatement(
                books: OverlordBooksRoot(),
                sectionCollection: 'companyProfitLossSection',
                flagField: 'profitLoss',
                sectionIdField: 'profitLossId',
                showSubtotals: true,
                reloadToken: _reload,
                nameOf: (data) => localizedAccountName(
                    data, Localizations.localeOf(context).toLanguageTag()),
                onAddAccount: (sectionRef) async {
                  await showAddAccountDialog(
                    context: context,
                    companyRef: companyRef,
                    profitLossRef: sectionRef,
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
