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

const HomeNavConfig _navConfig = {
  'dashboard': [
    HomeNavItem(
      label: 'Home',
      icon: Icons.home,
      route: AppRoutePaths.dashboard,
    ),
  ],
  'legal': [
    HomeNavItem(
      label: 'Home',
      icon: Icons.home,
      route: AppRoutePaths.legalHome,
    ),
    HomeNavItem(
      label: 'Documents',
      icon: Icons.description,
      route: AppRoutePaths.legalDocuments,
    ),
    HomeNavItem(
      label: 'Compliance',
      icon: Icons.verified,
      route: AppRoutePaths.legalCompliance,
    ),
    HomeNavItem(
      label: 'Contracts',
      icon: Icons.handshake,
      route: AppRoutePaths.legalContracts,
    ),
    HomeNavItem(
      label: 'Stats',
      icon: Icons.bar_chart,
      route: AppRoutePaths.legalStats,
    ),
  ],
  'companies': [
    HomeNavItem(
      label: 'Companies',
      icon: Icons.business,
      route: AppRoutePaths.companies,
    ),
  ],
  'billing': [
    HomeNavItem(
      label: 'Billing',
      icon: Icons.receipt_long,
      route: AppRoutePaths.billing,
    ),
  ],
  'aiUsage': [
    HomeNavItem(
      label: 'AI Usage',
      icon: Icons.smart_toy,
      route: AppRoutePaths.aiUsage,
    ),
  ],
  'storage': [
    HomeNavItem(
      label: 'Storage',
      icon: Icons.cloud,
      route: AppRoutePaths.storage,
    ),
  ],
  'users': [
    HomeNavItem(
      label: 'Users',
      icon: Icons.people,
      route: AppRoutePaths.users,
    ),
  ],
  'onboarding': [
    HomeNavItem(
      label: 'Onboarding',
      icon: Icons.how_to_reg,
      route: AppRoutePaths.onboarding,
    ),
  ],
  'support': [
    HomeNavItem(
      label: 'Support',
      icon: Icons.support_agent,
      route: AppRoutePaths.support,
    ),
  ],
  'catalog': [
    HomeNavItem(
      label: 'Catalog',
      icon: Icons.inventory_2,
      route: AppRoutePaths.catalog,
    ),
  ],
  'deviceRegistry': [
    HomeNavItem(
      label: 'Devices',
      icon: Icons.cell_tower,
      route: AppRoutePaths.deviceRegistry,
    ),
  ],
};
