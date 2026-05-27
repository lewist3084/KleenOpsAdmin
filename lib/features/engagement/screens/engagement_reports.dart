// lib/content/engagement/engagement_reports.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kleenops_admin/app/routes.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/details_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/home_navbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/drawers/appbar_logout_adapter.dart';
import 'package:kleenops_admin/features/engagement/tabs/engagement_reports_tabs.dart'
    show EngagementReportsTabs, engagementReportsTabsSearchVisibleProvider;
import 'package:kleenops_admin/services/ai/ai_context_service.dart';
import 'package:kleenops_admin/widgets/ai/ai_screen_context.dart';
import 'package:shared_widgets/containers/canvas_top_bookend.dart';
import 'package:shared_widgets/containers/standard_canvas.dart';
import 'package:shared_widgets/drawers/menu_drawer.dart';

/// Top-level screen with its own Scaffold (app bar + content + bottom nav)
class EngagementReportsScreen extends StatelessWidget {
  const EngagementReportsScreen({super.key});

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
      required bool searchActive,
      required VoidCallback onSearchToggle,
    }) {
      if (hideChrome) return const SizedBox.shrink();
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DetailsAppBar(
            title: 'Engagement Reports',
            onAiPressed: onAiPressed,
            menuSections: menuSections,
            showSearchToggle: true,
            searchActive: searchActive,
            onSearchToggle: onSearchToggle,
          ),
          const HomeNavBarAdapter(),
        ],
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: null,
      drawer: const UserDrawer(),
      body: AiScreenContext(
        context: AiContextPresets.engagementReports(),
        child: _wrapCanvas(
          const EngagementReportsTabs(),
        ),
      ),
      bottomNavigationBar: Consumer(
        builder: (context, ref, _) {
          final controller = ref.read(aiCanvasControllerProvider);
          final menuSections = MenuDrawerSections(
            actions: [
              ContentMenuItem(
                icon: Icons.home_outlined,
                label: 'Engagement Home',
                onTap: () => context.push(AppRoutePaths.engagementHome),
              ),
              ContentMenuItem(
                icon: Icons.assignment_outlined,
                label: 'Surveys',
                onTap: () => context.push(AppRoutePaths.engagementSurvey),
              ),
              ContentMenuItem(
                icon: Icons.bar_chart_outlined,
                label: 'Stats',
                onTap: () => context.push(AppRoutePaths.engagementStats),
              ),
            ],
          );
          final searchActive =
              ref.watch(engagementReportsTabsSearchVisibleProvider);
          return buildBottomBar(
            onAiPressed: controller.toggle,
            menuSections: menuSections,
            searchActive: searchActive,
            onSearchToggle: () {
              final notifier =
                  ref.read(engagementReportsTabsSearchVisibleProvider.notifier);
              notifier.state = !notifier.state;
            },
          );
        },
      ),
    );
  }
}
