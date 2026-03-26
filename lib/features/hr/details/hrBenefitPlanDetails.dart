// lib/features/hr/details/hrBenefitPlanDetails.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:kleenops_admin/app/routes.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/details_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/home_navbar_adapter.dart';
import 'package:kleenops_admin/features/auth/providers/auth_provider.dart';
import 'package:kleenops_admin/theme/palette.dart';
import 'package:shared_widgets/containers/canvas_top_bookend.dart';
import 'package:shared_widgets/containers/standard_canvas.dart';
import 'package:shared_widgets/containers/container_action.dart';
import 'package:shared_widgets/tiles/standard_tile_small.dart';

class HrBenefitPlanDetailsScreen extends ConsumerWidget {
  final String docId;
  final String name;

  factory HrBenefitPlanDetailsScreen.fromExtra(Map<String, dynamic>? extra) {
    final e = extra ?? {};
    return HrBenefitPlanDetailsScreen(
      docId: e['docId'] as String? ?? '',
      name: e['name'] as String? ?? '',
    );
  }

  const HrBenefitPlanDetailsScreen({
    super.key,
    required this.docId,
    required this.name,
  });

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
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = AppPaletteScope.of(context);
    final bool hideChrome = false;

    Widget buildBottomBar({VoidCallback? onAiPressed}) {
      if (hideChrome) return const SizedBox.shrink();
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DetailsAppBar(
            title: name,
            onAiPressed: onAiPressed,
          ),
          const HomeNavBarAdapter(highlightSelected: false),
        ],
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: null,
      bottomNavigationBar: Consumer(
        builder: (context, ref, _) {
          return buildBottomBar();
        },
      ),
      body: _wrapCanvas(
          ref.watch(companyIdProvider).when(
                data: (companyRef) {
                  if (companyRef == null) {
                    return const Center(child: Text('No company'));
                  }
                  return _PlanDetailsBody(
                    companyRef: companyRef,
                    docId: docId,
                    name: name,
                  );
                },
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e')),
              ),
        ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: palette.primary1.withAlpha(220),
        tooltip: 'Edit Plan',
        child: const Icon(Icons.edit),
        onPressed: () {
          context.push(
            AppRoutePaths.hrBenefitPlanForm,
            extra: {'docId': docId},
          );
        },
      ),
    );
  }
}

class _PlanDetailsBody extends StatelessWidget {
  final DocumentReference<Map<String, dynamic>> companyRef;
  final String docId;
  final String name;

  const _PlanDetailsBody({
    required this.companyRef,
    required this.docId,
    required this.name,
  });

  @override
  Widget build(BuildContext context) {
    final planStream =
        FirebaseFirestore.instance.collection('benefitPlan').doc(docId).snapshots();
    final bottomInset =
        kBottomNavigationBarHeight + 16.0 + MediaQuery.of(context).padding.bottom;

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: planStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final data = snapshot.data?.data() ?? {};

        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(16, 16, 16, bottomInset),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Plan summary card ──
              _planSummaryCard(data),
              const SizedBox(height: 16),

              // ── Contributions ──
              _detailSection('Contributions (per pay period)', [
                _detailRow(Icons.business, 'Employer',
                    '\$${_fmt(data['employerContribution'])}'),
                _detailRow(Icons.person, 'Employee',
                    '\$${_fmt(data['employeeContribution'])}'),
              ]),

              // ── Eligibility ──
              _detailSection('Eligibility', [
                _detailRow(Icons.check_circle_outline, 'Type',
                    _formatEligibility(data['eligibilityType']?.toString() ?? '')),
                if (data['eligibilityType'] == 'custom')
                  _detailRow(Icons.schedule, 'Min Hours',
                      '${data['eligibilityMinHours'] ?? 30} hrs/week'),
                _detailRow(Icons.hourglass_empty, 'Waiting Period',
                    '${data['waitingPeriodDays'] ?? 90} days'),
                _detailRow(Icons.date_range, 'Enrollment Window',
                    '${data['enrollmentWindowDays'] ?? 30} days'),
              ]),

              // ── Enrolled employees ──
              const SizedBox(height: 8),
              _EnrolledEmployeesSection(
                companyRef: companyRef,
                planId: docId,
                planName: name,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _planSummaryCard(Map<String, dynamic> data) {
    final type = (data['type'] ?? '').toString();
    final provider = (data['provider'] ?? '').toString();
    final planNumber = (data['planNumber'] ?? '').toString();
    final active = data['active'] ?? true;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_iconForType(type), size: 28, color: Colors.blue[700]),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: active ? Colors.green[50] : Colors.red[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: active ? Colors.green[300]! : Colors.red[300]!,
                  ),
                ),
                child: Text(
                  active ? 'Active' : 'Inactive',
                  style: TextStyle(
                    fontSize: 12,
                    color: active ? Colors.green[800] : Colors.red[800],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (type.isNotEmpty)
            _infoChip(_formatBenefitType(type)),
          if (provider.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('Provider: $provider',
                style: TextStyle(fontSize: 14, color: Colors.grey[600])),
          ],
          if (planNumber.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text('Plan #: $planNumber',
                style: TextStyle(fontSize: 13, color: Colors.grey[500])),
          ],
        ],
      ),
    );
  }

  Widget _infoChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 12, color: Colors.blue[800]),
      ),
    );
  }

  Widget _detailSection(String title, List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
                letterSpacing: 0.5,
              )),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey[600]),
          const SizedBox(width: 10),
          SizedBox(
            width: 130,
            child: Text(label,
                style: TextStyle(fontSize: 13, color: Colors.grey[600])),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 14)),
          ),
        ],
      ),
    );
  }

  String _fmt(dynamic v) {
    if (v == null) return '0.00';
    if (v is double) return NumberFormat('#,##0.00').format(v);
    if (v is int) return NumberFormat('#,##0.00').format(v.toDouble());
    return v.toString();
  }

  String _formatEligibility(String type) {
    switch (type) {
      case 'full-time':
        return 'Full-Time Only';
      case 'all':
        return 'All Employees';
      case 'custom':
        return 'Custom (min hours)';
      default:
        return type;
    }
  }

  String _formatBenefitType(String type) {
    switch (type) {
      case 'health': return 'Health Insurance';
      case 'dental': return 'Dental Insurance';
      case 'vision': return 'Vision Insurance';
      case 'life': return 'Life Insurance';
      case '401k': return '401(k) Retirement';
      case 'hsa': return 'HSA';
      case 'fsa': return 'FSA';
      case 'pto': return 'Paid Time Off';
      default: return type;
    }
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'health': return Icons.local_hospital_outlined;
      case 'dental': return Icons.mood_outlined;
      case 'vision': return Icons.visibility_outlined;
      case 'life': return Icons.shield_outlined;
      case '401k': return Icons.savings_outlined;
      case 'hsa': return Icons.account_balance_wallet_outlined;
      case 'fsa': return Icons.receipt_long_outlined;
      case 'pto': return Icons.beach_access_outlined;
      default: return Icons.health_and_safety_outlined;
    }
  }
}

// ─────────────────── Enrolled Employees Section ───────────────────

class _EnrolledEmployeesSection extends StatelessWidget {
  final DocumentReference<Map<String, dynamic>> companyRef;
  final String planId;
  final String planName;

  const _EnrolledEmployeesSection({
    required this.companyRef,
    required this.planId,
    required this.planName,
  });

  @override
  Widget build(BuildContext context) {
    // Query members who have this plan in their enrollments array
    final enrollmentStream = FirebaseFirestore.instance
        .collection('benefitEnrollment')
        .where('benefitPlanId', isEqualTo:
            FirebaseFirestore.instance.collection('benefitPlan').doc(planId))
        .where('status', isEqualTo: 'active')
        .snapshots();

    return ContainerActionWidget(
      title: 'Enrolled Employees',
      actionText: 'Enroll Employee',
      onAction: () => context.push(
        AppRoutePaths.hrBenefitEnrollmentForm,
        extra: {'planId': planId, 'planName': planName},
      ),
      content: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: enrollmentStream,
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
                'No employees enrolled in this plan yet.',
                style: TextStyle(color: Colors.grey[500]),
              ),
            );
          }
          return Column(
            children: docs.map((doc) {
              final data = doc.data();
              final memberName =
                  (data['memberName'] ?? 'Unknown').toString();
              final status = (data['status'] ?? '').toString();
              final effectiveDate = data['effectiveDate'];
              final dateStr = effectiveDate is Timestamp
                  ? DateFormat('yMMMd').format(effectiveDate.toDate())
                  : '';
              final eeCost = data['employeeContribution'];

              return StandardTileSmallDart(
                label: memberName,
                secondaryText: [
                  if (dateStr.isNotEmpty) 'Since $dateStr',
                  if (eeCost != null) 'EE: \$$eeCost/period',
                ].join(' · '),
                labelIcon: Icons.person_outline,
                trailingIcon1: status == 'active'
                    ? Icons.check_circle
                    : Icons.radio_button_unchecked,
              );
            }).toList(),
          );
        },
      ),
    );
  }
}
