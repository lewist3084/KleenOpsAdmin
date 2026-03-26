import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:kleenops_admin/app/routes.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/details_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/home_navbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/home_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/drawers/appbar_logout_adapter.dart';
import 'package:kleenops_admin/features/auth/providers/auth_provider.dart';
import 'package:shared_widgets/containers/canvas_top_bookend.dart';
import 'package:shared_widgets/containers/standard_canvas.dart';
import 'package:shared_widgets/drawers/menu_drawer.dart';

/// Top-level screen with its own Scaffold (app bar + content + bottom nav)
class FinancesStatsScreen extends StatelessWidget {
  const FinancesStatsScreen({super.key});

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
            title: 'Finance Stats',
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
          const FinanceStatsContent(),
      ),
      bottomNavigationBar: Consumer(
        builder: (context, ref, _) {
          final menuSections = MenuDrawerSections(
            actions: [
              ContentMenuItem(
                icon: Icons.home_outlined,
                label: 'Finances Home',
                onTap: () => context.push(AppRoutePaths.financeHome),
              ),
              ContentMenuItem(
                icon: Icons.list_alt_outlined,
                label: 'Ledger',
                onTap: () => context.push(AppRoutePaths.financeLedger),
              ),
              ContentMenuItem(
                icon: Icons.account_balance_outlined,
                label: 'Accounts',
                onTap: () => context.push(AppRoutePaths.financeAccounts),
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

class FinanceStatsContent extends ConsumerWidget {
  const FinanceStatsContent({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final companyAsync = ref.watch(companyIdProvider);
    final bottomPadding = kBottomNavigationBarHeight +
        16.0 +
        MediaQuery.of(context).padding.bottom;

    return companyAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
      data: (companyRef) {
        if (companyRef == null) {
          return const Center(child: Text('No company found'));
        }
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(16, 16, 16, bottomPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _StatSection(
                title: 'Invoices',
                icon: Icons.receipt_long_outlined,
                children: [
                  _StreamCountStat(
                    label: 'Outstanding',
                    stream: FirebaseFirestore.instance
                        .collection('invoice')
                        .where('status', whereIn: const ['sent', 'partial'])
                        .snapshots(),
                    sumField: 'amountDue',
                  ),
                  _StreamCountStat(
                    label: 'Overdue',
                    stream: FirebaseFirestore.instance
                        .collection('invoice')
                        .where('status', isEqualTo: 'overdue')
                        .snapshots(),
                    sumField: 'amountDue',
                  ),
                  _StreamCountStat(
                    label: 'Paid (all time)',
                    stream: FirebaseFirestore.instance
                        .collection('invoice')
                        .where('status', isEqualTo: 'paid')
                        .snapshots(),
                    sumField: 'total',
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _StatSection(
                title: 'Bills',
                icon: Icons.request_quote_outlined,
                children: [
                  _StreamCountStat(
                    label: 'Unpaid',
                    stream: FirebaseFirestore.instance
                        .collection('bill')
                        .where('status', whereIn: const ['unpaid', 'partial'])
                        .snapshots(),
                    sumField: 'total',
                  ),
                  _StreamCountStat(
                    label: 'Paid (all time)',
                    stream: FirebaseFirestore.instance
                        .collection('bill')
                        .where('status', isEqualTo: 'paid')
                        .snapshots(),
                    sumField: 'total',
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _StatSection(
                title: 'Customers',
                icon: Icons.people_outlined,
                children: [
                  _StreamCountStat(
                    label: 'Active',
                    stream: FirebaseFirestore.instance
                        .collection('customer')
                        .where('active', isEqualTo: true)
                        .snapshots(),
                  ),
                  _StreamCountStat(
                    label: 'Total owed',
                    stream: FirebaseFirestore.instance
                        .collection('customer')
                        .where('active', isEqualTo: true)
                        .snapshots(),
                    sumField: 'balance',
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _StatSection(
                title: 'Payments',
                icon: Icons.payments_outlined,
                children: [
                  _StreamCountStat(
                    label: 'Received',
                    stream: FirebaseFirestore.instance
                        .collection('payment')
                        .where('type', isEqualTo: 'received')
                        .snapshots(),
                    sumField: 'amount',
                  ),
                  _StreamCountStat(
                    label: 'Made',
                    stream: FirebaseFirestore.instance
                        .collection('payment')
                        .where('type', isEqualTo: 'made')
                        .snapshots(),
                    sumField: 'amount',
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StatSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _StatSection({
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

class _StreamCountStat extends StatelessWidget {
  final String label;
  final Stream<QuerySnapshot<Map<String, dynamic>>> stream;
  final String? sumField;

  const _StreamCountStat({
    required this.label,
    required this.stream,
    this.sumField,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snap) {
        final count = snap.data?.docs.length ?? 0;
        double sum = 0;
        if (sumField != null && snap.hasData) {
          for (final doc in snap.data!.docs) {
            final val = doc.data()[sumField!];
            if (val is num) sum += val.toDouble();
          }
        }

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label),
              Row(
                children: [
                  Text(
                    '$count',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  if (sumField != null) ...[
                    const SizedBox(width: 8),
                    Text(
                      '\$${sum.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
