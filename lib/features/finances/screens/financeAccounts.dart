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
import 'package:kleenops_admin/features/finances/details/financeAccountDetails.dart';
import 'package:kleenops_admin/features/finances/forms/financeAccountForm.dart';
import 'package:kleenops_admin/theme/palette.dart';
import 'package:shared_widgets/containers/canvas_top_bookend.dart';
import 'package:shared_widgets/containers/standard_canvas.dart';
import 'package:shared_widgets/drawers/menu_drawer.dart';
import 'package:shared_widgets/tiles/standard_tile_small.dart';

/// Chart of Accounts screen with full account listing grouped by type
class FinanceAccountsScreen extends StatelessWidget {
  const FinanceAccountsScreen({super.key});

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
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: null,
      drawer: const UserDrawer(),
      body: _wrapCanvas(const FinanceAccountsContent()),
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
                icon: Icons.receipt_long_outlined,
                label: 'Invoices',
                onTap: () => context.push(AppRoutePaths.financeInvoices),
              ),
              ContentMenuItem(
                icon: Icons.bar_chart_outlined,
                label: 'Stats',
                onTap: () => context.push(AppRoutePaths.financeStats),
              ),
            ],
          );
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DetailsAppBar(
                title: 'Accounts',
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

class FinanceAccountsContent extends ConsumerStatefulWidget {
  const FinanceAccountsContent({super.key});

  @override
  ConsumerState<FinanceAccountsContent> createState() =>
      _FinanceAccountsContentState();
}

class _FinanceAccountsContentState
    extends ConsumerState<FinanceAccountsContent> {
  String _searchQuery = '';

  static const _typeOrder = [
    'Asset',
    'Liability',
    'Equity',
    'Revenue',
    'Expense',
  ];

  @override
  Widget build(BuildContext context) {
    final palette = AppPaletteScope.of(context);
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
                        hintText: 'Search accounts',
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
                    heroTag: 'addAccount',
                    backgroundColor: palette.primary1.withAlpha(220),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => FinanceAccountForm(
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
                    .collection('account')
                    .orderBy('name')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(child: Text('No accounts yet'));
                  }

                  var docs = snapshot.data!.docs;
                  if (_searchQuery.isNotEmpty) {
                    docs = docs.where((d) {
                      final data = d.data();
                      final name =
                          (data['name'] ?? '').toString().toLowerCase();
                      final type =
                          (data['type'] ?? '').toString().toLowerCase();
                      return name.contains(_searchQuery) ||
                          type.contains(_searchQuery);
                    }).toList();
                  }

                  // Group by type
                  final grouped = <String,
                      List<QueryDocumentSnapshot<Map<String, dynamic>>>>{};
                  for (final doc in docs) {
                    final type =
                        (doc.data()['type'] ?? 'Other').toString();
                    grouped.putIfAbsent(type, () => []).add(doc);
                  }

                  return ListView(
                    padding: const EdgeInsets.only(bottom: 100),
                    children: [
                      for (final type in _typeOrder)
                        if (grouped.containsKey(type)) ...[
                          _buildSectionHeader(type, grouped[type]!.length),
                          ...grouped[type]!.map(
                            (doc) => _buildAccountTile(
                                context, doc, companyRef),
                          ),
                        ],
                      for (final entry in grouped.entries)
                        if (!_typeOrder.contains(entry.key)) ...[
                          _buildSectionHeader(
                              entry.key, entry.value.length),
                          ...entry.value.map(
                            (doc) => _buildAccountTile(
                                context, doc, companyRef),
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

  IconData _typeIcon(String type) {
    switch (type) {
      case 'Asset':
        return Icons.account_balance_wallet_outlined;
      case 'Liability':
        return Icons.credit_card_outlined;
      case 'Equity':
        return Icons.pie_chart_outline;
      case 'Revenue':
        return Icons.trending_up;
      case 'Expense':
        return Icons.trending_down;
      default:
        return Icons.account_balance_outlined;
    }
  }

  Widget _buildAccountTile(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    DocumentReference<Map<String, dynamic>> companyRef,
  ) {
    final data = doc.data();
    final name = (data['name'] ?? 'Unnamed').toString();
    final type = (data['type'] ?? '').toString();
    final balance = (data['balance'] as num?)?.toDouble() ?? 0.0;

    return StandardTileSmallDart(
      label: name,
      secondaryText: '\$${balance.toStringAsFixed(2)}',
      leadingIcon: _typeIcon(type),
      trailingIcon1: Icons.chevron_right,
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => FinanceAccountDetailsScreen(
              companyRef: companyRef,
              docId: doc.id,
            ),
          ),
        );
      },
    );
  }
}
