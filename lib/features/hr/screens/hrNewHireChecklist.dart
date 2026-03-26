// lib/features/hr/screens/hrNewHireChecklist.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:kleenops_admin/app/shared_widgets/navigation/details_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/home_navbar_adapter.dart';
import 'package:kleenops_admin/features/auth/providers/auth_provider.dart';
import 'package:shared_widgets/containers/canvas_top_bookend.dart';
import 'package:shared_widgets/containers/standard_canvas.dart';
import 'package:shared_widgets/containers/container_action.dart';
import 'package:shared_widgets/tiles/standard_tile_small.dart';

/// New-hire onboarding checklist screen.
/// Shows all required steps for a new employee with completion status.
class HrNewHireChecklistScreen extends ConsumerWidget {
  final String memberId;
  final String memberName;

  factory HrNewHireChecklistScreen.fromExtra(Map<String, dynamic>? extra) {
    final e = extra ?? {};
    return HrNewHireChecklistScreen(
      memberId: e['memberId'] as String? ?? '',
      memberName: e['memberName'] as String? ?? '',
    );
  }

  const HrNewHireChecklistScreen({
    super.key,
    required this.memberId,
    required this.memberName,
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
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: null,
      bottomNavigationBar: Consumer(
        builder: (context, ref, _) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DetailsAppBar(
                title: 'New Hire Checklist',
              ),
              const HomeNavBarAdapter(highlightSelected: false),
            ],
          );
        },
      ),
      body: _wrapCanvas(
          ref.watch(companyIdProvider).when(
                data: (companyRef) {
                  if (companyRef == null) {
                    return const Center(child: Text('No company'));
                  }
                  return _ChecklistBody(
                    companyRef: companyRef,
                    memberId: memberId,
                    memberName: memberName,
                  );
                },
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e')),
              ),
        ),
    );
  }
}

class _ChecklistBody extends StatelessWidget {
  final DocumentReference<Map<String, dynamic>> companyRef;
  final String memberId;
  final String memberName;

  const _ChecklistBody({
    required this.companyRef,
    required this.memberId,
    required this.memberName,
  });

  @override
  Widget build(BuildContext context) {
    final bottomInset = kBottomNavigationBarHeight +
        16.0 +
        MediaQuery.of(context).padding.bottom;

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('member').doc(memberId).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final data = snapshot.data?.data() ?? {};

        final startDate = data['startDate'] is Timestamp
            ? (data['startDate'] as Timestamp).toDate()
            : null;
        final hireStr = startDate != null
            ? DateFormat('yMMMd').format(startDate)
            : 'Not set';

        // Build checklist items
        final items = _buildChecklistItems(data);
        final completedCount = items.where((i) => i.done).length;

        return SingleChildScrollView(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Container(
                width: double.infinity,
                color: Colors.white,
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      memberName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Hire Date: $hireStr',
                      style: TextStyle(
                          fontSize: 14, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 8),
                    // Progress bar
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: items.isNotEmpty
                                  ? completedCount / items.length
                                  : 0,
                              minHeight: 6,
                              backgroundColor: Colors.grey[200],
                              valueColor: const AlwaysStoppedAnimation(
                                  Colors.green),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '$completedCount / ${items.length}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: completedCount == items.length
                                ? Colors.green[700]
                                : Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // ── Day 1 Requirements ──
              ContainerActionWidget(
                title: 'Day 1 — Before First Shift',
                actionText: '',
                content: Column(
                  children: items
                      .where((i) => i.category == 'day1')
                      .map((i) => _buildCheckItem(context, i))
                      .toList(),
                ),
              ),

              // ── Within 3 Days ──
              ContainerActionWidget(
                title: 'Within 3 Business Days',
                actionText: '',
                content: Column(
                  children: items
                      .where((i) => i.category == 'within3')
                      .map((i) => _buildCheckItem(context, i))
                      .toList(),
                ),
              ),

              // ── Within First Week ──
              ContainerActionWidget(
                title: 'First Week',
                actionText: '',
                content: Column(
                  children: items
                      .where((i) => i.category == 'week1')
                      .map((i) => _buildCheckItem(context, i))
                      .toList(),
                ),
              ),

              // ── Within 30 Days ──
              ContainerActionWidget(
                title: 'Within 30 Days',
                actionText: '',
                content: Column(
                  children: items
                      .where((i) => i.category == 'month1')
                      .map((i) => _buildCheckItem(context, i))
                      .toList(),
                ),
              ),

              // Navigate to employee edit
              Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => context.push(
                      '/hr/employeeEdit',
                      extra: {'documentId': memberId},
                    ),
                    icon: const Icon(Icons.edit, size: 18),
                    label: const Text('Edit Employee Record'),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCheckItem(BuildContext context, _CheckItem item) {
    return StandardTileSmallDart(
      label: item.title,
      secondaryText: item.subtitle,
      trailingIcon1: item.done
          ? Icons.check_circle
          : Icons.radio_button_unchecked,
    );
  }

  List<_CheckItem> _buildChecklistItems(Map<String, dynamic> data) {
    final w4 = data['w4OnFile'] == true;
    final i9 = data['i9Verified'] == true;
    final hasBank = (data['bankAccounts'] as List?)?.isNotEmpty ?? false;
    final paymentMethod =
        (data['paymentMethod'] ?? '').toString();
    final hasEmergency =
        data['emergencyContact'] is Map &&
            ((data['emergencyContact'] as Map)['name'] ?? '').toString().isNotEmpty;
    final hasAddress = data['address'] is Map;
    final hasSSN = (data['ssnLast4'] ?? '').toString().isNotEmpty;
    final hasRole = data['roleId'] != null;
    final hasPayRate = data['payRate'] != null;
    final hasWorkState = (data['workState'] ?? '').toString().isNotEmpty;
    final hasFiling =
        (data['federalFilingStatus'] ?? '').toString().isNotEmpty;
    final hasBenefits = false; // Would check benefitEnrollment subcollection

    return [
      // Day 1
      _CheckItem('day1', 'W-4 Federal Tax Form',
          w4 ? 'On file' : 'Required before first paycheck', w4),
      _CheckItem('day1', 'Personal Information',
          hasAddress ? 'Complete' : 'Name, address, DOB, SSN', hasAddress && hasSSN),
      _CheckItem('day1', 'Emergency Contact',
          hasEmergency ? 'On file' : 'Name, phone, relationship', hasEmergency),
      _CheckItem('day1', 'Role & Pay Rate',
          hasRole && hasPayRate ? 'Configured' : 'Assign role and set pay', hasRole && hasPayRate),

      // Within 3 days
      _CheckItem('within3', 'I-9 Employment Verification',
          i9 ? 'Verified' : 'Must complete within 3 business days of hire', i9),

      // Week 1
      _CheckItem('week1', 'Direct Deposit Setup',
          hasBank
              ? 'Bank account on file'
              : paymentMethod == 'paper_check'
                  ? 'Paper check selected'
                  : 'Bank routing + account needed',
          hasBank || paymentMethod == 'paper_check'),
      _CheckItem('week1', 'Work Location & State',
          hasWorkState ? 'State: ${data['workState']}' : 'Set work state for tax calculation',
          hasWorkState),
      _CheckItem('week1', 'Federal Filing Status',
          hasFiling ? data['federalFilingStatus'].toString() : 'Set W-4 filing status',
          hasFiling),

      // Month 1
      _CheckItem('month1', 'Benefits Enrollment',
          'Enroll in available benefit plans within 60 days', hasBenefits),
      _CheckItem('month1', 'Training Assignments',
          'Assign required training modules', false),
      _CheckItem('month1', 'Equipment & Supplies',
          'Issue cleaning supplies, uniforms, keys/badges', false),
    ];
  }
}

class _CheckItem {
  final String category;
  final String title;
  final String subtitle;
  final bool done;

  const _CheckItem(this.category, this.title, this.subtitle, this.done);
}
