// lib/features/hr/screens/hr_benefits.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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

class HrBenefitsScreen extends StatelessWidget {
  const HrBenefitsScreen({super.key});

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
            title: 'Benefits',
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
                      return _BenefitsContent(companyRef: companyRef);
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
                icon: Icons.person_add_outlined,
                label: 'Onboarding',
                onTap: () => context.push(AppRoutePaths.hrOnboarding),
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

class _BenefitsContent extends StatelessWidget {
  final DocumentReference<Map<String, dynamic>> companyRef;

  const _BenefitsContent({required this.companyRef});

  @override
  Widget build(BuildContext context) {
    final bottomInset =
        kBottomNavigationBarHeight + 16.0 + MediaQuery.of(context).padding.bottom;

    return SingleChildScrollView(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Active Benefit Plans ──
          ContainerActionWidget(
            title: 'Benefit Plans',
            actionText: 'New Plan',
            onAction: () => context.push(AppRoutePaths.hrBenefitPlanForm),
            content: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('benefitPlan')
                  .where('active', isEqualTo: true)
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
                      'No benefit plans configured. Create one to get started.',
                      style: TextStyle(color: Colors.grey[500]),
                    ),
                  );
                }
                return Column(
                  children: docs.map((doc) {
                    final data = doc.data();
                    final name = (data['name'] ?? 'Untitled').toString();
                    final type = (data['type'] ?? '').toString();
                    final provider = (data['provider'] ?? '').toString();
                    final employerContrib = data['employerContribution'];
                    final employeeContrib = data['employeeContribution'];

                    final subtitle = [
                      if (provider.isNotEmpty) provider,
                      if (employerContrib != null)
                        'ER: \$${employerContrib}',
                      if (employeeContrib != null)
                        'EE: \$${employeeContrib}',
                    ].join(' · ');

                    return StandardTileSmallDart(
                      label: name,
                      secondaryText: subtitle.isNotEmpty ? subtitle : null,
                      labelIcon: _iconForBenefitType(type),
                      trailingIcon1: Icons.chevron_right,
                      onTap: () => context.push(
                        AppRoutePaths.hrBenefitPlanDetails,
                        extra: {'docId': doc.id, 'name': name},
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ),

          // ── Benefit types summary ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                border: Border.all(color: Colors.blue[200]!),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Supported Benefit Types',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.blue[900],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _benefitTypeChip('Health', Icons.local_hospital_outlined),
                      _benefitTypeChip('Dental', Icons.mood_outlined),
                      _benefitTypeChip('Vision', Icons.visibility_outlined),
                      _benefitTypeChip('Life', Icons.shield_outlined),
                      _benefitTypeChip('401k', Icons.savings_outlined),
                      _benefitTypeChip('HSA', Icons.account_balance_wallet_outlined),
                      _benefitTypeChip('FSA', Icons.receipt_long_outlined),
                      _benefitTypeChip('PTO', Icons.beach_access_outlined),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _benefitTypeChip(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.blue[700]),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.blue[800]),
          ),
        ],
      ),
    );
  }

  IconData _iconForBenefitType(String type) {
    switch (type) {
      case 'health':
        return Icons.local_hospital_outlined;
      case 'dental':
        return Icons.mood_outlined;
      case 'vision':
        return Icons.visibility_outlined;
      case 'life':
        return Icons.shield_outlined;
      case '401k':
        return Icons.savings_outlined;
      case 'hsa':
        return Icons.account_balance_wallet_outlined;
      case 'fsa':
        return Icons.receipt_long_outlined;
      case 'pto':
        return Icons.beach_access_outlined;
      default:
        return Icons.health_and_safety_outlined;
    }
  }
}
