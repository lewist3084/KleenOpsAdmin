// lib/features/dashboard/screens/dashboard_home.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_widgets/buttons/menu_button_block.dart';
import 'package:shared_widgets/containers/canvas_top_bookend.dart';
import 'package:shared_widgets/containers/standard_canvas.dart';
import 'package:shared_widgets/drawers/menu_drawer.dart';

import '../../../app/routes.dart';
import '../../../app/shared_widgets/drawers/user_drawer.dart';
import '../../../app/shared_widgets/navigation/details_appbar_adapter.dart';
import '../../../app/shared_widgets/navigation/home_navbar_adapter.dart';
import '../../../services/admin_firebase_service.dart';

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
    final menuConfigs = <MenuButtonConfig>[
      MenuButtonConfig(
        id: 'catalog',
        label: 'Catalog',
        icon: Icons.inventory_2,
        accessFlagKey: 'catalog',
        onPressed: (ctx) => ctx.go(AppRoutePaths.catalog),
      ),
      MenuButtonConfig(
        id: 'companies',
        label: 'Companies',
        icon: Icons.business,
        accessFlagKey: 'companies',
        onPressed: (ctx) => ctx.go(AppRoutePaths.companies),
      ),
      MenuButtonConfig(
        id: 'billing',
        label: 'Billing',
        icon: Icons.receipt_long,
        accessFlagKey: 'billing',
        onPressed: (ctx) => ctx.go(AppRoutePaths.billing),
      ),
      MenuButtonConfig(
        id: 'aiUsage',
        label: 'AI Usage',
        icon: Icons.smart_toy,
        accessFlagKey: 'aiUsage',
        onPressed: (ctx) => ctx.go(AppRoutePaths.aiUsage),
      ),
      MenuButtonConfig(
        id: 'storage',
        label: 'Storage',
        icon: Icons.cloud,
        accessFlagKey: 'storage',
        onPressed: (ctx) => ctx.go(AppRoutePaths.storage),
      ),
      MenuButtonConfig(
        id: 'users',
        label: 'Users',
        icon: Icons.people,
        accessFlagKey: 'users',
        onPressed: (ctx) => ctx.go(AppRoutePaths.users),
      ),
      MenuButtonConfig(
        id: 'onboarding',
        label: 'Onboarding',
        icon: Icons.how_to_reg,
        accessFlagKey: 'onboarding',
        onPressed: (ctx) => ctx.go(AppRoutePaths.onboarding),
      ),
      MenuButtonConfig(
        id: 'legal',
        label: 'Legal',
        icon: Icons.gavel,
        accessFlagKey: 'legal',
        onPressed: (ctx) => ctx.go(AppRoutePaths.legalHome),
      ),
      MenuButtonConfig(
        id: 'support',
        label: 'Support',
        icon: Icons.support_agent,
        accessFlagKey: 'support',
        onPressed: (ctx) => ctx.go(AppRoutePaths.support),
      ),
      MenuButtonConfig(
        id: 'deviceRegistry',
        label: 'Devices',
        icon: Icons.cell_tower,
        accessFlagKey: 'deviceRegistry',
        onPressed: (ctx) => ctx.go(AppRoutePaths.deviceRegistry),
      ),
    ];

    // Admin gets all access flags set to true.
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
    );

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: null,
      drawer: const UserDrawer(),
      body: _wrapCanvas(
        SingleChildScrollView(
          padding: EdgeInsets.only(
            bottom: kBottomNavigationBarHeight + 16.0 +
                MediaQuery.of(context).padding.bottom,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              // Company count summary
              StreamBuilder(
                stream: AdminFirebaseService.instance.allCompanies(),
                builder: (context, snapshot) {
                  final count = snapshot.data?.docs.length ?? 0;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        _KpiCard(
                          label: 'Companies',
                          value: '$count',
                          icon: Icons.business,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),
              // Menu grid
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
            title: 'Kleenops Admin',
            menuSections: menuSections,
          ),
          const HomeNavBarAdapter(),
        ],
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _KpiCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(icon, size: 40, color: color),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value,
                      style: Theme.of(context)
                          .textTheme
                          .headlineMedium
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  Text(label,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: Colors.grey)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
