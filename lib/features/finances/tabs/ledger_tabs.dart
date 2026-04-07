// ledger_tabs.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kleenops_admin/features/finances/screens/finance_ledger.dart';
import 'package:kleenops_admin/features/finances/screens/finance_profit_loss.dart';
import 'package:kleenops_admin/features/finances/screens/finance_balance_sheet.dart';
import 'package:kleenops_admin/app/routes.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/details_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/home_navbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/home_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/drawers/appbar_logout_adapter.dart';
import 'package:shared_widgets/containers/canvas_top_bookend.dart';
import 'package:shared_widgets/containers/standard_canvas.dart';
import 'package:shared_widgets/drawers/menu_drawer.dart';
import 'package:shared_widgets/tabs/standard_tab.dart';

/// Top-level screen with its own Scaffold (app bar + content + bottom nav)
class FinanceLedgerTabsScreen extends StatelessWidget {
  const FinanceLedgerTabsScreen({super.key});

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
            title: 'Ledger',
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
          const FinanceLedgerTabs(),
      ),
      bottomNavigationBar: Consumer(
        builder: (context, ref, _) {
          final menuSections = MenuDrawerSections(
            actions: [
              ContentMenuItem(
                icon: Icons.home_outlined,
                label: 'Finances Home',
                onTap: () => context.push(AppRoutePaths.financeHome),
              ),
              ContentMenuItem(
                icon: Icons.account_balance_outlined,
                label: 'Accounts',
                onTap: () => context.push(AppRoutePaths.financeAccounts),
              ),
              ContentMenuItem(
                icon: Icons.bar_chart_outlined,
                label: 'Stats',
                onTap: () => context.push(AppRoutePaths.financeStats),
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

class FinanceLedgerTabs extends ConsumerStatefulWidget {
  const FinanceLedgerTabs({super.key});

  @override
  _FinanceLedgerTabsState createState() => _FinanceLedgerTabsState();
}

class _FinanceLedgerTabsState extends ConsumerState<FinanceLedgerTabs>
    with SingleTickerProviderStateMixin {
  late TabController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool hideChrome = false;
    final bottomInset =
        (hideChrome ? 16.0 : kBottomNavigationBarHeight + 16.0) +
            MediaQuery.of(context).padding.bottom;

    return Column(
      children: [
        Container(
          color: Colors.white,
          child: StandardTabBar(
            controller: _ctrl,
            isScrollable: true,
            dividerColor: Colors.grey[300],
            indicatorColor: Theme.of(context).primaryColor,
            indicatorWeight: 3.0,
            labelColor: Colors.black,
            unselectedLabelColor: Colors.grey[600],
            tabs: const [
              Tab(text: 'Ledger'),
              Tab(text: 'Profit and Loss'),
              Tab(text: 'Balance Sheet'),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: bottomInset),
            child: TabBarView(
              physics: const NeverScrollableScrollPhysics(),
              controller: _ctrl,
              children: const [
                FinanceLedgerContent(),
                FinanceProfitLossContent(),
                FinanceBalanceSheetContent(),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
