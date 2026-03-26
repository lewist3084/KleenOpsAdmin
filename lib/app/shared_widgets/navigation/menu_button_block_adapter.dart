// Kleenops Admin adapter for the shared MenuButtonBlock.
// In admin, all access flags are set to true since the user is a platform admin.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kleenops_admin/app/routes.dart';
import 'package:shared_widgets/buttons/menu_button_block.dart' as shared;

class MenuButtonBlock extends ConsumerWidget {
  const MenuButtonBlock({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final configs = <shared.MenuButtonConfig>[
      shared.MenuButtonConfig(
        id: 'Customers',
        label: 'Customers',
        icon: Icons.people_outlined,
        accessFlagKey: 'customers',
        onPressed: (ctx) => ctx.go(AppRoutePaths.financeCustomers),
      ),
      shared.MenuButtonConfig(
        id: 'Invoices',
        label: 'Invoices',
        icon: Icons.receipt_long_outlined,
        accessFlagKey: 'invoices',
        onPressed: (ctx) => ctx.go(AppRoutePaths.financeInvoices),
      ),
      shared.MenuButtonConfig(
        id: 'Bills',
        label: 'Bills',
        icon: Icons.request_quote_outlined,
        accessFlagKey: 'bills',
        onPressed: (ctx) => ctx.go(AppRoutePaths.financeBills),
      ),
      shared.MenuButtonConfig(
        id: 'Payments',
        label: 'Payments',
        icon: Icons.payments_outlined,
        accessFlagKey: 'payments',
        onPressed: (ctx) => ctx.go(AppRoutePaths.financePayments),
      ),
      shared.MenuButtonConfig(
        id: 'Ledger',
        label: 'Ledger',
        icon: Icons.list_alt_outlined,
        accessFlagKey: 'ledger',
        onPressed: (ctx) => ctx.go(AppRoutePaths.financeLedger),
      ),
      shared.MenuButtonConfig(
        id: 'Accounts',
        label: 'Accounts',
        icon: Icons.account_tree_outlined,
        accessFlagKey: 'accounts',
        onPressed: (ctx) => ctx.go(AppRoutePaths.financeAccounts),
      ),
      shared.MenuButtonConfig(
        id: 'Payroll',
        label: 'Payroll',
        icon: Icons.account_balance_wallet_outlined,
        accessFlagKey: 'payroll',
        onPressed: (ctx) => ctx.go(AppRoutePaths.financePayroll),
      ),
      shared.MenuButtonConfig(
        id: 'Banking',
        label: 'Banking',
        icon: Icons.account_balance_outlined,
        accessFlagKey: 'banking',
        onPressed: (ctx) => ctx.go(AppRoutePaths.financeBanking),
      ),
      shared.MenuButtonConfig(
        id: 'Stats',
        label: 'Stats',
        icon: Icons.bar_chart_outlined,
        accessFlagKey: 'stats',
        onPressed: (ctx) => ctx.go(AppRoutePaths.financeStats),
      ),
    ];

    // Admin gets all access flags set to true.
    final adminAccessStream = Stream.value(<String, dynamic>{
      for (final c in configs) c.accessFlagKey: true,
    });

    return shared.MenuButtonBlock(
      userDataStream: adminAccessStream,
      configs: configs,
      padding: const EdgeInsets.all(16),
      emptyLabel: 'No finance apps available.',
    );
  }
}
