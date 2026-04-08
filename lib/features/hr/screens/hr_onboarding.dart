// lib/features/hr/screens/hr_onboarding.dart

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
import 'package:shared_widgets/containers/canvas_top_bookend.dart';
import 'package:shared_widgets/containers/standard_canvas.dart';
import 'package:shared_widgets/containers/container_action.dart';
import 'package:shared_widgets/drawers/menu_drawer.dart';
import 'package:shared_widgets/tiles/standard_tile_small.dart';

class HrOnboardingScreen extends StatelessWidget {
  const HrOnboardingScreen({super.key});

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
            title: 'Onboarding',
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
                      return _OnboardingContent(companyRef: companyRef);
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
                icon: Icons.badge_outlined,
                label: 'Employees',
                onTap: () => context.push(AppRoutePaths.hrEmployees),
              ),
              ContentMenuItem(
                icon: Icons.health_and_safety_outlined,
                label: 'Benefits',
                onTap: () => context.push(AppRoutePaths.hrBenefits),
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

String _formatEmploymentType(String value) {
  switch (value) {
    case 'fullTime':
      return 'Full-Time';
    case 'partTime':
      return 'Part-Time';
    case 'contractor':
      return 'Contractor';
    default:
      return value;
  }
}

class _OnboardingContent extends StatelessWidget {
  final DocumentReference<Map<String, dynamic>> companyRef;

  const _OnboardingContent({required this.companyRef});

  @override
  Widget build(BuildContext context) {
    final bottomInset =
        kBottomNavigationBarHeight + 16.0 + MediaQuery.of(context).padding.bottom;

    // Active onboardings: members with onboarding in progress
    final activeStream = FirebaseFirestore.instance
        .collection('member')
        .where('active', isEqualTo: true)
        .where('onboardingStatus', isEqualTo: 'in_progress')
        .snapshots();

    // Recently completed
    final completedStream = FirebaseFirestore.instance
        .collection('member')
        .where('onboardingStatus', isEqualTo: 'completed')
        .orderBy('onboardingCompletedDate', descending: true)
        .limit(10)
        .snapshots();

    return SingleChildScrollView(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Active Onboardings ──
          ContainerActionWidget(
            title: 'Active Onboardings',
            isEmpty: false,
            showEmptyDisclaimer: true,
            emptyDisclaimer: 'No employees currently onboarding',
            actionText: 'Start Onboarding',
            onAction: () => _showStartOnboardingDialog(context),
            content: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: activeStream,
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
                      'No employees currently onboarding.',
                      style: TextStyle(color: Colors.grey[500]),
                    ),
                  );
                }
                return Column(
                  children: docs.map((doc) {
                    final data = doc.data();
                    final name = (data['name'] ?? 'Unknown').toString();
                    final steps = data['onboardingSteps'] as List? ?? [];
                    final completed =
                        steps.where((s) => s['status'] == 'completed').length;
                    final total = steps.length;

                    return StandardTileSmallDart(
                      label: name,
                      secondaryText: '$completed / $total steps completed',
                      labelIcon: Icons.person_outline,
                      trailingIcon1: Icons.chevron_right,
                      onTap: () => context.push(
                        AppRoutePaths.hrOnboardingDetails,
                        extra: {'documentId': doc.id, 'name': name},
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ),

          // ── Onboarding Profiles ──
          ContainerActionWidget(
            title: 'Onboarding Profiles',
            actionText: 'New Profile',
            onAction: () => context.push(AppRoutePaths.hrOnboardingProfileForm),
            content: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: companyRef
                  .collection('onboardingProfile')
                  .orderBy('name')
                  .snapshots(),
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
                      'No onboarding profiles yet. Create one to apply preset defaults at scan time.',
                      style: TextStyle(color: Colors.grey[500]),
                    ),
                  );
                }
                return Column(
                  children: docs.map((doc) {
                    final data = doc.data();
                    final name = (data['name'] ?? 'Untitled').toString();
                    final employmentType =
                        (data['employmentType'] as String?) ?? '';
                    final payType = (data['payType'] as String?) ?? '';
                    final summary = [
                      if (employmentType.isNotEmpty)
                        _formatEmploymentType(employmentType),
                      if (payType.isNotEmpty)
                        payType[0].toUpperCase() + payType.substring(1),
                    ].join(' · ');

                    return StandardTileSmallDart(
                      label: name,
                      secondaryText: summary.isEmpty ? null : summary,
                      labelIcon: Icons.assignment_ind_outlined,
                      trailingIcon1: Icons.edit,
                      onTrailing1Tap: () => context.push(
                        AppRoutePaths.hrOnboardingProfileForm,
                        extra: {'docId': doc.id},
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ),

          // ── Onboarding Templates ──
          ContainerActionWidget(
            title: 'Onboarding Templates',
            actionText: 'New Template',
            onAction: () => context.push(AppRoutePaths.hrOnboardingTemplateForm),
            content: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('onboardingTemplate')
                  .orderBy('name')
                  .snapshots(),
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
                      'No onboarding templates yet. Create one to get started.',
                      style: TextStyle(color: Colors.grey[500]),
                    ),
                  );
                }
                return Column(
                  children: docs.map((doc) {
                    final data = doc.data();
                    final name = (data['name'] ?? 'Untitled').toString();
                    final steps = data['steps'] as List? ?? [];

                    return StandardTileSmallDart(
                      label: name,
                      secondaryText: '${steps.length} steps',
                      labelIcon: Icons.list_alt,
                      trailingIcon1: Icons.edit,
                      onTrailing1Tap: () => context.push(
                        AppRoutePaths.hrOnboardingTemplateForm,
                        extra: {'docId': doc.id},
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ),

          // ── Recently Completed ──
          ContainerActionWidget(
            title: 'Recently Completed',
            actionText: '',
            content: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: completedStream,
              builder: (context, snapshot) {
                final docs = snapshot.data?.docs ?? [];
                if (docs.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'No completed onboardings yet.',
                      style: TextStyle(color: Colors.grey[500]),
                    ),
                  );
                }
                return Column(
                  children: docs.map((doc) {
                    final data = doc.data();
                    final name = (data['name'] ?? 'Unknown').toString();
                    final completedDate = data['onboardingCompletedDate'];
                    final dateStr = completedDate is Timestamp
                        ? DateFormat('yMMMd').format(completedDate.toDate())
                        : '';

                    return StandardTileSmallDart(
                      label: name,
                      secondaryText:
                          dateStr.isNotEmpty ? 'Completed $dateStr' : 'Completed',
                      labelIcon: Icons.check_circle_outline,
                    );
                  }).toList(),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showStartOnboardingDialog(BuildContext context) {
    // Navigate to employee list to select who to onboard
    // For now, show a simple message
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
            'Select an employee from the Employees list, then use the Edit form to begin their onboarding.'),
      ),
    );
  }
}
