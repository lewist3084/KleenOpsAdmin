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
        id: 'companies',
        label: 'Companies',
        icon: Icons.business,
        accessFlagKey: 'companies',
        onPressed: (ctx) => ctx.go(AppRoutePaths.companies),
      ),
      MenuButtonConfig(
        id: 'finance',
        label: 'Finance',
        icon: Icons.account_balance_outlined,
        accessFlagKey: 'finance',
        onPressed: (ctx) => ctx.go(AppRoutePaths.financeLedger),
      ),
      MenuButtonConfig(
        id: 'hr',
        label: 'HR',
        icon: Icons.badge_outlined,
        accessFlagKey: 'hr',
        onPressed: (ctx) => ctx.go(AppRoutePaths.hrEmployees),
      ),
      MenuButtonConfig(
        id: 'administration',
        label: 'Admin',
        icon: Icons.admin_panel_settings_outlined,
        accessFlagKey: 'administration',
        onPressed: (ctx) => ctx.go(AppRoutePaths.adminCompany),
      ),
      MenuButtonConfig(
        id: 'sales',
        label: 'Sales',
        icon: Icons.sell_outlined,
        accessFlagKey: 'sales',
        onPressed: (ctx) => ctx.go(AppRoutePaths.salesSales),
      ),
      MenuButtonConfig(
        id: 'purchasing',
        label: 'Purchasing',
        icon: Icons.shopping_cart_outlined,
        accessFlagKey: 'purchasing',
        onPressed: (ctx) => ctx.go(AppRoutePaths.purchasingOrders),
      ),
      MenuButtonConfig(
        id: 'inventory',
        label: 'Inventory',
        icon: Icons.inventory_2_outlined,
        accessFlagKey: 'inventory',
        onPressed: (ctx) => ctx.go(AppRoutePaths.inventoryHome),
      ),
      MenuButtonConfig(
        id: 'objects',
        label: 'Objects',
        icon: Icons.category_outlined,
        accessFlagKey: 'objects',
        onPressed: (ctx) => ctx.go(AppRoutePaths.catalog),
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
        onPressed: (ctx) => ctx.go(AppRoutePaths.legalDocuments),
      ),
      MenuButtonConfig(
        id: 'support',
        label: 'Support',
        icon: Icons.support_agent,
        accessFlagKey: 'support',
        onPressed: (ctx) => ctx.go(AppRoutePaths.support),
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
          padding: EdgeInsets.only(
            bottom: kBottomNavigationBarHeight + 16.0 +
                MediaQuery.of(context).padding.bottom,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              const _PlatformMetricsPanel(),
              const SizedBox(height: 24),
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

/* ═══════════════════════════════════════════════════════════════════════
   Platform Metrics Panel
   – Loads all metrics once, shows a grid of KPI cards grouped
     by category.
   ═══════════════════════════════════════════════════════════════════════ */

class _PlatformMetricsPanel extends StatefulWidget {
  const _PlatformMetricsPanel();

  @override
  State<_PlatformMetricsPanel> createState() => _PlatformMetricsPanelState();
}

class _PlatformMetricsPanelState extends State<_PlatformMetricsPanel> {
  final _svc = AdminFirebaseService.instance;

  // Company & user counts
  int _totalCompanies = 0;
  int _activeCompanies = 0;
  int _totalUsers = 0;

  // Member counts
  int _totalMembers = 0;
  int _activeMembers = 0;
  int _inactiveMembers = 0;

  // Service adoption
  int _companiesWithBank = 0;
  int _totalBankAccounts = 0;
  int _companiesWithPhone = 0;
  int _totalPhoneLines = 0;

  // Voice metrics
  double _voiceCalls = 0;
  double _videoCalls = 0;
  double _voiceCost = 0;

  // AI metrics
  double _aiCalls = 0;
  double _aiTokens = 0;
  double _aiCost = 0;

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadMetrics();
  }

  Future<void> _loadMetrics() async {
    try {
      final results = await Future.wait([
        _svc.totalCompanyCount(),       // 0
        _svc.activeCompanyCount(),      // 1
        _svc.totalUserCount(),          // 2
        _svc.aggregateMemberCounts(),   // 3
        _svc.companiesWithBankAccounts(), // 4
        _svc.totalBankAccounts(),       // 5
        _svc.companiesWithPhoneLines(), // 6
        _svc.totalPhoneLines(),         // 7
        _svc.aggregateVoiceMetrics(),   // 8
        _svc.aggregateAiMetrics(),      // 9
      ]);

      if (!mounted) return;

      final memberCounts = results[3] as Map<String, int>;
      final voiceMetrics = results[8] as Map<String, double>;
      final aiMetrics = results[9] as Map<String, double>;

      setState(() {
        _totalCompanies = results[0] as int;
        _activeCompanies = results[1] as int;
        _totalUsers = results[2] as int;

        _totalMembers = memberCounts['total'] ?? 0;
        _activeMembers = memberCounts['active'] ?? 0;
        _inactiveMembers = memberCounts['inactive'] ?? 0;

        _companiesWithBank = results[4] as int;
        _totalBankAccounts = results[5] as int;
        _companiesWithPhone = results[6] as int;
        _totalPhoneLines = results[7] as int;

        _voiceCalls = voiceMetrics['voiceCalls'] ?? 0;
        _videoCalls = voiceMetrics['videoCalls'] ?? 0;
        _voiceCost = voiceMetrics['totalCost'] ?? 0;

        _aiCalls = aiMetrics['totalCalls'] ?? 0;
        _aiTokens = aiMetrics['totalTokens'] ?? 0;
        _aiCost = aiMetrics['totalCost'] ?? 0;

        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _currency(double v) =>
      '\$${v.toStringAsFixed(2)}';

  String _compact(double v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
    return v.toInt().toString();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Companies & Users ─────────────────────────
          _SectionHeader(
            icon: Icons.business,
            title: 'Companies & Users',
          ),
          Row(
            children: [
              _KpiCard(
                label: 'Total Companies',
                value: '$_totalCompanies',
                icon: Icons.business,
                color: const Color(0xFF002E5D),
              ),
              _KpiCard(
                label: 'Active',
                value: '$_activeCompanies',
                icon: Icons.check_circle_outline,
                color: const Color(0xFF2E7D32),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _KpiCard(
                label: 'Platform Users',
                value: '$_totalUsers',
                icon: Icons.person,
                color: const Color(0xFF1565C0),
              ),
              _KpiCard(
                label: 'Inactive Companies',
                value: '${_totalCompanies - _activeCompanies}',
                icon: Icons.block,
                color: Colors.grey,
              ),
            ],
          ),

          const SizedBox(height: 16),

          // ── Members ──────────────────────────────────
          _SectionHeader(
            icon: Icons.people,
            title: 'Members (All Companies)',
          ),
          Row(
            children: [
              _KpiCard(
                label: 'Total Members',
                value: '$_totalMembers',
                icon: Icons.people,
                color: const Color(0xFF002E5D),
              ),
              _KpiCard(
                label: 'Active',
                value: '$_activeMembers',
                icon: Icons.person,
                color: const Color(0xFF2E7D32),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _KpiCard(
                label: 'Inactive',
                value: '$_inactiveMembers',
                icon: Icons.person_off,
                color: Colors.orange,
              ),
              const Expanded(child: SizedBox()),
            ],
          ),

          const SizedBox(height: 16),

          // ── Banking & Phone ──────────────────────────
          _SectionHeader(
            icon: Icons.account_balance,
            title: 'Service Adoption',
          ),
          Row(
            children: [
              _KpiCard(
                label: 'Bank Connected',
                value: '$_companiesWithBank co.',
                icon: Icons.account_balance,
                color: const Color(0xFFE65100),
              ),
              _KpiCard(
                label: 'Bank Accounts',
                value: '$_totalBankAccounts',
                icon: Icons.credit_card,
                color: const Color(0xFF1565C0),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _KpiCard(
                label: 'Phone Lines',
                value: '$_companiesWithPhone co.',
                icon: Icons.phone,
                color: const Color(0xFF6A1B9A),
              ),
              _KpiCard(
                label: 'Total Lines',
                value: '$_totalPhoneLines',
                icon: Icons.phone_in_talk,
                color: const Color(0xFF2E7D32),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // ── Voice / VoIP ─────────────────────────────
          _SectionHeader(
            icon: Icons.phone_in_talk,
            title: 'Voice & Video (All Companies)',
          ),
          Row(
            children: [
              _KpiCard(
                label: 'Voice Calls',
                value: _compact(_voiceCalls),
                icon: Icons.call,
                color: const Color(0xFF1565C0),
              ),
              _KpiCard(
                label: 'Video Calls',
                value: _compact(_videoCalls),
                icon: Icons.videocam,
                color: const Color(0xFF6A1B9A),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _KpiCard(
                label: 'Voice Cost',
                value: _currency(_voiceCost),
                icon: Icons.attach_money,
                color: const Color(0xFFE65100),
              ),
              const Expanded(child: SizedBox()),
            ],
          ),

          const SizedBox(height: 16),

          // ── AI Usage ─────────────────────────────────
          _SectionHeader(
            icon: Icons.auto_awesome,
            title: 'AI Usage (All Companies)',
          ),
          Row(
            children: [
              _KpiCard(
                label: 'AI Calls',
                value: _compact(_aiCalls),
                icon: Icons.auto_awesome,
                color: const Color(0xFF6A1B9A),
              ),
              _KpiCard(
                label: 'Tokens',
                value: _compact(_aiTokens),
                icon: Icons.token,
                color: const Color(0xFF1565C0),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _KpiCard(
                label: 'AI Cost',
                value: _currency(_aiCost),
                icon: Icons.attach_money,
                color: const Color(0xFFE65100),
              ),
              const Expanded(child: SizedBox()),
            ],
          ),
        ],
      ),
    );
  }
}

/* ─── Reusable KPI card ─────────────────────────────────────────────── */

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
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 20, color: color),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      value,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      label,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: Colors.grey.shade600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/* ─── Section header ────────────────────────────────────────────────── */

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;

  const _SectionHeader({
    required this.icon,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8, top: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey.shade700),
          const SizedBox(width: 6),
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
          ),
        ],
      ),
    );
  }
}
