// lib/features/compliance/screens/compliance_dashboard_screen.dart
//
// DEGRADED port: kleenops version reads from
// `companyRef.collection('complianceItem')` and uses
// `TaxComplianceService` (no admin equivalent — admin doesn't ship a
// per-company tax-obligations runtime). The admin port reads the
// top-level `complianceItem` collection and drops the "Where to Pay"
// federal/state portal directory. The compliance category sections,
// summary chips, and upcoming tax-filing deadlines all port intact.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:kleenops_admin/app/routes.dart';
import 'package:kleenops_admin/app/shared_widgets/drawers/appbar_logout_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/details_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/home_navbar_adapter.dart';
import 'package:kleenops_admin/theme/palette.dart';
import 'package:shared_widgets/containers/canvas_top_bookend.dart';
import 'package:shared_widgets/containers/container_action.dart';
import 'package:shared_widgets/containers/standard_canvas.dart';
import 'package:shared_widgets/drawers/menu_drawer.dart';
import 'package:shared_widgets/tiles/standard_tile_small.dart';

class ComplianceDashboardScreen extends StatelessWidget {
  const ComplianceDashboardScreen({super.key});

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
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: null,
      drawer: const UserDrawer(),
      body: _wrapCanvas(const _DashboardContent()),
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
                icon: Icons.verified_user_outlined,
                label: 'Admin Compliance',
                onTap: () => context.push(AppRoutePaths.adminCompliance),
              ),
            ],
          );
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DetailsAppBar(
                title: 'Compliance',
                menuSections: menuSections,
              ),
              const HomeNavBarAdapter(),
            ],
          );
        },
      ),
    );
  }
}

class _DashboardContent extends StatelessWidget {
  const _DashboardContent();

  @override
  Widget build(BuildContext context) {
    const bottomInset = 16.0;

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('complianceItem')
          .orderBy('position')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final allDocs = snapshot.data?.docs ?? [];

        if (allDocs.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.verified_user_outlined,
                      size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No compliance items yet',
                    style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Complete the Company Setup Wizard to generate your compliance checklist.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
          );
        }

        final federal =
            allDocs.where((d) => d.data()['category'] == 'federal').toList();
        final state =
            allDocs.where((d) => d.data()['category'] == 'state').toList();
        final insurance =
            allDocs.where((d) => d.data()['category'] == 'insurance').toList();

        int pending = 0;
        int complete = 0;
        int overdue = 0;
        for (final doc in allDocs) {
          final status = doc.data()['status'];
          if (status == 'complete') {
            complete++;
          } else if (status == 'overdue') {
            overdue++;
          } else {
            pending++;
          }
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: bottomInset),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SummaryRow(
                total: allDocs.length,
                complete: complete,
                pending: pending,
                overdue: overdue,
              ),
              const _TaxDeadlineSection(),
              if (federal.isNotEmpty)
                _ComplianceCategorySection(
                  title: 'Federal Requirements',
                  icon: Icons.account_balance,
                  docs: federal,
                ),
              if (state.isNotEmpty)
                _ComplianceCategorySection(
                  title: 'State Requirements',
                  icon: Icons.location_on_outlined,
                  docs: state,
                ),
              if (insurance.isNotEmpty)
                _ComplianceCategorySection(
                  title: 'Insurance',
                  icon: Icons.health_and_safety_outlined,
                  docs: insurance,
                ),
            ],
          ),
        );
      },
    );
  }
}

// ──────────────── Summary Row ────────────────

class _SummaryRow extends StatelessWidget {
  final int total;
  final int complete;
  final int pending;
  final int overdue;

  const _SummaryRow({
    required this.total,
    required this.complete,
    required this.pending,
    required this.overdue,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AppPaletteScope.of(context);
    final pct = total > 0 ? (complete / total * 100).round() : 0;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Text(
                  '$pct% Complete',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: palette.primary2,
                  ),
                ),
                const Spacer(),
                Text(
                  '$complete of $total items',
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: total > 0 ? complete / total : 0,
                minHeight: 6,
                backgroundColor: Colors.grey[200],
                valueColor: AlwaysStoppedAnimation(palette.primary4),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _StatusChip(
                  label: 'Complete',
                  count: complete,
                  color: Colors.green,
                  icon: Icons.check_circle,
                ),
                _StatusChip(
                  label: 'Pending',
                  count: pending,
                  color: Colors.orange,
                  icon: Icons.schedule,
                ),
                _StatusChip(
                  label: 'Overdue',
                  count: overdue,
                  color: Colors.red,
                  icon: Icons.warning_amber,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final int count;
  final MaterialColor color;
  final IconData icon;

  const _StatusChip({
    required this.label,
    required this.count,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color[600]),
        const SizedBox(width: 4),
        Text(
          '$count $label',
          style: TextStyle(fontSize: 12, color: color[700]),
        ),
      ],
    );
  }
}

// ──────────────── Category Section ────────────────

class _ComplianceCategorySection extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;

  const _ComplianceCategorySection({
    required this.title,
    required this.icon,
    required this.docs,
  });

  @override
  Widget build(BuildContext context) {
    final completedCount =
        docs.where((d) => d.data()['status'] == 'complete').length;

    return ContainerActionWidget(
      title: '$title ($completedCount/${docs.length})',
      actionText: '',
      content: Column(
        children: docs.map((doc) {
          final data = doc.data();
          final itemTitle = (data['title'] ?? '').toString();
          final status = (data['status'] ?? 'pending').toString();
          final recurring = data['recurring'] == true;

          return StandardTileSmallDart(
            label: itemTitle,
            secondaryText: [
              _formatStatus(status),
              if (recurring) 'Recurring',
            ].join(' · '),
            labelIcon: icon,
            trailingIcon1: _statusIcon(status),
            onTap: () => context.push(
              AppRoutePaths.adminCompliance,
              extra: {'docId': doc.id},
            ),
          );
        }).toList(),
      ),
    );
  }

  String _formatStatus(String status) {
    switch (status) {
      case 'complete':
        return 'Complete';
      case 'overdue':
        return 'Overdue';
      case 'notApplicable':
        return 'N/A';
      default:
        return 'Pending';
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'complete':
        return Icons.check_circle;
      case 'overdue':
        return Icons.warning_amber;
      case 'notApplicable':
        return Icons.remove_circle_outline;
      default:
        return Icons.radio_button_unchecked;
    }
  }
}

// ──────────────── Tax Filing Deadline Section ────────────────

class _TaxDeadlineSection extends StatelessWidget {
  const _TaxDeadlineSection();

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final deadlines = _generateUpcomingDeadlines(now);

    if (deadlines.isEmpty) return const SizedBox.shrink();

    return ContainerActionWidget(
      title: 'Upcoming Tax Filing Deadlines',
      actionText: '',
      content: Column(
        children: deadlines.map((d) {
          final daysUntil = d.dueDate.difference(now).inDays;
          final isOverdue = daysUntil < 0;
          final isUrgent = daysUntil >= 0 && daysUntil <= 14;

          return StandardTileSmallDart(
            label: d.title,
            secondaryText: [
              DateFormat('MMM d, yyyy').format(d.dueDate),
              if (isOverdue)
                '${-daysUntil} days overdue'
              else if (daysUntil == 0)
                'Due today'
              else
                '$daysUntil days left',
            ].join(' · '),
            labelIcon: d.icon,
            trailingIcon1: isOverdue
                ? Icons.error
                : isUrgent
                    ? Icons.warning_amber
                    : Icons.schedule,
          );
        }).toList(),
      ),
    );
  }

  List<_Deadline> _generateUpcomingDeadlines(DateTime now) {
    final year = now.year;
    final deadlines = <_Deadline>[];

    final q941Dates = [
      DateTime(year, 4, 30),
      DateTime(year, 7, 31),
      DateTime(year, 10, 31),
      DateTime(year + 1, 1, 31),
    ];
    final q941Labels = ['Q1', 'Q2', 'Q3', 'Q4'];
    for (int i = 0; i < q941Dates.length; i++) {
      deadlines.add(_Deadline(
        title: 'Form 941 – ${q941Labels[i]} $year',
        dueDate: q941Dates[i],
        icon: Icons.account_balance,
        category: 'federal',
      ));
    }

    deadlines.add(_Deadline(
      title: 'Form 940 – Annual FUTA Return',
      dueDate: DateTime(year + 1, 1, 31),
      icon: Icons.account_balance,
      category: 'federal',
    ));

    deadlines.add(_Deadline(
      title: 'W-2 / W-3 – Annual Wage Statements',
      dueDate: DateTime(year + 1, 1, 31),
      icon: Icons.description,
      category: 'federal',
    ));

    deadlines.add(_Deadline(
      title: '1099-NEC – Contractor Payments',
      dueDate: DateTime(year + 1, 1, 31),
      icon: Icons.description,
      category: 'federal',
    ));

    for (int i = 0; i < q941Dates.length; i++) {
      deadlines.add(_Deadline(
        title: 'State Withholding – ${q941Labels[i]} $year',
        dueDate: q941Dates[i],
        icon: Icons.location_on_outlined,
        category: 'state',
      ));
    }

    for (int i = 0; i < q941Dates.length; i++) {
      deadlines.add(_Deadline(
        title: 'State Unemployment (SUTA) – ${q941Labels[i]} $year',
        dueDate: q941Dates[i],
        icon: Icons.location_on_outlined,
        category: 'state',
      ));
    }

    deadlines.sort((a, b) => a.dueDate.compareTo(b.dueDate));
    return deadlines
        .where((d) {
          final diff = d.dueDate.difference(now).inDays;
          return diff >= -30 && diff <= 90;
        })
        .toList();
  }
}

class _Deadline {
  final String title;
  final DateTime dueDate;
  final IconData icon;
  final String category;

  const _Deadline({
    required this.title,
    required this.dueDate,
    required this.icon,
    required this.category,
  });
}
