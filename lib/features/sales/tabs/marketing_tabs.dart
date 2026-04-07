import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:kleenops_admin/features/sales/providers/marketing_provider.dart';
import 'package:kleenops_admin/features/sales/screens/marketing_campaign.dart';
import 'package:kleenops_admin/features/sales/screens/marketing_ads.dart';
import 'package:kleenops_admin/features/sales/screens/marketing_schedule.dart';
import 'package:kleenops_admin/features/sales/screens/marketing_target_group.dart';
import 'package:kleenops_admin/features/sales/screens/marketing_data.dart';
import 'package:kleenops_admin/app/routes.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/details_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/home_navbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/home_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/drawers/appbar_logout_adapter.dart';
import 'package:shared_widgets/containers/canvas_top_bookend.dart';
import 'package:shared_widgets/containers/standard_canvas.dart';
import 'package:shared_widgets/drawers/menu_drawer.dart';
import 'package:shared_widgets/tabs/standard_tab.dart';

/// Top-level screen with its own Scaffold (app bar + content + bottom nav)
class SalesMarketingTabsScreen extends StatelessWidget {
  const SalesMarketingTabsScreen({super.key});

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
            title: 'Sales Marketing',
            onAiPressed: onAiPressed,
            menuSections: menuSections,
          ),
          const HomeNavBarAdapter(),
        ],
      );
    }

    return Scaffold(
      appBar: null,
      drawer: const UserDrawer(),
      body: _wrapCanvas(
          const SalesMarketingTabs(),
        ),
      bottomNavigationBar: Consumer(
        builder: (context, ref, _) {
          final menuSections = MenuDrawerSections(
            actions: [
              ContentMenuItem(
                icon: Icons.home_outlined,
                label: 'Sales Home',
                onTap: () => context.push(AppRoutePaths.salesHome),
              ),
              ContentMenuItem(
                icon: Icons.sell_outlined,
                label: 'Sales',
                onTap: () => context.push(AppRoutePaths.salesSales),
              ),
              ContentMenuItem(
                icon: Icons.bar_chart_outlined,
                label: 'Stats',
                onTap: () => context.push(AppRoutePaths.salesStats),
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

class SalesMarketingTabs extends ConsumerStatefulWidget {
  const SalesMarketingTabs({super.key});

  @override
  ConsumerState<SalesMarketingTabs> createState() => _SalesMarketingTabsState();
}

class _SalesMarketingTabsState extends ConsumerState<SalesMarketingTabs>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging ||
          _tabController.index == _tabController.animation?.value) {
        ref.read(marketingTabIndexProvider.notifier).state = _tabController.index;
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
      length: 5,
      child: Column(
        children: [
          Container(
            color: Colors.white,
            child: StandardTabBar(
              controller: _tabController,
              isScrollable: true,
              dividerColor: Colors.grey[300],
              indicatorColor: Theme.of(context).primaryColor,
              indicatorWeight: 3.0,
              labelColor: Colors.black,
              unselectedLabelColor: Colors.grey[600],
              tabs: const [
                Tab(text: 'Campaign'),
                Tab(text: 'Ads'),
                Tab(text: 'Target'),
                Tab(text: 'Delivery'),
                Tab(text: 'Data'),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: bottomInset),
              child: TabBarView(
                physics: const NeverScrollableScrollPhysics(),
                controller: _tabController,
                children: const [
                  MarketingCampaignContent(),
                  MarketingAdsContent(),
                  MarketingTargetGroupContent(),
                  MarketingScheduleContent(),
                  MarketingDataContent(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
