// lib/features/finances/screens/financeInvoices.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:kleenops_admin/app/routes.dart';
import 'package:kleenops_admin/features/auth/providers/auth_provider.dart';
import 'package:kleenops_admin/features/finances/screens/financeCustomers.dart';
import 'package:kleenops_admin/features/finances/details/financeInvoiceDetails.dart';
import 'package:kleenops_admin/features/finances/forms/financeInvoiceForm.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/details_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/home_navbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/home_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/drawers/appbar_logout_adapter.dart';
import 'package:shared_widgets/containers/canvas_top_bookend.dart';
import 'package:shared_widgets/containers/standard_canvas.dart';
import 'package:shared_widgets/drawers/menu_drawer.dart';
import 'package:shared_widgets/tiles/standard_tile_small.dart';

class FinanceInvoicesScreen extends StatelessWidget {
  const FinanceInvoicesScreen({super.key});

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
            title: 'Invoices',
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
          const FinanceInvoicesContent(),
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
                icon: Icons.people_outlined,
                label: 'Customers',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const FinanceCustomersScreen(),
                    ),
                  );
                },
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

class FinanceInvoicesContent extends ConsumerStatefulWidget {
  const FinanceInvoicesContent({super.key});

  @override
  ConsumerState<FinanceInvoicesContent> createState() =>
      _FinanceInvoicesContentState();
}

class _FinanceInvoicesContentState
    extends ConsumerState<FinanceInvoicesContent> {
  String _searchQuery = '';

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
                        hintText: 'Search',
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
                    heroTag: 'addInvoice',
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => FinanceInvoiceForm(
                            companyRef: companyRef,
                          ),
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
                    .collection('invoice')
                    .orderBy('createdAt', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(
                      child: Text(
                        'No invoices yet',
                        style: TextStyle(fontSize: 16),
                      ),
                    );
                  }

                  var docs = snapshot.data!.docs;
                  if (_searchQuery.isNotEmpty) {
                    docs = docs.where((d) {
                      final data = d.data();
                      final number = (data['invoiceNumber'] ?? '')
                          .toString()
                          .toLowerCase();
                      final customer = (data['customerName'] ?? '')
                          .toString()
                          .toLowerCase();
                      final status =
                          (data['status'] ?? '').toString().toLowerCase();
                      return number.contains(_searchQuery) ||
                          customer.contains(_searchQuery) ||
                          status.contains(_searchQuery);
                    }).toList();
                  }

                  // Group by status.
                  final statusOrder = [
                    'draft',
                    'sent',
                    'partial',
                    'overdue',
                    'paid',
                  ];

                  final grouped = <String, List<
                      QueryDocumentSnapshot<Map<String, dynamic>>>>{};
                  for (final doc in docs) {
                    final status =
                        (doc.data()['status'] ?? 'draft').toString();
                    grouped.putIfAbsent(status, () => []).add(doc);
                  }

                  return ListView(
                    padding: const EdgeInsets.only(bottom: 100),
                    children: [
                      for (final status in statusOrder)
                        if (grouped.containsKey(status)) ...[
                          _buildSectionHeader(
                            _statusLabel(status),
                            grouped[status]!.length,
                          ),
                          ...grouped[status]!.map(
                            (doc) => _buildInvoiceTile(
                              context,
                              doc,
                              companyRef,
                            ),
                          ),
                        ],
                      // Any statuses not in the predefined order.
                      for (final entry in grouped.entries)
                        if (!statusOrder.contains(entry.key)) ...[
                          _buildSectionHeader(
                            _statusLabel(entry.key),
                            entry.value.length,
                          ),
                          ...entry.value.map(
                            (doc) => _buildInvoiceTile(
                              context,
                              doc,
                              companyRef,
                            ),
                          ),
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

  String _statusLabel(String status) {
    switch (status) {
      case 'draft':
        return 'Draft';
      case 'sent':
        return 'Sent';
      case 'partial':
        return 'Partially Paid';
      case 'paid':
        return 'Paid';
      case 'overdue':
        return 'Overdue';
      default:
        return status;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'draft':
        return Colors.grey;
      case 'sent':
        return Colors.blue;
      case 'partial':
        return Colors.orange;
      case 'paid':
        return Colors.green;
      case 'overdue':
        return Colors.red;
      default:
        return Colors.grey;
    }
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

  Widget _buildInvoiceTile(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    DocumentReference<Map<String, dynamic>> companyRef,
  ) {
    final data = doc.data();
    final invoiceNumber = data['invoiceNumber'] ?? '';
    final customerName = (data['customerName'] ?? 'No Customer') as String;
    final total = (data['total'] as num?)?.toDouble() ?? 0.0;
    final status = (data['status'] ?? 'draft') as String;

    return Dismissible(
      key: ValueKey(doc.id),
      direction: status == 'draft'
          ? DismissDirection.startToEnd
          : DismissDirection.none,
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (direction) async {
        if (status != 'draft') return false;
        return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Delete Invoice'),
            content: Text(
              'Delete draft invoice #$invoiceNumber? This cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
        );
      },
      onDismissed: (_) => doc.reference.delete(),
      child: StandardTileSmallDart(
        label: '#$invoiceNumber  -  $customerName',
        secondaryText: '\$${total.toStringAsFixed(2)}',
        leadingIcon: Icons.receipt_long_outlined,
        leadingIconColor: _statusColor(status),
        trailingIcon1: Icons.chevron_right,
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => FinanceInvoiceDetailsScreen(
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
