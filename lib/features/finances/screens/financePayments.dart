// lib/features/finances/screens/financePayments.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:kleenops_admin/app/routes.dart';
import 'package:kleenops_admin/features/auth/providers/auth_provider.dart';
import 'package:kleenops_admin/features/finances/forms/financePaymentForm.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/details_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/home_navbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/home_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/drawers/appbar_logout_adapter.dart';
import 'package:shared_widgets/containers/canvas_top_bookend.dart';
import 'package:shared_widgets/containers/standard_canvas.dart';
import 'package:shared_widgets/drawers/menu_drawer.dart';
import 'package:shared_widgets/tiles/standard_tile_small.dart';

class FinancePaymentsScreen extends StatelessWidget {
  const FinancePaymentsScreen({super.key});

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
    Widget buildBottomBar({
      VoidCallback? onAiPressed,
      MenuDrawerSections? menuSections,
    }) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DetailsAppBar(
            title: 'Payments',
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
          const FinancePaymentsContent(),
      ),
      bottomNavigationBar: Consumer(
        builder: (context, ref, _) {
          final menuSections = MenuDrawerSections(
            actions: [
              ContentMenuItem(
                icon: Icons.home_outlined,
                label: 'Finance Home',
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

class FinancePaymentsContent extends ConsumerStatefulWidget {
  const FinancePaymentsContent({super.key});

  @override
  ConsumerState<FinancePaymentsContent> createState() =>
      _FinancePaymentsContentState();
}

class _FinancePaymentsContentState
    extends ConsumerState<FinancePaymentsContent> {
  final _currencyFormat = NumberFormat.currency(symbol: '\$');
  final _dateFormat = DateFormat.yMMMd();

  @override
  Widget build(BuildContext context) {
    final companyAsync = ref.watch(companyIdProvider);

    return companyAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
      data: (companyRef) {
        if (companyRef == null) {
          return const Center(child: Text('No company found'));
        }

        return DefaultTabController(
          length: 2,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Row(
                  children: [
                    const Expanded(
                      child: TabBar(
                        tabs: [
                          Tab(text: 'Received'),
                          Tab(text: 'Made'),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    FloatingActionButton.small(
                      heroTag: 'addPayment',
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                FinancePaymentForm(companyRef: companyRef),
                          ),
                        );
                      },
                      child: const Icon(Icons.add),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    _buildPaymentList(companyRef, 'received'),
                    _buildPaymentList(companyRef, 'made'),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPaymentList(
    DocumentReference<Map<String, dynamic>> companyRef,
    String type,
  ) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('payment')
          .where('type', isEqualTo: type)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Text(
              type == 'received'
                  ? 'No payments received'
                  : 'No payments made',
              style: const TextStyle(fontSize: 16),
            ),
          );
        }

        final docs = snapshot.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 100),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data();
            final amount =
                (data['amount'] as num?)?.toDouble() ?? 0.0;
            final method = (data['method'] ?? '') as String;
            final ts = data['createdAt'] as Timestamp?;
            final dateStr =
                ts != null ? _dateFormat.format(ts.toDate()) : '';

            // Linked invoice or bill number.
            String linkedLabel = '';
            if (type == 'received') {
              final invoiceNumber =
                  (data['invoiceNumber'] ?? '') as String;
              if (invoiceNumber.isNotEmpty) {
                linkedLabel = 'Invoice #$invoiceNumber';
              }
            } else {
              final billNumber =
                  (data['billNumber'] ?? '') as String;
              if (billNumber.isNotEmpty) {
                linkedLabel = 'Bill #$billNumber';
              }
            }

            final secondaryParts = <String>[
              if (dateStr.isNotEmpty) dateStr,
              if (method.isNotEmpty) method,
              if (linkedLabel.isNotEmpty) linkedLabel,
            ];

            return StandardTileSmallDart(
              label: _currencyFormat.format(amount),
              secondaryText: secondaryParts.join('  |  '),
              leadingIcon: type == 'received'
                  ? Icons.arrow_downward
                  : Icons.arrow_upward,
              leadingIconColor:
                  type == 'received' ? Colors.green : Colors.red,
              trailingIcon1: Icons.chevron_right,
              onTap: () {
                // Detail navigation can be added later.
              },
            );
          },
        );
      },
    );
  }
}
