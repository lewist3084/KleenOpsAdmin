// lib/features/safety/tabs/analysis_tabs.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kleenops_admin/app/routes.dart';
import 'package:kleenops_admin/features/safety/providers/safety_provider.dart';
import 'package:kleenops_admin/features/safety/screens/safety_analysis.dart';
import 'package:kleenops_admin/features/safety/screens/safety_contacts.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/details_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/home_navbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/drawers/appbar_logout_adapter.dart';
import 'package:kleenops_admin/services/ai/ai_context_service.dart';
import 'package:kleenops_admin/widgets/ai/ai_screen_context.dart';
import 'package:shared_widgets/containers/canvas_top_bookend.dart';
import 'package:shared_widgets/containers/standard_canvas.dart';
import 'package:shared_widgets/drawers/menu_drawer.dart';
import 'package:shared_widgets/tabs/lazy_tab_view.dart';
import 'package:shared_widgets/tabs/standard_tab.dart';

/// Top-level screen with its own Scaffold (app bar + content + bottom nav)
class AnalysisTabsScreen extends StatelessWidget {
  const AnalysisTabsScreen({super.key});

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
            title: 'Safety Analysis',
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
      body: AiScreenContext(
        context: AiContextPresets.safetyAnalysis(),
        child: _wrapCanvas(
          const AnalysisTabs(),
        ),
      ),
      bottomNavigationBar: Consumer(
        builder: (context, ref, _) {
          final controller = ref.read(aiCanvasControllerProvider);
          final menuSections = MenuDrawerSections(
            actions: [
              ContentMenuItem(
                icon: Icons.health_and_safety_outlined,
                label: 'Response',
                onTap: () => context.push(AppRoutePaths.safetyResponse),
              ),
              ContentMenuItem(
                icon: Icons.bar_chart_outlined,
                label: 'Stats',
                onTap: () => context.push(AppRoutePaths.safetyStats),
              ),
            ],
          );
          return buildBottomBar(
            onAiPressed: controller.toggle,
            menuSections: menuSections,
          );
        },
      ),
    );
  }
}

class AnalysisTabs extends ConsumerStatefulWidget {
  final String? teamId;
  const AnalysisTabs({super.key, this.teamId});

  @override
  _AnalysisTabsState createState() => _AnalysisTabsState();
}

class _AnalysisTabsState extends ConsumerState<AnalysisTabs>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging ||
          _tabController.index == _tabController.animation?.value) {
        ref.read(safetyTabIndexProvider.notifier).state = _tabController.index;
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

    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Container(
            color: Colors.white,
            child: StandardTabBar(
              controller: _tabController,
              isScrollable: true,
              dividerColor: Colors.grey[300],
              indicatorWeight: 3.0,
              labelColor: Colors.black,
              unselectedLabelColor: Colors.grey[600],
              tabs: const [
                Tab(text: 'Analysis'),
                Tab(text: 'Contacts'),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: bottomInset),
              child: LazyTabView(
                physics: const NeverScrollableScrollPhysics(),
                controller: _tabController,
                children: const [
                  SafetyAnalysisContent(),
                  SafetyContactsContent(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
