// lib/features/admin/screens/adminCompliance.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:kleenops_admin/app/routes.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/details_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/home_navbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/home_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/drawers/appbar_logout_adapter.dart';
import 'package:kleenops_admin/features/auth/providers/auth_provider.dart';
import 'package:kleenops_admin/features/compliance/services/compliance_reference_service.dart';
import 'package:kleenops_admin/features/compliance/services/compliance_seed_service.dart';
import 'package:shared_widgets/containers/canvas_top_bookend.dart';
import 'package:shared_widgets/containers/standard_canvas.dart';
import 'package:shared_widgets/containers/container_action.dart';
import 'package:shared_widgets/drawers/menu_drawer.dart';
import 'package:shared_widgets/tiles/standard_tile_small.dart';

class AdminComplianceScreen extends StatelessWidget {
  const AdminComplianceScreen({super.key});

  Widget _wrapCanvas(Widget child) {
    return StandardCanvas(
      child: SafeArea(
        top: true,
        bottom: false,
        child: Stack(
          children: [
            Positioned.fill(child: child),
            const Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: CanvasTopBookend(),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool hideChrome = false;

    Widget buildBottomBar({
      VoidCallback? onAiPressed,
      MenuDrawerSections? menuSections,
    }) {
      if (hideChrome) return const SizedBox.shrink();
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DetailsAppBar(
            title: 'Compliance',
            onAiPressed: onAiPressed,
            menuSections: menuSections,
          ),
          const HomeNavBarAdapter(),
        ],
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: null,
      drawer: const UserDrawer(),
      body: _wrapCanvas(
          Consumer(
            builder: (context, ref, _) {
              return ref.watch(companyIdProvider).when(
                    data: (companyRef) {
                      if (companyRef == null) {
                        return const Center(child: Text('No company'));
                      }
                      return _ComplianceContent(companyRef: companyRef);
                    },
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Center(child: Text('Error: $e')),
                  );
            },
          ),
        ),
      bottomNavigationBar: Consumer(
        builder: (context, ref, _) {
          final menuSections = MenuDrawerSections(
            actions: [
              ContentMenuItem(
                icon: Icons.apartment_outlined,
                label: 'Company',
                onTap: () => context.push(AppRoutePaths.adminCompany),
              ),
              ContentMenuItem(
                icon: Icons.policy_outlined,
                label: 'Policies',
                onTap: () => context.push(AppRoutePaths.adminPolicies),
              ),
            ],
          );
          return buildBottomBar(
            menuSections: menuSections,
          );
        },
      ),
    );
  }
}

class _ComplianceContent extends StatefulWidget {
  final DocumentReference<Map<String, dynamic>> companyRef;

  const _ComplianceContent({required this.companyRef});

  @override
  State<_ComplianceContent> createState() => _ComplianceContentState();
}

class _ComplianceContentState extends State<_ComplianceContent> {
  bool _seeding = false;
  String _seedStatus = '';

  Future<void> _seedReferenceData() async {
    setState(() {
      _seeding = true;
      _seedStatus = 'Starting...';
    });
    try {
      final service = ComplianceSeedService();
      final counts = await service.seedAll(
        onProgress: (msg) {
          if (mounted) setState(() => _seedStatus = msg);
        },
      );
      final total = counts.values.fold(0, (a, b) => a + b);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Seeded $total reference documents')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Seed error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _seeding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset =
        kBottomNavigationBarHeight + 16.0 + MediaQuery.of(context).padding.bottom;

    return SingleChildScrollView(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Seed Reference Data ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _seeding ? null : _seedReferenceData,
                icon: _seeding
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.cloud_upload_outlined, size: 18),
                label: Text(_seeding
                    ? _seedStatus
                    : 'Seed / Update Reference Data (All 51 States)'),
              ),
            ),
          ),

          // ── Federal Rules ──
          _FederalRulesSection(companyRef: widget.companyRef),

          // ── State Rules ──
          ContainerActionWidget(
            title: 'State Regulations (Reference Data)',
            actionText: 'View All',
            onAction: () => context.push(
              AppRoutePaths.adminStateRuleForm,
            ),
            content: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              // Read from top-level stateRule collection (shared across all companies)
              stream: ComplianceReferenceService().watchAllStateRules(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final docs = snapshot.data?.docs ?? [];
                if (docs.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'No state rules configured. Add states where your employees work.',
                      style: TextStyle(color: Colors.grey[500]),
                    ),
                  );
                }
                return Column(
                  children: docs.map((doc) {
                    final data = doc.data();
                    final stateName =
                        (data['stateName'] ?? doc.id).toString();
                    final stateCode =
                        (data['stateCode'] ?? doc.id).toString();
                    final minWage = data['minimumWage'];
                    final benefitsThreshold = data['benefitsThresholdHours'];
                    final otThreshold = data['overtimeThreshold'];

                    final details = <String>[];
                    if (minWage != null) {
                      details.add('Min wage: \$${_fmt(minWage)}');
                    }
                    if (otThreshold != null) {
                      details.add('OT after ${otThreshold}h');
                    }
                    if (benefitsThreshold != null) {
                      details.add('Benefits: ${benefitsThreshold}h/wk');
                    }

                    return StandardTileSmallDart(
                      label: '$stateName ($stateCode)',
                      secondaryText:
                          details.isNotEmpty ? details.join(' · ') : null,
                      labelIcon: Icons.location_on_outlined,
                      trailingIcon1: Icons.chevron_right,
                      onTap: () => context.push(
                        AppRoutePaths.adminStateRuleForm,
                        extra: {'stateCode': stateCode},
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ),

          // ── Compliance Dashboard link ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () =>
                    context.push(AppRoutePaths.adminCompliance),
                icon: const Icon(Icons.checklist_outlined, size: 18),
                label: const Text('Open Compliance Dashboard'),
              ),
            ),
          ),

          // ── Info card ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                border: Border.all(color: Colors.blue[200]!),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline,
                      color: Colors.blue[800], size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This page shows shared reference data for all companies. '
                      'Use the Compliance Dashboard to track your company-specific compliance status.',
                      style:
                          TextStyle(fontSize: 13, color: Colors.blue[900]),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _fmt(dynamic value) {
    if (value is double) return NumberFormat('#,##0.00').format(value);
    if (value is int) return NumberFormat('#,##0.00').format(value.toDouble());
    return value.toString();
  }
}

// ─────────────────────── Federal Rules Section ───────────────────────

class _FederalRulesSection extends StatelessWidget {
  final DocumentReference<Map<String, dynamic>> companyRef;

  const _FederalRulesSection({required this.companyRef});

  @override
  Widget build(BuildContext context) {
    // Read from top-level federalRule collection (shared across all companies)
    final year = DateTime.now().year;
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: ComplianceReferenceService().watchFederalRule(year: year),
      builder: (context, snapshot) {
        final data = snapshot.data?.data();
        final exists = data != null;

        return ContainerActionWidget(
          title: 'Federal Regulations',
          actionText: exists ? 'Edit' : 'Configure',
          onAction: () => context.push(AppRoutePaths.adminFederalRuleForm),
          content: exists
              ? Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  child: Column(
                    children: [
                      _ruleRow('Minimum Wage',
                          '\$${_fmt(data['federalMinimumWage'])}'),
                      _ruleRow('Overtime Threshold',
                          '${data['overtimeThresholdWeekly'] ?? 40} hrs/week'),
                      _ruleRow('FICA Rate',
                          '${_pct(data['ficaRate'])}'),
                      _ruleRow('SS Rate',
                          '${_pct(data['socialSecurityRate'])}'),
                      _ruleRow('SS Wage Cap',
                          '\$${_fmtInt(data['socialSecurityWageCap'])}'),
                      _ruleRow('Medicare Rate',
                          '${_pct(data['medicareRate'])}'),
                      _ruleRow('ACA Benefits Threshold',
                          '${data['acaBenefitsThreshold'] ?? 30} hrs/week'),
                      _ruleRow('Effective Year',
                          '${data['effectiveYear'] ?? ''}'),
                    ],
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Federal rules not configured yet. Tap Configure to set up federal tax rates, FICA, and overtime thresholds.',
                    style: TextStyle(color: Colors.grey[500]),
                  ),
                ),
        );
      },
    );
  }

  Widget _ruleRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 160,
            child: Text(
              label,
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 14)),
          ),
        ],
      ),
    );
  }

  String _fmt(dynamic value) {
    if (value == null) return '—';
    if (value is double) return NumberFormat('#,##0.00').format(value);
    if (value is int) return NumberFormat('#,##0.00').format(value.toDouble());
    return value.toString();
  }

  String _fmtInt(dynamic value) {
    if (value == null) return '—';
    if (value is int) return NumberFormat('#,##0').format(value);
    if (value is double) return NumberFormat('#,##0').format(value.toInt());
    return value.toString();
  }

  String _pct(dynamic value) {
    if (value == null) return '—';
    final d = value is int ? value.toDouble() : value as double;
    return '${(d * 100).toStringAsFixed(2)}%';
  }
}
