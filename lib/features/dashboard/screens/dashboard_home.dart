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
        onPressed: (ctx) => ctx.go(AppRoutePaths.catalog),
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
              const _OnboardingFunnelPanel(),
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

/* ═══════════════════════════════════════════════════════════════════════
   Onboarding Funnel Panel
   – Reads the rolled-up `funnelTotals/onboarding` doc written by the
     `aggregateFunnelDaily` cloud function and renders the funnel as a
     vertical list of stages with progress bars + drop-off callout.
   – Refresh button calls `recomputeFunnelOnDemand` so the user can rebuild
     without waiting for the daily cron.
   ═══════════════════════════════════════════════════════════════════════ */

class _OnboardingFunnelPanel extends StatefulWidget {
  const _OnboardingFunnelPanel();

  @override
  State<_OnboardingFunnelPanel> createState() => _OnboardingFunnelPanelState();
}

class _OnboardingFunnelPanelState extends State<_OnboardingFunnelPanel> {
  final _svc = AdminFirebaseService.instance;
  bool _refreshing = false;

  /// Ordered list of (stageKey, displayLabel) pairs that show in the funnel
  /// — these are the rows the user sees, in funnel order. The keys match the
  /// snake_case event names written by AnalyticsService.
  static const _funnelRows = <List<String>>[
    ['registration_fork_viewed', 'Registration fork viewed'],
    ['registration_fork_picked', 'Picked a fork option'],
    ['business_type_viewed', 'Business type viewed'],
    ['business_type_picked', 'Picked a business type'],
    ['cleaning_setup_viewed', 'Cleaning setup viewed'],
    ['cleaning_setup_company_named', 'Named the company'],
    ['welcome_carousel_viewed', 'Welcome carousel viewed'],
    ['welcome_carousel_completed', 'Welcome carousel completed'],
    ['setup_dashboard_viewed', 'Setup dashboard viewed'],
    ['setup_section_opened', 'Opened a setup section'],
    ['setup_section_completed', 'Completed a setup section'],
    ['setup_review_reached', 'Reached review & pay'],
    ['setup_paid', 'Paid'],
    ['onboarding_complete', 'Onboarding complete'],
  ];

  Future<void> _refresh() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    try {
      await _svc.recomputeFunnelNow();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Refresh failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<OnboardingFunnel?>(
      stream: _svc.onboardingFunnelStream(),
      builder: (context, snapshot) {
        final funnel = snapshot.data;
        return Card(
          elevation: 1,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.timeline,
                        size: 18, color: Colors.grey.shade700),
                    const SizedBox(width: 6),
                    Text(
                      funnel == null
                          ? 'Onboarding Funnel'
                          : 'Onboarding Funnel — last ${funnel.windowDays}d',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade700,
                          ),
                    ),
                    const Spacer(),
                    IconButton(
                      tooltip: 'Refresh',
                      icon: _refreshing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.refresh, size: 20),
                      onPressed: _refreshing ? null : _refresh,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (funnel == null)
                  _emptyState()
                else
                  _funnelBody(funnel),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _emptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
      child: Text(
        'No onboarding events yet — once users start the registration flow, '
        'data will appear here within 24 hours, or tap Refresh to rebuild now.',
        style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
      ),
    );
  }

  Widget _funnelBody(OnboardingFunnel funnel) {
    final rows = _funnelRows
        .map((pair) => _FunnelRowData(
              key: pair[0],
              label: pair[1],
              count: funnel.stageCounts[pair[0]] ?? 0,
            ))
        .toList();

    final maxCount = rows.fold<int>(0, (m, r) => r.count > m ? r.count : m);
    final firstCount = rows.isNotEmpty ? rows.first.count : 0;

    // Find the biggest absolute drop between consecutive stages so we can
    // flag where users are abandoning the flow.
    int biggestDropIndex = -1;
    int biggestDrop = 0;
    for (var i = 1; i < rows.length; i++) {
      final drop = rows[i - 1].count - rows[i].count;
      if (drop > biggestDrop) {
        biggestDrop = drop;
        biggestDropIndex = i;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < rows.length; i++)
          _FunnelRow(
            label: rows[i].label,
            count: rows[i].count,
            relativeToMax: maxCount == 0 ? 0 : rows[i].count / maxCount,
            percentOfTop:
                firstCount == 0 ? 0 : rows[i].count / firstCount,
            isBiggestDrop: i == biggestDropIndex && biggestDrop > 0,
          ),
        const SizedBox(height: 16),
        _SectionBreakdown(
          title: 'Section opens',
          data: funnel.sectionOpened,
        ),
        const SizedBox(height: 8),
        _SectionBreakdown(
          title: 'Section completions',
          data: funnel.sectionCompleted,
        ),
        const SizedBox(height: 16),
        _ScreenTimeMiniTable(
          averageMs: funnel.screenTimeAverageMs,
          sampleCount: funnel.screenTimeSampleCount,
        ),
        if (funnel.updatedAt != null) ...[
          const SizedBox(height: 12),
          Text(
            'Updated ${_friendlyTimestamp(funnel.updatedAt!)}',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
          ),
        ],
      ],
    );
  }

  String _friendlyTimestamp(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

class _FunnelRowData {
  const _FunnelRowData({
    required this.key,
    required this.label,
    required this.count,
  });
  final String key;
  final String label;
  final int count;
}

class _FunnelRow extends StatelessWidget {
  const _FunnelRow({
    required this.label,
    required this.count,
    required this.relativeToMax,
    required this.percentOfTop,
    required this.isBiggestDrop,
  });
  final String label;
  final int count;
  final double relativeToMax;
  final double percentOfTop;
  final bool isBiggestDrop;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      color: isBiggestDrop ? Colors.red.shade700 : Colors.black87,
                      fontWeight:
                          isBiggestDrop ? FontWeight.w600 : FontWeight.normal,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isBiggestDrop)
                  Container(
                    margin: const EdgeInsets.only(left: 6),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Text(
                      'biggest drop',
                      style: TextStyle(
                        fontSize: 9,
                        color: Colors.red.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 32,
            child: Text(
              '$count',
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: relativeToMax,
                minHeight: 8,
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation(
                  isBiggestDrop
                      ? Colors.red.shade400
                      : const Color(0xFF002E5D),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 36,
            child: Text(
              '${(percentOfTop * 100).round()}%',
              textAlign: TextAlign.right,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionBreakdown extends StatelessWidget {
  const _SectionBreakdown({required this.title, required this.data});
  final String title;
  final Map<String, int> data;

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const SizedBox.shrink();
    final entries = data.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade600,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: entries.map((e) {
            return Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Text(
                '${e.key} · ${e.value}',
                style: const TextStyle(fontSize: 11),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _ScreenTimeMiniTable extends StatelessWidget {
  const _ScreenTimeMiniTable({
    required this.averageMs,
    required this.sampleCount,
  });
  final Map<String, int> averageMs;
  final Map<String, int> sampleCount;

  @override
  Widget build(BuildContext context) {
    if (averageMs.isEmpty) return const SizedBox.shrink();
    final entries = averageMs.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = entries.take(5).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Avg time on screen (top 5)',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade600,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4),
        for (final entry in top)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    entry.key,
                    style: const TextStyle(fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _formatMs(entry.value),
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: 6),
                Text(
                  '(n=${sampleCount[entry.key] ?? 0})',
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
      ],
    );
  }

  String _formatMs(int ms) {
    if (ms < 1000) return '${ms}ms';
    final seconds = ms / 1000;
    if (seconds < 60) return '${seconds.toStringAsFixed(1)}s';
    final minutes = seconds / 60;
    return '${minutes.toStringAsFixed(1)}m';
  }
}
