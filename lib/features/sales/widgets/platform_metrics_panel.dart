// lib/features/sales/widgets/platform_metrics_panel.dart
//
// Platform-wide KPI tiles (companies, users, members, service adoption,
// voice/video, AI usage). These used to live on the admin Home dashboard; they
// were relocated here under Sales → Stats when the Home tiles were reframed as
// the sellable product catalog (Sales → Products). The numbers are the
// platform-wide totals behind those products.

import 'package:flutter/material.dart';

import '../../../services/admin_firebase_service.dart';

class PlatformMetricsPanel extends StatefulWidget {
  const PlatformMetricsPanel({super.key});

  @override
  State<PlatformMetricsPanel> createState() => _PlatformMetricsPanelState();
}

class _PlatformMetricsPanelState extends State<PlatformMetricsPanel> {
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
        _svc.totalCompanyCount(), // 0
        _svc.activeCompanyCount(), // 1
        _svc.totalUserCount(), // 2
        _svc.aggregateMemberCounts(), // 3
        _svc.companiesWithBankAccounts(), // 4
        _svc.totalBankAccounts(), // 5
        _svc.companiesWithPhoneLines(), // 6
        _svc.totalPhoneLines(), // 7
        _svc.aggregateVoiceMetrics(), // 8
        _svc.aggregateAiMetrics(), // 9
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

  String _currency(double v) => '\$${v.toStringAsFixed(2)}';

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
