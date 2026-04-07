import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';

import 'package:kleenops_admin/app/routes.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/details_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/home_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/home_navbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/drawers/appbar_logout_adapter.dart';
import 'package:kleenops_admin/features/sales/details/sales_customer_details.dart';
import 'package:kleenops_admin/features/sales/providers/sales_provider.dart';
import 'package:kleenops_admin/features/sales/widgets/customer_requests_tab.dart';
import 'package:shared_widgets/containers/canvas_top_bookend.dart';
import 'package:shared_widgets/containers/standard_canvas.dart';
import 'package:shared_widgets/drawers/menu_drawer.dart';
import 'package:shared_widgets/tabs/standard_tab.dart';

class SalesCustomerTabsScreen extends StatelessWidget {
  final DocumentReference<Map<String, dynamic>> customerRef;
  const SalesCustomerTabsScreen({super.key, required this.customerRef});

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

    return Scaffold(
      appBar: null,
      drawer: const UserDrawer(),
      body: _wrapCanvas(
        SalesCustomerTabs(customerRef: customerRef),
      ),
      bottomNavigationBar: hideChrome
          ? null
          : Consumer(
              builder: (context, ref, _) {
                final menuSections = MenuDrawerSections(
                  actions: [
                    ContentMenuItem(
                      icon: Icons.sell_outlined,
                      label: 'Sales',
                      onTap: () => context.push(AppRoutePaths.salesSales),
                    ),
                    ContentMenuItem(
                      icon: Icons.campaign_outlined,
                      label: 'Marketing',
                      onTap: () => context.push(AppRoutePaths.salesMarketing),
                    ),
                    ContentMenuItem(
                      icon: Icons.bar_chart_outlined,
                      label: 'Stats',
                      onTap: () => context.push(AppRoutePaths.salesStats),
                    ),
                  ],
                );
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DetailsAppBar(
                      title: 'Customer',
                      menuSections: menuSections,
                    ),
                    const HomeNavBarAdapter(highlightSelected: false),
                  ],
                );
              },
            ),
    );
  }
}

class SalesCustomerTabs extends ConsumerStatefulWidget {
  final DocumentReference<Map<String, dynamic>> customerRef;
  const SalesCustomerTabs({super.key, required this.customerRef});

  @override
  ConsumerState<SalesCustomerTabs> createState() => _SalesCustomerTabsState();
}

class _SalesCustomerTabsState extends ConsumerState<SalesCustomerTabs>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging ||
          _tabController.index == _tabController.animation?.value) {
        ref.read(customerTabIndexProvider.notifier).state = _tabController.index;
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool hideChrome = false;
    final bottomInset =
        (hideChrome ? 16.0 : kBottomNavigationBarHeight + 16.0) +
            MediaQuery.of(context).padding.bottom;

    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          Container(
            color: Colors.white,
            child: StandardTabBar(
              controller: _tabController,
              isScrollable: true,
              dividerColor: Colors.grey[300],
              indicatorColor: Theme.of(context).primaryColor,
              indicatorWeight: 3,
              labelColor: Colors.black,
              unselectedLabelColor: Colors.grey[600],
              tabs: const [
                Tab(text: 'Details'),
                Tab(text: 'Requests'),
                Tab(text: 'Charts'),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: bottomInset),
              child: TabBarView(
                physics: const NeverScrollableScrollPhysics(),
                controller: _tabController,
                children: [
                  SalesCustomerDetails(customerRef: widget.customerRef),
                  CustomerRequestsTab(customerRef: widget.customerRef),
                  const Center(child: Text('Charts Content')),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
