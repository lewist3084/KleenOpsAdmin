// lib/features/marketplace/screens/marketplace_home.dart
//
// Marketplace catalog screen — mirrors the regular CleanOps
// `marketplace_marketplace.dart` layout: a single "Catalog" tab whose body is
// the shared CatalogContent (reads the global `object` collection), wrapped
// in the standard admin chrome (DetailsAppBar + HomeNavBarAdapter).
//
// The bottom HomeNavBar is configured under the `marketplace` section in
// `home_navbar_adapter.dart` and surfaces Home / Catalog / Scraping / Resell.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_widgets/containers/canvas_top_bookend.dart';
import 'package:shared_widgets/containers/standard_canvas.dart';
import 'package:shared_widgets/drawers/menu_drawer.dart';
import 'package:shared_widgets/tabs/standard_tab.dart';

import '../../../app/shared_widgets/drawers/user_drawer.dart';
import '../../../app/shared_widgets/navigation/details_appbar_adapter.dart';
import '../../../app/shared_widgets/navigation/home_navbar_adapter.dart';
import '../../../common/communications/comm_menu.dart';
import '../../catalog/screens/catalog.dart';

class MarketplaceHome extends ConsumerWidget {
  const MarketplaceHome({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final menuSections = MenuDrawerSections(
      actions: const [],
      communications: buildAdminCommunicationMenuItems(context),
    );

    return Scaffold(
      appBar: null,
      drawer: const UserDrawer(),
      body: StandardCanvas(
        child: SafeArea(
          top: true,
          bottom: false,
          child: Stack(
            children: [
              const Positioned.fill(child: _MarketplaceCatalogTabs()),
              const Positioned(
                left: 0,
                right: 0,
                top: 0,
                child: CanvasTopBookend(),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DetailsAppBar(
            title: 'Marketplace',
            menuSections: menuSections,
          ),
          const HomeNavBarAdapter(),
        ],
      ),
    );
  }
}

class _MarketplaceCatalogTabs extends StatefulWidget {
  const _MarketplaceCatalogTabs();

  @override
  State<_MarketplaceCatalogTabs> createState() =>
      _MarketplaceCatalogTabsState();
}

class _MarketplaceCatalogTabsState extends State<_MarketplaceCatalogTabs>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 1, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          decoration: const BoxDecoration(color: Colors.white),
          child: StandardTabBar(
            controller: _tabController,
            isScrollable: true,
            dividerColor: Colors.grey[300],
            indicatorColor: Theme.of(context).primaryColor,
            indicatorWeight: 3.0,
            labelColor: Colors.black,
            unselectedLabelColor: Colors.grey[600],
            tabs: const [
              Tab(text: 'Catalog'),
            ],
          ),
        ),
        // No extra bottom padding — the Scaffold's bottomNavigationBar
        // (DetailsAppBar + HomeNavBarAdapter) already reserves its own
        // space, so doubling up here leaves a visible white gap beneath
        // the list.
        const Expanded(child: CatalogContent()),
      ],
    );
  }
}
