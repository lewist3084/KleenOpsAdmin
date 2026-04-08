// Adapter that feeds Kleenops Admin routing into the shared HomeNavBar widget.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kleenops_admin/app/router.dart' show goRouterProvider, rootNavigatorKey;
import 'package:kleenops_admin/app/routes.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/section_resolver.dart';
import 'package:shared_widgets/navigation/home_navbar.dart';

class HomeNavBarAdapter extends ConsumerWidget {
  final bool highlightSelected;
  final bool forceDetail;

  const HomeNavBarAdapter({
    super.key,
    this.highlightSelected = true,
    this.forceDetail = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(goRouterProvider);
    return HomeNavBar(
      navConfig: _navConfig,
      sectionResolver: resolveAppSection,
      forceDetail: forceDetail || !highlightSelected,
      rootNavigatorKey: rootNavigatorKey,
      router: router,
    );
  }
}

// Navigation pattern:
// - "Home" ALWAYS returns to the main dashboard MenuButtonBlock (AppRoutePaths.dashboard)
// - Each section gets ~3-4 content-specific nav items
// - Deeper organization happens via StandardTab widgets within those screens
const HomeNavConfig _navConfig = {
  'dashboard': [
    HomeNavItem(label: 'Home', icon: Icons.home, route: AppRoutePaths.dashboard),
  ],
  'hr': [
    HomeNavItem(label: 'Home', icon: Icons.home, route: AppRoutePaths.dashboard),
    HomeNavItem(label: 'Employees', icon: Icons.badge, route: AppRoutePaths.hrEmployees),
    HomeNavItem(label: 'Team', icon: Icons.group, route: AppRoutePaths.hrTeam),
    HomeNavItem(label: 'Time Off', icon: Icons.calendar_month, route: AppRoutePaths.hrTimeOff),
    HomeNavItem(label: 'Stats', icon: Icons.bar_chart, route: AppRoutePaths.hrStats),
  ],
  'sales': [
    HomeNavItem(label: 'Home', icon: Icons.home, route: AppRoutePaths.dashboard),
    HomeNavItem(label: 'Sales', icon: Icons.sell, route: AppRoutePaths.salesSales),
    HomeNavItem(label: 'Marketing', icon: Icons.markunread_mailbox, route: AppRoutePaths.salesMarketing),
    HomeNavItem(label: 'Users', icon: Icons.people, route: AppRoutePaths.users),
    HomeNavItem(label: 'Stats', icon: Icons.bar_chart, route: AppRoutePaths.salesStats),
  ],
  'aiUsage': [
    HomeNavItem(label: 'Home', icon: Icons.home, route: AppRoutePaths.dashboard),
    HomeNavItem(label: 'Sales', icon: Icons.sell, route: AppRoutePaths.salesSales),
    HomeNavItem(label: 'AI Usage', icon: Icons.smart_toy, route: AppRoutePaths.aiUsage),
    HomeNavItem(label: 'Stats', icon: Icons.bar_chart, route: AppRoutePaths.salesStats),
  ],
  'storage': [
    HomeNavItem(label: 'Home', icon: Icons.home, route: AppRoutePaths.dashboard),
    HomeNavItem(label: 'Sales', icon: Icons.sell, route: AppRoutePaths.salesSales),
    HomeNavItem(label: 'Storage', icon: Icons.cloud, route: AppRoutePaths.storage),
    HomeNavItem(label: 'Stats', icon: Icons.bar_chart, route: AppRoutePaths.salesStats),
  ],
  'users': [
    HomeNavItem(label: 'Home', icon: Icons.home, route: AppRoutePaths.dashboard),
    HomeNavItem(label: 'Sales', icon: Icons.sell, route: AppRoutePaths.salesSales),
    HomeNavItem(label: 'Users', icon: Icons.people, route: AppRoutePaths.users),
    HomeNavItem(label: 'Stats', icon: Icons.bar_chart, route: AppRoutePaths.salesStats),
  ],
  'purchasing': [
    HomeNavItem(label: 'Home', icon: Icons.home, route: AppRoutePaths.dashboard),
    HomeNavItem(label: 'Orders', icon: Icons.shopping_cart, route: AppRoutePaths.purchasingOrders),
    HomeNavItem(label: 'Vendors', icon: Icons.storefront_outlined, route: AppRoutePaths.purchasingVendors),
    HomeNavItem(label: 'Objects', icon: Icons.category, route: AppRoutePaths.purchasingObjects),
    HomeNavItem(label: 'Stats', icon: Icons.bar_chart, route: AppRoutePaths.purchasingStats),
  ],
  'finance': [
    HomeNavItem(label: 'Home', icon: Icons.home, route: AppRoutePaths.dashboard),
    HomeNavItem(label: 'Ledger', icon: Icons.account_balance, route: AppRoutePaths.financeLedger),
    HomeNavItem(label: 'Invoices', icon: Icons.receipt_long, route: AppRoutePaths.financeInvoices),
    HomeNavItem(label: 'Bills', icon: Icons.request_quote, route: AppRoutePaths.financeBills),
    HomeNavItem(label: 'Payments', icon: Icons.payments_outlined, route: AppRoutePaths.financePayments),
  ],
  'legal': [
    HomeNavItem(label: 'Home', icon: Icons.home, route: AppRoutePaths.dashboard),
    HomeNavItem(label: 'Documents', icon: Icons.description, route: AppRoutePaths.legalDocuments),
    HomeNavItem(label: 'Compliance', icon: Icons.verified, route: AppRoutePaths.legalCompliance),
    HomeNavItem(label: 'Contracts', icon: Icons.handshake, route: AppRoutePaths.legalContracts),
    HomeNavItem(label: 'Stats', icon: Icons.bar_chart, route: AppRoutePaths.legalStats),
  ],
  'admin': [
    HomeNavItem(label: 'Home', icon: Icons.home, route: AppRoutePaths.dashboard),
    HomeNavItem(label: 'Company', icon: Icons.business, route: AppRoutePaths.adminCompany),
    HomeNavItem(label: 'Policies', icon: Icons.policy, route: AppRoutePaths.adminPolicies),
  ],
  'companies': [
    HomeNavItem(label: 'Home', icon: Icons.home, route: AppRoutePaths.dashboard),
    HomeNavItem(label: 'Companies', icon: Icons.business, route: AppRoutePaths.companies),
  ],
  // Billing resolves to finance section (billing is under finance)
  'billing': [
    HomeNavItem(label: 'Home', icon: Icons.home, route: AppRoutePaths.dashboard),
    HomeNavItem(label: 'Ledger', icon: Icons.account_balance, route: AppRoutePaths.financeLedger),
    HomeNavItem(label: 'Billing', icon: Icons.receipt_long, route: AppRoutePaths.billing),
    HomeNavItem(label: 'Invoices', icon: Icons.receipt_long, route: AppRoutePaths.financeInvoices),
    HomeNavItem(label: 'Payments', icon: Icons.payments_outlined, route: AppRoutePaths.financePayments),
  ],
  // Objects section (catalog, scraping, staging)
  'catalog': [
    HomeNavItem(label: 'Home', icon: Icons.home, route: AppRoutePaths.dashboard),
    HomeNavItem(label: 'Catalog', icon: Icons.inventory_2, route: AppRoutePaths.catalog),
    HomeNavItem(label: 'Scraping', icon: Icons.build, route: AppRoutePaths.catalogScrapeJobs),
  ],
  'deviceRegistry': [
    HomeNavItem(label: 'Home', icon: Icons.home, route: AppRoutePaths.dashboard),
    HomeNavItem(label: 'Devices', icon: Icons.cell_tower, route: AppRoutePaths.deviceRegistry),
  ],
  'onboarding': [
    HomeNavItem(label: 'Home', icon: Icons.home, route: AppRoutePaths.dashboard),
    HomeNavItem(label: 'Onboarding', icon: Icons.how_to_reg, route: AppRoutePaths.onboarding),
  ],
  'support': [
    HomeNavItem(label: 'Home', icon: Icons.home, route: AppRoutePaths.dashboard),
    HomeNavItem(label: 'Support', icon: Icons.support_agent, route: AppRoutePaths.support),
  ],
  'tasks': [
    HomeNavItem(label: 'Home', icon: Icons.home, route: AppRoutePaths.dashboard),
    HomeNavItem(label: 'Tasks', icon: Icons.assignment_turned_in, route: AppRoutePaths.tasksTasks),
  ],
  'facilities': [
    HomeNavItem(label: 'Home', icon: Icons.home, route: AppRoutePaths.dashboard),
    HomeNavItem(label: 'Properties', icon: Icons.business, route: AppRoutePaths.facilitiesProperties),
  ],
  'marketplace': [
    HomeNavItem(label: 'Home', icon: Icons.home, route: AppRoutePaths.dashboard),
    HomeNavItem(label: 'Marketplace', icon: Icons.storefront, route: AppRoutePaths.marketplaceHome),
  ],
  'processes': [
    HomeNavItem(label: 'Home', icon: Icons.home, route: AppRoutePaths.dashboard),
    HomeNavItem(label: 'Processes', icon: Icons.route, route: AppRoutePaths.processesHome),
  ],
  'scheduling': [
    HomeNavItem(label: 'Home', icon: Icons.home, route: AppRoutePaths.dashboard),
    HomeNavItem(label: 'Teams', icon: Icons.view_timeline, route: AppRoutePaths.schedulingTeams),
  ],
  'supervision': [
    HomeNavItem(label: 'Home', icon: Icons.home, route: AppRoutePaths.dashboard),
    HomeNavItem(label: 'Teams', icon: Icons.groups, route: AppRoutePaths.supervisionTeams),
  ],
  'training': [
    HomeNavItem(label: 'Home', icon: Icons.home, route: AppRoutePaths.dashboard),
    HomeNavItem(label: 'Training', icon: Icons.school, route: AppRoutePaths.trainingHome),
  ],
  'quality': [
    HomeNavItem(label: 'Home', icon: Icons.home, route: AppRoutePaths.dashboard),
    HomeNavItem(label: 'Teams', icon: Icons.auto_awesome, route: AppRoutePaths.qualityTeams),
  ],
  'safety': [
    HomeNavItem(label: 'Home', icon: Icons.home, route: AppRoutePaths.dashboard),
    HomeNavItem(label: 'Analysis', icon: Icons.warning_amber, route: AppRoutePaths.safetyAnalysis),
  ],
  'occupancy': [
    HomeNavItem(label: 'Home', icon: Icons.home, route: AppRoutePaths.dashboard),
    HomeNavItem(label: 'Property', icon: Icons.door_front_door, route: AppRoutePaths.occupancyProperty),
  ],
  'engagement': [
    HomeNavItem(label: 'Home', icon: Icons.home, route: AppRoutePaths.dashboard),
    HomeNavItem(label: 'Reports', icon: Icons.headset_mic, route: AppRoutePaths.engagementReports),
  ],
  'inventory': [
    HomeNavItem(label: 'Home', icon: Icons.home, route: AppRoutePaths.dashboard),
    HomeNavItem(label: 'Fulfillment', icon: Icons.inventory_2, route: AppRoutePaths.inventoryFulfillment),
    HomeNavItem(label: 'Stats', icon: Icons.bar_chart, route: AppRoutePaths.inventoryStats),
  ],
};
