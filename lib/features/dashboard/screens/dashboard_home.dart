// lib/features/dashboard/screens/dashboard_home.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_widgets/buttons/menu_button_block.dart';
import 'package:shared_widgets/containers/canvas_top_bookend.dart';
import 'package:shared_widgets/containers/standard_canvas.dart';
import 'package:shared_widgets/drawers/menu_drawer.dart';

import '../../../app/routes.dart';
import '../../../common/communications/comm_menu.dart';
import '../../../app/shared_widgets/drawers/user_drawer.dart';
import '../../../app/shared_widgets/navigation/details_appbar_adapter.dart';
import '../../../app/shared_widgets/navigation/home_navbar_adapter.dart';

class DashboardHome extends ConsumerWidget {
  const DashboardHome({super.key});

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
  Widget build(BuildContext context, WidgetRef ref) {
    // ── Business operations buttons (mirroring KleenOps app) ──
    // Note: company oversight has moved into the Sales section.
    final menuConfigs = <MenuButtonConfig>[
      // Mirrored from KleenOps app (same order as appMenuOrder)
      MenuButtonConfig(
        id: 'tasks',
        label: 'Tasks',
        icon: Icons.assignment_turned_in_outlined,
        accessFlagKey: 'tasks',
        onPressed: (ctx) => ctx.go(AppRoutePaths.tasksTasks),
      ),
      MenuButtonConfig(
        id: 'facilities',
        label: 'Facilities',
        icon: Icons.business_outlined,
        accessFlagKey: 'facilities',
        onPressed: (ctx) => ctx.go(AppRoutePaths.facilitiesProperties),
      ),
      MenuButtonConfig(
        id: 'objects',
        label: 'Objects',
        icon: Icons.category_outlined,
        accessFlagKey: 'objects',
        onPressed: (ctx) => ctx.go(AppRoutePaths.objectsHome),
      ),
      MenuButtonConfig(
        id: 'marketplace',
        label: 'Marketplace',
        icon: Icons.storefront_outlined,
        accessFlagKey: 'marketplace',
        onPressed: (ctx) => ctx.go(AppRoutePaths.marketplaceHome),
      ),
      MenuButtonConfig(
        id: 'processes',
        label: 'Processes',
        icon: Icons.route_outlined,
        accessFlagKey: 'processes',
        onPressed: (ctx) => ctx.go(AppRoutePaths.processesHome),
      ),
      MenuButtonConfig(
        id: 'scheduling',
        label: 'Scheduling',
        icon: Icons.view_timeline_outlined,
        accessFlagKey: 'scheduling',
        onPressed: (ctx) => ctx.go(AppRoutePaths.schedulingTeams),
      ),
      MenuButtonConfig(
        id: 'hr',
        label: 'HR',
        icon: Icons.badge_outlined,
        accessFlagKey: 'hr',
        onPressed: (ctx) => ctx.go(AppRoutePaths.hrEmployees),
      ),
      MenuButtonConfig(
        id: 'supervision',
        label: 'Supervision',
        icon: Icons.groups_outlined,
        accessFlagKey: 'supervision',
        onPressed: (ctx) => ctx.go(AppRoutePaths.supervisionTeams),
      ),
      MenuButtonConfig(
        id: 'training',
        label: 'Training',
        icon: Icons.school_outlined,
        accessFlagKey: 'training',
        onPressed: (ctx) => ctx.go(AppRoutePaths.trainingHome),
      ),
      MenuButtonConfig(
        id: 'quality',
        label: 'Quality',
        icon: Icons.auto_awesome_outlined,
        accessFlagKey: 'quality',
        onPressed: (ctx) => ctx.go(AppRoutePaths.qualityTeams),
      ),
      MenuButtonConfig(
        id: 'safety',
        label: 'Safety',
        icon: Icons.warning_amber_rounded,
        accessFlagKey: 'safety',
        onPressed: (ctx) => ctx.go(AppRoutePaths.safetyAnalysis),
      ),
      MenuButtonConfig(
        id: 'inventory',
        label: 'Inventory',
        icon: Icons.inventory_outlined,
        accessFlagKey: 'inventory',
        onPressed: (ctx) => ctx.go(AppRoutePaths.inventoryFulfillment),
      ),
      MenuButtonConfig(
        id: 'purchasing',
        label: 'Purchasing',
        icon: Icons.shopping_cart_outlined,
        accessFlagKey: 'purchasing',
        onPressed: (ctx) => ctx.go(AppRoutePaths.purchasingOrders),
      ),
      MenuButtonConfig(
        id: 'occupancy',
        label: 'Occupancy',
        icon: Icons.door_front_door_outlined,
        accessFlagKey: 'occupancy',
        onPressed: (ctx) => ctx.go(AppRoutePaths.occupancyProperty),
      ),
      MenuButtonConfig(
        id: 'engagement',
        label: 'Engagement',
        icon: Icons.headset_mic_outlined,
        accessFlagKey: 'engagement',
        onPressed: (ctx) => ctx.go(AppRoutePaths.engagementReports),
      ),
      MenuButtonConfig(
        id: 'sales',
        label: 'Sales',
        icon: Icons.sell_outlined,
        accessFlagKey: 'sales',
        onPressed: (ctx) => ctx.go(AppRoutePaths.salesSales),
      ),
      MenuButtonConfig(
        id: 'legal',
        label: 'Legal',
        icon: Icons.gavel_outlined,
        accessFlagKey: 'legal',
        onPressed: (ctx) => ctx.go(AppRoutePaths.legalDocuments),
      ),
      MenuButtonConfig(
        id: 'finance',
        label: 'Finance',
        icon: Icons.account_balance_outlined,
        accessFlagKey: 'finance',
        onPressed: (ctx) => ctx.go(AppRoutePaths.financeLedger),
      ),
      MenuButtonConfig(
        id: 'administration',
        label: 'Admin',
        icon: Icons.attach_file_outlined,
        accessFlagKey: 'administration',
        onPressed: (ctx) => ctx.go(AppRoutePaths.adminCompany),
      ),
      MenuButtonConfig(
        id: 'me',
        label: 'Me',
        icon: Icons.person_outline,
        accessFlagKey: 'me',
        onPressed: (ctx) => ctx.go(AppRoutePaths.meInfo),
      ),
    ];

    final adminAccessStream = Stream.value(<String, dynamic>{
      for (final c in menuConfigs) c.accessFlagKey: true,
    });

    final menuSections = MenuDrawerSections(
      actions: [
        ContentMenuItem(
          icon: Icons.inventory_2_outlined,
          label: 'Catalog',
          onTap: () => context.go(AppRoutePaths.catalog),
        ),
        ContentMenuItem(
          icon: Icons.business_outlined,
          label: 'Companies',
          onTap: () => context.go(AppRoutePaths.companies),
        ),
        ContentMenuItem(
          icon: Icons.domain_outlined,
          label: 'Organizations',
          onTap: () => context.go(AppRoutePaths.organizationRegistry),
        ),
        ContentMenuItem(
          icon: Icons.gavel_outlined,
          label: 'Legal',
          onTap: () => context.go(AppRoutePaths.legalHome),
        ),
        ContentMenuItem(
          icon: Icons.support_agent_outlined,
          label: 'Support',
          onTap: () => context.go(AppRoutePaths.support),
        ),
      ],
      communications: buildAdminCommunicationMenuItems(context),
    );

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: null,
      drawer: const UserDrawer(),
      body: _wrapCanvas(
        SingleChildScrollView(
          padding: const EdgeInsets.only(
            bottom: 16.0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              // The onboarding funnel moved to Engagement › Mobile/Web, where
              // it's split by platform alongside time-in-app + A/B experiments.
              MenuButtonBlock(
                userDataStream: adminAccessStream,
                configs: menuConfigs,
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DetailsAppBar(
            title: 'KleenOps Admin',
            menuSections: menuSections,
          ),
          const HomeNavBarAdapter(),
        ],
      ),
    );
  }
}
