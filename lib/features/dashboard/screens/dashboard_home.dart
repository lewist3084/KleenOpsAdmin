// lib/features/dashboard/screens/dashboard_home.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_widgets/buttons/menu_button_block.dart';
import 'package:shared_widgets/containers/standard_canvas.dart';

import '../../../app/routes.dart';
import '../../../services/admin_firebase_service.dart';
import '../../../theme/palette.dart';

class DashboardHome extends ConsumerWidget {
  const DashboardHome({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const palette = adminPalette;
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
        id: 'support',
        label: 'Support',
        icon: Icons.support_agent,
        accessFlagKey: 'support',
        onPressed: (ctx) => ctx.go(AppRoutePaths.support),
      ),
    ];

    // Admin gets all access flags set to true.
    final adminAccessStream = Stream.value(<String, dynamic>{
      for (final c in menuConfigs) c.accessFlagKey: true,
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kleenops Admin'),
        backgroundColor: palette.primary1,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => FirebaseAuth.instance.signOut(),
          ),
        ],
      ),
      body: StandardCanvas(
        child: SingleChildScrollView(
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
                          color: palette.primary1,
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
