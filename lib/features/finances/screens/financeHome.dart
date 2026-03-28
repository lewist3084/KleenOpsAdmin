//  financeHome.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kleenops_admin/app/routes.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/menu_button_block_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/details_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/home_navbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/home_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/drawers/appbar_logout_adapter.dart';
import 'package:shared_widgets/containers/canvas_top_bookend.dart';
import 'package:shared_widgets/containers/standard_canvas.dart';
import 'package:shared_widgets/drawers/menu_drawer.dart';

/// Top-level screen with its own Scaffold (app bar + content + bottom nav)
class FinancesHomeScreen extends StatelessWidget {
  const FinancesHomeScreen({super.key});

  Widget _wrapCanvas(Widget child) {
    return StandardCanvas(
      child: SafeArea(
        top: true,
        bottom: false,
        child: Stack(
          children: [
            Positioned.fill(child: child),
            const Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: CanvasTopBookend(),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool hideChrome = false;

    Widget buildBottomBar({
      VoidCallback? onAiPressed,
      MenuDrawerSections? menuSections,
    }) {
      if (hideChrome) return const SizedBox.shrink();
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DetailsAppBar(
            title: 'Finances',
            onAiPressed: onAiPressed,
            menuSections: menuSections,
          ),
          const HomeNavBarAdapter(),
        ],
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: null,
      drawer: const UserDrawer(),
      body: _wrapCanvas(
          const FinanceHomeContent(),
      ),
      bottomNavigationBar: Consumer(
        builder: (context, ref, _) {
          final menuSections = MenuDrawerSections(
            actions: [
              ContentMenuItem(
                icon: Icons.people_outline,
                label: 'Customers',
                onTap: () => context.push(AppRoutePaths.financeCustomers),
              ),
              ContentMenuItem(
                icon: Icons.receipt_long_outlined,
                label: 'Invoices',
                onTap: () => context.push(AppRoutePaths.financeInvoices),
              ),
              ContentMenuItem(
                icon: Icons.request_quote_outlined,
                label: 'Bills',
                onTap: () => context.push(AppRoutePaths.financeBills),
              ),
              ContentMenuItem(
                icon: Icons.payments_outlined,
                label: 'Payments',
                onTap: () => context.push(AppRoutePaths.financePayments),
              ),
              ContentMenuItem(
                icon: Icons.account_balance_wallet_outlined,
                label: 'Payroll',
                onTap: () => context.push(AppRoutePaths.financePayroll),
              ),
              ContentMenuItem(
                icon: Icons.account_balance_outlined,
                label: 'Link Bank Account',
                onTap: () => context.push(AppRoutePaths.financeBanking),
              ),
              ContentMenuItem(
                icon: Icons.receipt_long_outlined,
                label: 'Billing',
                onTap: () => context.push(AppRoutePaths.billing),
              ),
              ContentMenuItem(
                icon: Icons.bar_chart_outlined,
                label: 'Stats',
                onTap: () => context.push(AppRoutePaths.financeStats),
              ),
              ContentMenuItem(
                icon: Icons.rocket_launch_outlined,
                label: 'Finance Setup Wizard',
                onTap: () => context.push(AppRoutePaths.financeSetupWizard),
              ),
            ],
          );
          return buildBottomBar(
            menuSections: menuSections,
          );
        },
      ),
    );
  }
}

class FinanceHomeContent extends StatelessWidget {
  const FinanceHomeContent({super.key}); // Added const constructor with Key

  @override
  Widget build(BuildContext context) {
    final bool hideChrome = false;
    final bottomInset =
        (hideChrome ? 16.0 : kBottomNavigationBarHeight + 16.0) +
            MediaQuery.of(context).padding.bottom;

    return SingleChildScrollView(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image or banner
          Container(
            width: double.infinity,
            color: Colors.white,
            padding: const EdgeInsets.only(top: 16.0),
            child: Center(
              child: Image.asset(
                'assets/sax.png',
                height: MediaQuery.of(context).size.height * 0.3,
                fit: BoxFit.contain,
              ),
            ),
          ),
          const MenuButtonBlock(), // Marked as const for consistency
        ],
      ),
    );
  }
}
