// finance_classify_transactions.dart (admin / overlord)
//
// Per-transaction review/classify for the KleenOps platform's OWN top-level
// books. Hosts the shared classify content with an OverlordBooksRoot. "New
// account" routes to the admin add-account dialog (which writes the top-level
// `account` collection = the overlord books root). AI suggestions are not wired
// here yet (no admin-side classifier service).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kleenops_admin/app/routes.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/details_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/home_navbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/drawers/user_drawer.dart';
import 'package:kleenops_admin/features/auth/providers/auth_provider.dart';
import 'package:kleenops_admin/features/finances/dialogs/add_account_dialog.dart';
import 'package:shared_widgets/containers/canvas_top_bookend.dart';
import 'package:shared_widgets/containers/standard_canvas.dart';
import 'package:shared_widgets/drawers/menu_drawer.dart';
import 'package:shared_widgets/finance/finance_books_root.dart';
import 'package:shared_widgets/finance/finance_classify_content.dart';
import 'package:shared_widgets/finance/transaction_categorizer_service.dart';

class FinanceClassifyTransactionsScreen extends ConsumerStatefulWidget {
  const FinanceClassifyTransactionsScreen({super.key});

  @override
  ConsumerState<FinanceClassifyTransactionsScreen> createState() =>
      _FinanceClassifyTransactionsScreenState();
}

class _FinanceClassifyTransactionsScreenState
    extends ConsumerState<FinanceClassifyTransactionsScreen> {
  final FinanceBooksRoot _books = OverlordBooksRoot();
  late final TransactionCategorizerService _categorizer =
      TransactionCategorizerService(books: _books);

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
    final companyAsync = ref.watch(companyIdProvider);
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: null,
      drawer: const UserDrawer(),
      body: _wrapCanvas(
        FinanceClassifyContent(
          books: _books,
          categorizer: _categorizer,
          onCreateAccount: (ctx) async {
            final companyRef = companyAsync.asData?.value;
            if (companyRef == null) return;
            await showAddAccountDialog(context: ctx, companyRef: companyRef);
          },
        ),
      ),
      bottomNavigationBar: Builder(
        builder: (context) {
          final menuSections = MenuDrawerSections(
            actions: [
              ContentMenuItem(
                icon: Icons.home_outlined,
                label: 'Finances Home',
                onTap: () => context.push(AppRoutePaths.financeHome),
              ),
              ContentMenuItem(
                icon: Icons.fact_check_outlined,
                label: 'Reconciliation',
                onTap: () => context.push(AppRoutePaths.financeReconciliation),
              ),
              ContentMenuItem(
                icon: Icons.account_balance_outlined,
                label: 'Banking',
                onTap: () => context.push(AppRoutePaths.financeBanking),
              ),
            ],
          );
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DetailsAppBar(
                title: 'Classify Transactions',
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
