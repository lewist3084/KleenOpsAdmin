// lib/features/finances/screens/financePayroll.dart

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

class FinancePayrollScreen extends StatelessWidget {
  const FinancePayrollScreen({super.key});

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
            title: 'Payroll',
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
                      return _PayrollContent(companyRef: companyRef);
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
                icon: Icons.receipt_long_outlined,
                label: 'Invoices',
                onTap: () => context.push(AppRoutePaths.financeInvoices),
              ),
              ContentMenuItem(
                icon: Icons.payments_outlined,
                label: 'Payments',
                onTap: () => context.push(AppRoutePaths.financePayments),
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

class _PayrollContent extends StatelessWidget {
  final DocumentReference<Map<String, dynamic>> companyRef;

  const _PayrollContent({required this.companyRef});

  @override
  Widget build(BuildContext context) {
    final bottomInset =
        kBottomNavigationBarHeight + 16.0 + MediaQuery.of(context).padding.bottom;
    final fmt = NumberFormat('#,##0.00');

    return SingleChildScrollView(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ContainerActionWidget(
            title: 'Payroll Runs',
            actionText: 'New Run',
            onAction: () => context.push(AppRoutePaths.financePayrollRunForm),
            content: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('payrollRun')
                  .orderBy('payDate', descending: true)
                  .limit(20)
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
                      'No payroll runs yet. Create one to calculate paychecks.',
                      style: TextStyle(color: Colors.grey[500]),
                    ),
                  );
                }
                return Column(
                  children: docs.map((doc) {
                    final data = doc.data();
                    final status =
                        (data['status'] ?? 'draft').toString();
                    final payDate = data['payDate'];
                    final dateStr = payDate is Timestamp
                        ? DateFormat('yMMMd').format(payDate.toDate())
                        : '—';
                    final totalNet = data['totalNet'];
                    final empCount = data['employeeCount'] ?? 0;

                    final periodStart = data['payPeriodStart'];
                    final periodEnd = data['payPeriodEnd'];
                    final periodStr = (periodStart is Timestamp &&
                            periodEnd is Timestamp)
                        ? '${DateFormat('M/d').format(periodStart.toDate())} - '
                            '${DateFormat('M/d').format(periodEnd.toDate())}'
                        : '';

                    return StandardTileSmallDart(
                      label: 'Pay Date: $dateStr',
                      secondaryText: [
                        if (periodStr.isNotEmpty) periodStr,
                        '$empCount employees',
                        if (totalNet != null) '\$${fmt.format(totalNet)}',
                      ].join(' · '),
                      labelIcon: _iconForStatus(status),
                      trailingIcon1: Icons.chevron_right,
                      onTap: () => context.push(
                        AppRoutePaths.financePayrollRunDetails,
                        extra: {'runId': doc.id},
                      ),
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

  IconData _iconForStatus(String status) {
    switch (status) {
      case 'draft':
        return Icons.edit_note;
      case 'approved':
        return Icons.thumb_up_outlined;
      case 'processed':
        return Icons.check_circle_outline;
      case 'paid':
        return Icons.paid_outlined;
      default:
        return Icons.receipt_long_outlined;
    }
  }
}
