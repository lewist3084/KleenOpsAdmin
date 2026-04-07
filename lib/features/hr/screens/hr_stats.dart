//  hr_stats.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kleenops_admin/app/routes.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/details_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/home_navbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/home_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/drawers/appbar_logout_adapter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kleenops_admin/features/auth/providers/auth_provider.dart';
import 'package:shared_widgets/containers/canvas_top_bookend.dart';
import 'package:shared_widgets/containers/standard_canvas.dart';
import 'package:shared_widgets/drawers/menu_drawer.dart';

/// Top-level screen with its own Scaffold (app bar + content + bottom nav)
class HrStatsScreen extends StatelessWidget {
  const HrStatsScreen({super.key});

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
            title: 'HR Stats',
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
          const HrStatsContent(),
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
                icon: Icons.groups_outlined,
                label: 'Teams',
                onTap: () => context.push(AppRoutePaths.hrTeam),
              ),
              ContentMenuItem(
                icon: Icons.badge,
                label: 'Roles',
                onTap: () => context.push(AppRoutePaths.hrRoles),
              ),
              ContentMenuItem(
                icon: Icons.calendar_month_outlined,
                label: 'Time Off',
                onTap: () => context.push(AppRoutePaths.hrTimeOff),
              ),
              ContentMenuItem(
                icon: Icons.qr_code_scanner,
                label: 'Scan Ticket',
                onTap: () => context.push(AppRoutePaths.hrTicketScanner),
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

class HrStatsContent extends ConsumerWidget {
  const HrStatsContent({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final companyRefAsync = ref.watch(companyIdProvider);
    final bottomPadding = kBottomNavigationBarHeight +
        16.0 +
        MediaQuery.of(context).padding.bottom;

    return companyRefAsync.when(
      data: (companyRef) {
        if (companyRef == null) {
          return const Center(child: Text('No company reference found.'));
        }

        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(16, 16, 16, bottomPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _HrStatCard(
                title: 'Employees',
                icon: Icons.badge_outlined,
                children: [
                  _HrStreamStat(
                    label: 'Active',
                    stream: FirebaseFirestore.instance
                        .collection('member')
                        .where('active', isEqualTo: true)
                        .snapshots(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _HrStatCard(
                title: 'Roles',
                icon: Icons.badge,
                children: [
                  _HrStreamStat(
                    label: 'Total',
                    stream: FirebaseFirestore.instance.collection('role').snapshots(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _HrStatCard(
                title: 'Teams',
                icon: Icons.groups_outlined,
                children: [
                  _HrStreamStat(
                    label: 'Total',
                    stream: FirebaseFirestore.instance.collection('team').snapshots(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _HrStatCard(
                title: 'Time Off',
                icon: Icons.calendar_month_outlined,
                children: [
                  _HrStreamStat(
                    label: 'Pending requests',
                    stream: FirebaseFirestore.instance
                        .collection('timeOff')
                        .where('status', isEqualTo: 'requested')
                        .snapshots(),
                  ),
                  _HrStreamStat(
                    label: 'Approved',
                    stream: FirebaseFirestore.instance
                        .collection('timeOff')
                        .where('status', isEqualTo: 'approved')
                        .snapshots(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _HrStatCard(
                title: 'Documents',
                icon: Icons.description_outlined,
                children: [
                  _HrStreamStat(
                    label: 'Total',
                    stream: FirebaseFirestore.instance
                        .collection('employeeDocument')
                        .snapshots(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _HrStatCard(
                title: 'Labor Rates',
                icon: Icons.attach_money,
                children: [
                  _HrStreamStat(
                    label: 'Defined rates',
                    stream: FirebaseFirestore.instance
                        .collection('standardLaborRates')
                        .snapshots(),
                  ),
                ],
              ),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }
}

class _HrStatCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _HrStatCard({
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: Colors.grey[700]),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const Divider(),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _HrStreamStat extends StatelessWidget {
  final String label;
  final Stream<QuerySnapshot<Map<String, dynamic>>> stream;

  const _HrStreamStat({
    required this.label,
    required this.stream,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snap) {
        final count = snap.data?.docs.length ?? 0;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label),
              Text(
                '$count',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

