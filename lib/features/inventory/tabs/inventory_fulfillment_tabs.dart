// lib/features/inventory/tabs/inventory_fulfillment_tabs.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:kleenops_admin/app/routes.dart';
import 'package:kleenops_admin/app/shared_widgets/drawers/appbar_logout_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/details_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/home_navbar_adapter.dart';
import 'package:kleenops_admin/features/inventory/providers/inventory_provider.dart';
import 'package:kleenops_admin/features/inventory/screens/inventory_fulfillment.dart';
import 'package:kleenops_admin/features/inventory/screens/inventory_request.dart';
import 'package:kleenops_admin/features/inventory/screens/inventory_restock.dart';
import 'package:shared_widgets/containers/canvas_top_bookend.dart';
import 'package:shared_widgets/containers/standard_canvas.dart';
import 'package:shared_widgets/drawers/menu_drawer.dart';
import 'package:shared_widgets/tabs/lazy_tab_view.dart';
import 'package:shared_widgets/tabs/standard_tab.dart';

/// Top-level screen with its own Scaffold (app bar + content + bottom nav)
class InventoryFulfillmentTabsScreen extends StatelessWidget {
  const InventoryFulfillmentTabsScreen({super.key});

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
    Widget buildBottomBar({MenuDrawerSections? menuSections}) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DetailsAppBar(
            title: 'Inventory Fulfillment',
            menuSections: menuSections,
          ),
          const HomeNavBarAdapter(),
        ],
      );
    }

    return Scaffold(
      appBar: null,
      drawer: const UserDrawer(),
      body: _wrapCanvas(const InventoryFulfillmentTabs()),
      bottomNavigationBar: Consumer(
        builder: (context, ref, _) {
          final menuSections = MenuDrawerSections(
            actions: [
              ContentMenuItem(
                icon: Icons.home_outlined,
                label: 'Inventory Home',
                onTap: () => context.push(AppRoutePaths.inventoryHome),
              ),
              ContentMenuItem(
                icon: Icons.bar_chart_outlined,
                label: 'Stats',
                onTap: () => context.push(AppRoutePaths.inventoryStats),
              ),
              ContentMenuItem(
                icon: Icons.playlist_add,
                label: 'New Request',
                onTap: () => context.push(AppRoutePaths.inventoryRequestForm),
              ),
            ],
          );
          return buildBottomBar(menuSections: menuSections);
        },
      ),
    );
  }
}

class InventoryFulfillmentTabs extends ConsumerStatefulWidget {
  /// Pass in a teamId (from a query parameter) to filter the teams view.
  final String? teamId;
  const InventoryFulfillmentTabs({super.key, this.teamId});

  @override
  ConsumerState<InventoryFulfillmentTabs> createState() =>
      _InventoryFulfillmentTabsState();
}

class _InventoryFulfillmentTabsState
    extends ConsumerState<InventoryFulfillmentTabs>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final GlobalKey<InventoryFulfillmentContentState> _fulfillmentKey =
      GlobalKey<InventoryFulfillmentContentState>();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    _tabController.addListener(() {
      if (_tabController.indexIsChanging ||
          _tabController.index == _tabController.animation?.value) {
        ref.read(inventoryTabIndexProvider.notifier).state =
            _tabController.index;
        setState(() {}); // refresh FAB visibility when tab changes
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
    const bottomInset = 16.0;
    final fab = _buildFloatingActionButton(context);

    return DefaultTabController(
      length: 3,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Column(
            children: [
              Container(
                decoration: const BoxDecoration(color: Colors.white),
                child: StandardTabBar(
                  controller: _tabController,
                  isScrollable: true,
                  dividerColor: Colors.grey[300],
                  indicatorWeight: 3.0,
                  labelColor: Colors.black,
                  unselectedLabelColor: Colors.grey[600],
                  tabs: const [
                    Tab(text: 'Requests'),
                    Tab(text: 'Fulfillment'),
                    Tab(text: 'Restocking'),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: bottomInset),
                  child: LazyTabView(
                    physics: const NeverScrollableScrollPhysics(),
                    controller: _tabController,
                    children: [
                      const InventoryRequestContent(),
                      InventoryFulfillmentContent(key: _fulfillmentKey),
                      const InventoryRestockContent(),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (fab != null)
            Positioned(right: 16, bottom: 16, child: fab),
        ],
      ),
    );
  }

  Widget? _buildFloatingActionButton(BuildContext context) {
    switch (_tabController.index) {
      case 0:
        return FloatingActionButton(
          onPressed: () => context.go(AppRoutePaths.inventoryRequestForm),
          child: const Icon(Icons.add),
        );
      case 1:
        return FloatingActionButton(
          onPressed: () async {
            final fulfillmentRef =
                await _fulfillmentKey.currentState?.beginFulfillmentFlow(
              context,
            );
            if (fulfillmentRef == null) return;
            if (!mounted) return;
            // No inventoryFulfillmentDetails route in admin yet —
            // re-enter the same screen until details lands.
            context.go(AppRoutePaths.inventoryFulfillment);
          },
          child: const Icon(Icons.add),
        );
      default:
        return null;
    }
  }
}
