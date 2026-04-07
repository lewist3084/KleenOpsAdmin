import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kleenops_admin/app/routes.dart';
import 'package:kleenops_admin/app/shared_widgets/drawers/appbar_logout_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/details_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/home_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/home_navbar_adapter.dart';
import 'package:kleenops_admin/features/auth/providers/auth_provider.dart';
import 'package:kleenops_admin/features/finances/details/finance_customer_details.dart';
import 'package:kleenops_admin/features/finances/dialogs/add_customer_dialog.dart';
import 'package:kleenops_admin/features/finances/forms/finance_customer_form.dart';
import 'package:shared_widgets/containers/canvas_top_bookend.dart';
import 'package:shared_widgets/containers/standard_canvas.dart';
import 'package:shared_widgets/drawers/menu_drawer.dart';
import 'package:shared_widgets/tiles/standard_tile_small.dart';

class FinanceCustomersScreen extends StatelessWidget {
  const FinanceCustomersScreen({super.key});

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
      body: _wrapCanvas(const _FinanceCustomersContent()),
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
                title: 'Customers',
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

class _FinanceCustomersContent extends ConsumerStatefulWidget {
  const _FinanceCustomersContent();

  @override
  ConsumerState<_FinanceCustomersContent> createState() =>
      _FinanceCustomersContentState();
}

class _FinanceCustomersContentState
    extends ConsumerState<_FinanceCustomersContent> {
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
                        hintText: 'Search customers',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      onChanged: (v) {
                        setState(() => _searchQuery = v.trim().toLowerCase());
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  FloatingActionButton.small(
                    heroTag: 'addCustomerFab',
                    onPressed: () async {
                      await showAddCustomerDialog(
                        context: context,
                        companyRef: companyRef,
                      );
                    },
                    child: const Icon(Icons.add),
                  ),
                ],
              ),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance.collection('customer').orderBy('name').snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(child: Text('No customers yet'));
                  }

                  var docs = snapshot.data!.docs;
                  if (_searchQuery.isNotEmpty) {
                    docs = docs.where((doc) {
                      final data = doc.data();
                      final name = (data['name'] ?? '').toString().toLowerCase();
                      final email = (data['email'] ?? '').toString().toLowerCase();
                      final phone = (data['phone'] ?? '').toString().toLowerCase();
                      return name.contains(_searchQuery) ||
                          email.contains(_searchQuery) ||
                          phone.contains(_searchQuery);
                    }).toList();
                  }

                  final active = docs.where((d) => d.data()['active'] != false).toList();
                  final inactive = docs.where((d) => d.data()['active'] == false).toList();

                  return ListView(
                    padding: const EdgeInsets.only(bottom: 110),
                    children: [
                      if (active.isNotEmpty) ...[
                        _sectionHeader('Active', active.length),
                        ...active.map((doc) => _customerTile(companyRef, doc)),
                      ],
                      if (inactive.isNotEmpty) ...[
                        _sectionHeader('Inactive', inactive.length),
                        ...inactive.map((doc) => _customerTile(companyRef, doc)),
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

  Widget _sectionHeader(String label, int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: Text(
        '$label ($count)',
        style: TextStyle(
          color: Colors.grey[600],
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
      ),
    );
  }

  Widget _customerTile(
    DocumentReference<Map<String, dynamic>> companyRef,
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    final name = (data['name'] ?? 'Unnamed') as String;
    final email = (data['email'] ?? '') as String;
    final phone = (data['phone'] ?? '') as String;
    final subtitle = email.isNotEmpty ? email : (phone.isNotEmpty ? phone : 'No contact info');

    return StandardTileSmallDart(
      leadingIcon: Icons.person_outline,
      label: name,
      secondaryText: subtitle,
      trailingIcon1: Icons.chevron_right,
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => FinanceCustomerDetailsScreen(
              companyRef: companyRef,
              docId: doc.id,
            ),
          ),
        );
      },
      trailingIcon2: Icons.edit_outlined,
      onTrailing2Tap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => FinanceCustomerForm(
              companyRef: companyRef,
              docId: doc.id,
            ),
          ),
        );
      },
    );
  }
}
