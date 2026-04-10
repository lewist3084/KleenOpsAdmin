// lib/features/marketplace/screens/marketplace_resell.dart
//
// Resell screen — mirrors the regular CleanOps `marketplace_resell.dart`
// layout (single Resell tab + content + standard chrome). The admin app does
// not yet surface per-company resale objects; the body is a placeholder.

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

class MarketplaceResellScreen extends ConsumerStatefulWidget {
  const MarketplaceResellScreen({super.key});

  @override
  ConsumerState<MarketplaceResellScreen> createState() =>
      _MarketplaceResellScreenState();
}

class _MarketplaceResellScreenState
    extends ConsumerState<MarketplaceResellScreen>
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
    return Scaffold(
      appBar: null,
      drawer: const UserDrawer(),
      body: StandardCanvas(
        child: SafeArea(
          top: true,
          bottom: false,
          child: Stack(
            children: [
              Positioned.fill(
                child: Column(
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
                          Tab(text: 'Resell'),
                        ],
                      ),
                    ),
                    const Expanded(
                      child: Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'Resell listings will appear here.',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
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
      bottomNavigationBar: Consumer(
        builder: (context, ref, _) {
          final menuSections = MenuDrawerSections(
            actions: const [],
            communications: buildAdminCommunicationMenuItems(context),
          );
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DetailsAppBar(title: 'Resell', menuSections: menuSections),
              const HomeNavBarAdapter(),
            ],
          );
        },
      ),
    );
  }
}
