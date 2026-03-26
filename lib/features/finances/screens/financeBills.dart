// lib/features/finances/screens/financeBills.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:kleenops_admin/app/routes.dart';
import 'package:kleenops_admin/features/auth/providers/auth_provider.dart';
import 'package:kleenops_admin/features/finances/forms/financeBillForm.dart';
import 'package:kleenops_admin/features/finances/details/financeBillDetails.dart';
import 'package:kleenops_admin/features/finances/screens/financePayments.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/details_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/home_navbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/home_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/drawers/appbar_logout_adapter.dart';
import 'package:shared_widgets/containers/canvas_top_bookend.dart';
import 'package:shared_widgets/containers/standard_canvas.dart';
import 'package:shared_widgets/drawers/menu_drawer.dart';
import 'package:shared_widgets/tiles/standard_tile_small.dart';

class FinanceBillsScreen extends StatelessWidget {
  const FinanceBillsScreen({super.key});

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
            title: 'Bills',
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
          const FinanceBillsContent(),
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
                icon: Icons.payment_outlined,
                label: 'Payments',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const FinancePaymentsScreen(),
                  ),
                ),
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

class FinanceBillsContent extends ConsumerStatefulWidget {
  const FinanceBillsContent({super.key});

  @override
  ConsumerState<FinanceBillsContent> createState() =>
      _FinanceBillsContentState();
}

class _FinanceBillsContentState extends ConsumerState<FinanceBillsContent> {
  String _searchQuery = '';
  final _currencyFormat = NumberFormat.currency(symbol: '\$');

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

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Search bills',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      onChanged: (v) =>
                          setState(() => _searchQuery = v.toLowerCase()),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FloatingActionButton.small(
                    heroTag: 'addBill',
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              FinanceBillForm(companyRef: companyRef),
                        ),
                      );
                    },
                    child: const Icon(Icons.add),
                  ),
                ],
              ),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('bill')
                    .orderBy('createdAt', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(
                      child: Text(
                        'No bills yet',
                        style: TextStyle(fontSize: 16),
                      ),
                    );
                  }

                  var docs = snapshot.data!.docs;
                  if (_searchQuery.isNotEmpty) {
                    docs = docs.where((d) {
                      final data = d.data();
                      final billNumber = (data['billNumber'] ?? '')
                          .toString()
                          .toLowerCase();
                      final vendorName =
                          (data['vendorName'] ?? '').toString().toLowerCase();
                      return billNumber.contains(_searchQuery) ||
                          vendorName.contains(_searchQuery);
                    }).toList();
                  }

                  final unpaid = docs
                      .where((d) => d.data()['status'] == 'unpaid')
                      .toList();
                  final partial = docs
                      .where((d) => d.data()['status'] == 'partial')
                      .toList();
                  final paid = docs
                      .where((d) => d.data()['status'] == 'paid')
                      .toList();

                  return ListView(
                    padding: const EdgeInsets.only(bottom: 100),
                    children: [
                      if (unpaid.isNotEmpty) ...[
                        _buildSectionHeader('Unpaid', unpaid.length),
                        ...unpaid.map(
                            (doc) => _buildBillTile(context, doc, companyRef)),
                      ],
                      if (partial.isNotEmpty) ...[
                        _buildSectionHeader('Partially Paid', partial.length),
                        ...partial.map(
                            (doc) => _buildBillTile(context, doc, companyRef)),
                      ],
                      if (paid.isNotEmpty) ...[
                        _buildSectionHeader('Paid', paid.length),
                        ...paid.map(
                            (doc) => _buildBillTile(context, doc, companyRef)),
                      ],
                    ],
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSectionHeader(String title, int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(
        '$title ($count)',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Colors.grey[600],
        ),
      ),
    );
  }

  Widget _buildBillTile(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    DocumentReference<Map<String, dynamic>> companyRef,
  ) {
    final data = doc.data();
    final billNumber = (data['billNumber'] ?? 'No Number') as String;
    final vendorName = (data['vendorName'] ?? 'Unknown Vendor') as String;
    final total = (data['total'] as num?)?.toDouble() ?? 0.0;
    final status = (data['status'] ?? 'unpaid') as String;

    final statusColor = status == 'paid'
        ? Colors.green
        : status == 'partial'
            ? Colors.orange
            : Colors.red;

    return Dismissible(
      key: ValueKey(doc.id),
      direction: status == 'unpaid'
          ? DismissDirection.startToEnd
          : DismissDirection.none,
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (direction) async {
        return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Delete Bill'),
            content:
                Text('Are you sure you want to delete bill #$billNumber?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child:
                    const Text('Delete', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        );
      },
      onDismissed: (_) async {
        final ref = doc.reference;
        final oldData = data;
        await ref.delete();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Bill deleted.'),
            duration: const Duration(seconds: 8),
            action: SnackBarAction(
              label: 'UNDO',
              onPressed: () => ref.set(oldData),
            ),
          ),
        );
      },
      child: StandardTileSmallDart(
        label: '#$billNumber',
        secondaryText: '$vendorName  |  ${_currencyFormat.format(total)}',
        leadingIcon: Icons.receipt_long_outlined,
        leadingIconColor: statusColor,
        trailingIcon1: Icons.chevron_right,
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => FinanceBillDetailsScreen(
                companyRef: companyRef,
                docId: doc.id,
              ),
            ),
          );
        },
      ),
    );
  }
}
