/* ────────────────────────────────────────────────────────────
   lib/features/onboarding/screens/setup_dashboard_screen.dart
   – TurboTax-style setup dashboard for new company onboarding.
   – Visual port of the kleenops counterpart so admin shows the
     same card layout when a user picks "Facilities Maintenance
     Business" during registration.
   – Dropped the setup_cart_provider dependency for now: admin
     does not run the per-section provisioning + Stripe payment
     flow, so the cards just show structure with stub onTaps.
   – Section onTaps show a "coming soon" SnackBar; the user will
     decide later which existing admin features (or new screens)
     each card should hand off to.
   ──────────────────────────────────────────────────────────── */
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:kleenops_admin/app/routes.dart';
import 'package:kleenops_admin/services/analytics_service.dart';
import 'package:shared_widgets/theme/app_palette.dart';
import 'package:shared_widgets/tiles/standard_bubble_tile.dart';

/* ─── Section definitions ─────────────────────────────────── */

class _Section {
  const _Section({
    required this.key,
    required this.title,
    required this.description,
    required this.icon,
    required this.estimateMinutes,
    required this.color,
    required this.costLabel,
    this.dependsOn = const [],
  });
  final String key;
  final String title;
  final String description;
  final IconData icon;
  final int estimateMinutes;
  final Color color;
  final String costLabel;
  final List<String> dependsOn;
}

const _sections = [
  _Section(
    key: 'company_info',
    title: 'Company Information',
    description: 'Business name, address, and entity type.',
    icon: Icons.business,
    estimateMinutes: 5,
    color: Color(0xFF002E5D),
    costLabel: 'Free',
  ),
  _Section(
    key: 'domain',
    title: 'Domain',
    description: 'Register or connect your business domain.',
    icon: Icons.language,
    estimateMinutes: 5,
    color: Color(0xFF1565C0),
    costLabel: '~\$10.44/yr',
    dependsOn: ['company_info'],
  ),
  _Section(
    key: 'phone',
    title: 'Business Phone Number',
    description: 'Get a dedicated number with call forwarding and SMS.',
    icon: Icons.phone,
    estimateMinutes: 3,
    color: Color(0xFF2E7D32),
    costLabel: '~\$1.15/mo',
    dependsOn: ['company_info'],
  ),
  _Section(
    key: 'business_address',
    title: 'Registered Agent & Business Address',
    description:
        'Registered agent, virtual mailing address, and mail forwarding.',
    icon: Icons.location_city,
    estimateMinutes: 3,
    color: Color(0xFF00695C),
    costLabel: 'Optional',
    dependsOn: ['company_info'],
  ),
  _Section(
    key: 'email',
    title: 'Email Addresses',
    description: 'Create professional email addresses for your company.',
    icon: Icons.email,
    estimateMinutes: 5,
    color: Color(0xFF0D47A1),
    costLabel: 'Free',
    dependsOn: ['domain'],
  ),
  _Section(
    key: 'documents',
    title: 'Business Documents',
    description: 'EIN, state registration, insurance, and business license.',
    icon: Icons.description,
    estimateMinutes: 15,
    color: Color(0xFF6A1B9A),
    costLabel: 'Free',
    dependsOn: ['company_info'],
  ),
  _Section(
    key: 'banking',
    title: 'Banking & Payments',
    description: 'Connect bank account and enable Stripe for invoicing.',
    icon: Icons.account_balance,
    estimateMinutes: 10,
    color: Color(0xFFE65100),
    costLabel: 'Free',
    dependsOn: ['company_info'],
  ),
  _Section(
    key: 'employee',
    title: 'Add First Employee',
    description: 'Invite a team member and assign their role.',
    icon: Icons.people,
    estimateMinutes: 5,
    color: Color(0xFFC62828),
    costLabel: 'Free',
    dependsOn: ['company_info'],
  ),
];

/* ─── Screen ──────────────────────────────────────────────── */

class SetupDashboardScreen extends StatefulWidget {
  const SetupDashboardScreen({super.key});

  @override
  State<SetupDashboardScreen> createState() => _SetupDashboardScreenState();
}

class _SetupDashboardScreenState extends State<SetupDashboardScreen> {
  @override
  void initState() {
    super.initState();
    AnalyticsService.instance.logFunnelEvent(FunnelEvent.setupDashboardViewed);
  }

  @override
  Widget build(BuildContext context) {
    // No setup_cart_provider in admin yet — render with empty progress.
    final completedSteps = <String>{};
    final completedCount = 0;
    final totalMinutes =
        _sections.fold<int>(0, (s, sec) => s + sec.estimateMinutes);

    void onSectionTap(_Section section) {
      AnalyticsService.instance.logFunnelEvent(
        FunnelEvent.setupSectionOpened,
        params: {'section_key': section.key},
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Coming soon: ${section.title}'),
          duration: const Duration(seconds: 2),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Set Up Your Company'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: () => context.go(AppRoutePaths.dashboard),
            child: const Text('Skip for now'),
          ),
        ],
      ),
      backgroundColor: Colors.grey.shade50,
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  /* ─── Progress summary ─── */
                  _ProgressCard(
                    completedCount: completedCount,
                    totalCount: _sections.length,
                    totalMinutes: totalMinutes,
                  ),
                  const SizedBox(height: 20),

                  /* ─── Section cards ─── */
                  ..._sections.map((section) {
                    final isComplete =
                        completedSteps.contains(section.key);
                    final isLocked =
                        !_isDependenciesMet(section, completedSteps);

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _SectionCard(
                        section: section,
                        isComplete: isComplete,
                        isLocked: isLocked,
                        onTap: isLocked ? null : () => onSectionTap(section),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),

          /* ─── Cost summary footer ─── */
          const _CostFooter(),
        ],
      ),
    );
  }

  bool _isDependenciesMet(_Section section, Set<String> completedSteps) {
    for (final dep in section.dependsOn) {
      if (!completedSteps.contains(dep)) return false;
    }
    return true;
  }
}

/* ─── Progress card ───────────────────────────────────────── */

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({
    required this.completedCount,
    required this.totalCount,
    required this.totalMinutes,
  });
  final int completedCount, totalCount, totalMinutes;

  @override
  Widget build(BuildContext context) {
    final progress = totalCount > 0 ? completedCount / totalCount : 0.0;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$completedCount of $totalCount sections complete',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Estimated ~$totalMinutes min total',
                    style:
                        TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: 56,
              height: 56,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 6,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation(
                        AppPaletteScope.of(context).primary2),
                  ),
                  Center(
                    child: Text(
                      '${(progress * 100).round()}%',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/* ─── Section card ────────────────────────────────────────── */

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.section,
    required this.isComplete,
    required this.isLocked,
    this.onTap,
  });
  final _Section section;
  final bool isComplete, isLocked;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final IconData leadingIcon;
    final Color leadingIconColor;
    if (isComplete) {
      leadingIcon = Icons.check_circle;
      leadingIconColor = Colors.green;
    } else if (isLocked) {
      leadingIcon = Icons.lock_outline;
      leadingIconColor = Colors.grey.shade500;
    } else {
      leadingIcon = section.icon;
      leadingIconColor = AppPaletteScope.of(context).primary2;
    }

    return StandardBubbleTile(
      title: section.title,
      description: section.description,
      leadingIcon: leadingIcon,
      leadingIconColor: leadingIconColor,
      enabled: !isLocked,
      onTap: onTap ?? () {},
      metaWidget: Row(
        children: [
          Icon(Icons.schedule, size: 14, color: Colors.grey.shade500),
          const SizedBox(width: 4),
          Text(
            '~${section.estimateMinutes} min',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
          ),
          const SizedBox(width: 16),
          _CostBadge(label: section.costLabel),
        ],
      ),
      trailing: isLocked ? const SizedBox.shrink() : null,
    );
  }
}

/* ─── Cost badge ──────────────────────────────────────────── */

class _CostBadge extends StatelessWidget {
  const _CostBadge({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final isFree = label == 'Free';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isFree ? Colors.green.shade50 : Colors.amber.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isFree ? Colors.green.shade200 : Colors.amber.shade200,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: isFree ? Colors.green.shade800 : Colors.amber.shade900,
        ),
      ),
    );
  }
}

/* ─── Cost summary footer ─────────────────────────────────── */

class _CostFooter extends StatelessWidget {
  const _CostFooter();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade300)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            /* ─── Cost summary row ─── */
            Row(
              children: [
                Expanded(
                  child: Text(
                    'No charges yet',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 14,
                    ),
                  ),
                ),

                /* ─── Review & Pay button (disabled until cart support lands) ─── */
                ElevatedButton(
                  onPressed: null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppPaletteScope.of(context).primary2,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Review & Pay'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
