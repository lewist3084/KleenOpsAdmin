// lib/features/tasks/tabs/tasks_timecard_tabs.dart

import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kleenops_admin/features/tasks/providers/team_provider.dart';
import 'package:kleenops_admin/features/tasks/screens/tasks_timecard.dart';
import 'package:kleenops_admin/features/tasks/screens/tasks_dependability.dart';
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

String _debugLocation(BuildContext context) {
  final router = GoRouter.maybeOf(context);
  if (router == null) return 'no-router';
  final info = router.routeInformationProvider.value;
  final uri = info.uri;
  if (uri.toString().isNotEmpty) return uri.toString();
  return 'unknown';
}

/// Top-level screen with its own Scaffold (app bar + content + bottom nav).
/// Admin port: Timeclock tab removed (depends on geo_stamp / lunch_policy /
/// user_repository).
class TasksTimecardTabsScreen extends StatelessWidget {
  const TasksTimecardTabsScreen({super.key});

  void _debugLog(String message) {
    if (!kDebugMode) return;
    debugPrint('[TasksTimecardTabsScreen] $message');
  }

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
    _debugLog('build location=${_debugLocation(context)}');
    const bool hideChrome = false;

    Widget buildBottomBar({
      VoidCallback? onAiPressed,
      MenuDrawerSections? menuSections,
    }) {
      if (hideChrome) return const SizedBox.shrink();
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DetailsAppBar(
            title: 'Timecard',
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
        context: AiContextPresets.detailScreen(
          key: 'tasksTimecard',
          sectionKey: 'tasks',
        ),
        child: _wrapCanvas(
          const TasksTimecardTabs(),
        ),
      ),
      bottomNavigationBar: hideChrome
          ? null
          : Consumer(
              builder: (context, ref, _) {
                final controller = ref.read(aiCanvasControllerProvider);
                final menuSections = const MenuDrawerSections();
                return buildBottomBar(
                  onAiPressed: controller.toggle,
                  menuSections: menuSections,
                );
              },
            ),
    );
  }
}

class TasksTimecardTabs extends ConsumerStatefulWidget {
  final String? teamId;
  const TasksTimecardTabs({super.key, this.teamId});

  @override
  ConsumerState<TasksTimecardTabs> createState() => _TasksTimecardTabsState();
}

class _TasksTimecardTabsState extends ConsumerState<TasksTimecardTabs>
    with SingleTickerProviderStateMixin {
  late final TabController _ctrl;

  void _debugLog(String message) {
    if (!kDebugMode) return;
    debugPrint('[TasksTimecardTabs] $message');
  }

  @override
  void initState() {
    super.initState();
    // Admin port: 2 tabs (Timecard + Dependability) — Timeclock removed.
    _ctrl = TabController(length: 2, vsync: this);

    _ctrl.addListener(() {
      if (_ctrl.indexIsChanging || _ctrl.index == _ctrl.animation?.value) {
        ref.read(teamTabIndexProvider.notifier).state = _ctrl.index;
      }
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _debugLog(
      'build tabIndex=${_ctrl.index} location=${_debugLocation(context)}',
    );
    const bool hideChrome = false;
    final media = MediaQuery.of(context);
    final bottomInset = hideChrome ? 16.0 + media.padding.bottom : 16.0;

    return Column(
      children: [
        Container(
          color: Colors.white,
          child: StandardTabBar(
            controller: _ctrl,
            isScrollable: true,
            dividerColor: Colors.grey[300],
            indicatorWeight: 3,
            labelColor: Colors.black,
            unselectedLabelColor: Colors.grey[600],
            tabs: const [
              Tab(text: 'Timecard'),
              Tab(text: 'Dependability'),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: bottomInset),
            child: LazyTabView(
              physics: const NeverScrollableScrollPhysics(),
              controller: _ctrl,
              children: const [
                TasksTimecardContent(key: PageStorageKey('timecard-tab')),
                TasksDependabilityContent(
                  key: PageStorageKey('dependability-tab'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
