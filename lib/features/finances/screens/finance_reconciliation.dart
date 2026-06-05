// finance_reconciliation.dart (admin / overlord)
//
// Reconciles the KleenOps platform's OWN bank feed against its top-level books.
// Reuses the shared reconciliation content + categorizer engine, pointed at an
// OverlordBooksRoot (top-level collections).

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kleenops_admin/app/routes.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/details_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/home_navbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/drawers/user_drawer.dart';
import 'package:kleenops_admin/common/utils/snackbar_service.dart';
import 'package:shared_widgets/containers/canvas_top_bookend.dart';
import 'package:shared_widgets/containers/standard_canvas.dart';
import 'package:shared_widgets/drawers/menu_drawer.dart';
import 'package:shared_widgets/finance/finance_books_root.dart';
import 'package:shared_widgets/finance/finance_reconciliation_content.dart';
import 'package:shared_widgets/finance/transaction_categorizer_service.dart';

class FinanceReconciliationScreen extends StatefulWidget {
  const FinanceReconciliationScreen({super.key});

  @override
  State<FinanceReconciliationScreen> createState() =>
      _FinanceReconciliationScreenState();
}

class _FinanceReconciliationScreenState
    extends State<FinanceReconciliationScreen> {
  // The platform/overlord's books live in top-level collections.
  final FinanceBooksRoot _books = OverlordBooksRoot();
  late final TransactionCategorizerService _categorizer =
      TransactionCategorizerService(books: _books);
  bool _categorizing = false;

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

  Future<void> _categorize() async {
    setState(() => _categorizing = true);
    try {
      final count = await _categorizer.categorizeUnreconciled();
      if (mounted) {
        SnackbarService.instance.showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 5),
            content: Text('Categorized $count transactions'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        SnackbarService.instance.showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 5),
            content: Text('Categorization error: $e'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _categorizing = false);
    }
  }

  Future<void> _approveAll() async {
    try {
      final count = await _categorizer.approveAllHighConfidence();
      if (mounted) {
        SnackbarService.instance.showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 5),
            backgroundColor: Colors.green,
            content: Text('Auto-approved $count high-confidence transactions'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        SnackbarService.instance.showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 5),
            content: Text('Error: $e'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: null,
      drawer: const UserDrawer(),
      body: _wrapCanvas(
        FinanceReconciliationContent(
          books: _books,
          categorizer: _categorizer,
          categorizing: _categorizing,
          onCategorize: _categorize,
          onApproveAll: _approveAll,
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
                icon: Icons.rule_outlined,
                label: 'Classify',
                onTap: () => context.push(AppRoutePaths.financeClassify),
              ),
              ContentMenuItem(
                icon: Icons.account_balance_outlined,
                label: 'Banking',
                onTap: () => context.push(AppRoutePaths.financeBanking),
              ),
              ContentMenuItem(
                icon: Icons.list_alt_outlined,
                label: 'Ledger',
                onTap: () => context.push(AppRoutePaths.financeLedger),
              ),
            ],
          );
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DetailsAppBar(
                title: 'Reconciliation',
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
