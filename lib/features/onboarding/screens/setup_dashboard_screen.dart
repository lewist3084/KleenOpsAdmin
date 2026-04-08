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
                    valueColor:
                        const AlwaysStoppedAnimation(Color(0xFF002E5D)),
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
    final opacity = isLocked ? 0.45 : 1.0;

    return Opacity(
      opacity: opacity,
      child: Card(
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                /* ─── Status icon ─── */
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isComplete
                        ? Colors.green.withValues(alpha: 0.1)
                        : isLocked
                            ? Colors.grey.shade100
                            : section.color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: isComplete
                      ? const Icon(Icons.check_circle,
                          color: Colors.green, size: 24)
                      : isLocked
                          ? Icon(Icons.lock_outline,
                              color: Colors.grey.shade400, size: 22)
                          : Icon(section.icon,
                              color: section.color, size: 22),
                ),
                const SizedBox(width: 14),

                /* ─── Text ─── */
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        section.title,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: isLocked
                              ? Colors.grey.shade500
                              : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        section.description,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 13,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.schedule,
                              size: 14, color: Colors.grey.shade500),
                          const SizedBox(width: 4),
                          Text(
                            '~${section.estimateMinutes} min',
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(width: 16),
                          _CostBadge(label: section.costLabel),
                        ],
                      ),
                    ],
                  ),
                ),

                /* ─── Chevron ─── */
                if (!isLocked)
                  Icon(Icons.chevron_right, color: Colors.grey.shade400),
              ],
            ),
          ),
        ),
      ),
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
                    backgroundColor: const Color(0xFF002E5D),
                    foregroundColor: Colors.white,
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
