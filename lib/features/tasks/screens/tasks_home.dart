// lib/features/tasks/screens/tasks_home.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kleenops_admin/app/routes.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/menu_button_block_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/details_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/home_navbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/drawers/appbar_logout_adapter.dart';
import 'package:shared_widgets/containers/canvas_top_bookend.dart';
import 'package:shared_widgets/containers/standard_canvas.dart';
import 'package:shared_widgets/drawers/menu_drawer.dart';

/// Top-level tasks hub mirroring admin's HrHomeScreen pattern.
///
/// Communication-heavy task surfaces (the full `tasks_tasks` /
/// `tasks_team` screens from kleenops) are not ported yet — they need
/// the texting/voice/video stack admin doesn't have. The hub exposes
/// the ported standalone surfaces (Messages, Quality, Dependability,
/// Performance, Timecard, Employee Tasks).
class TasksHome extends StatelessWidget {
  const TasksHome({super.key});

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
    Widget buildBottomBar({
      VoidCallback? onAiPressed,
      MenuDrawerSections? menuSections,
    }) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DetailsAppBar(
            title: 'Tasks',
            onAiPressed: onAiPressed,
            menuSections: menuSections,
          ),
          const HomeNavBarAdapter(),
        ],
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: null,
      drawer: const UserDrawer(),
      body: _wrapCanvas(const TasksHomeContent()),
      bottomNavigationBar: Consumer(
        builder: (context, ref, _) {
          final menuSections = MenuDrawerSections(
            actions: [
              ContentMenuItem(
                icon: Icons.message_outlined,
                label: 'Messages',
                onTap: () => context.push(AppRoutePaths.tasksMessage),
              ),
              ContentMenuItem(
                icon: Icons.fact_check_outlined,
                label: 'Quality',
                onTap: () => context.push(AppRoutePaths.tasksQuality),
              ),
              ContentMenuItem(
                icon: Icons.event_available_outlined,
                label: 'Dependability',
                onTap: () => context.push(AppRoutePaths.tasksDependability),
              ),
              ContentMenuItem(
                icon: Icons.trending_up_outlined,
                label: 'Performance',
                onTap: () => context.push(AppRoutePaths.tasksPerformance),
              ),
              ContentMenuItem(
                icon: Icons.timer_outlined,
                label: 'Timecard',
                onTap: () => context.push(AppRoutePaths.tasksTimecardTabs),
              ),
              ContentMenuItem(
                icon: Icons.assignment_ind_outlined,
                label: 'Employee Tasks',
                onTap: () => context.push(AppRoutePaths.tasksEmployeeTasks),
              ),
            ],
          );
          return buildBottomBar(menuSections: menuSections);
        },
      ),
    );
  }
}

class TasksHomeContent extends StatelessWidget {
  const TasksHomeContent({super.key});

  @override
  Widget build(BuildContext context) {
    final bottomInset =
        kBottomNavigationBarHeight + 16.0 + MediaQuery.of(context).padding.bottom;

    return SingleChildScrollView(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MenuButtonBlock(),
        ],
      ),
    );
  }
}
