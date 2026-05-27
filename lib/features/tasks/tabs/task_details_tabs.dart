// task_details_tabs.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kleenops_admin/features/tasks/providers/team_provider.dart';
import 'package:kleenops_admin/features/tasks/screens/task_completion.dart';
import 'package:kleenops_admin/features/tasks/screens/task_contributor_list.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/details_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/home_navbar_adapter.dart';
import 'package:kleenops_admin/services/ai/ai_context_service.dart';
import 'package:kleenops_admin/widgets/ai/ai_screen_context.dart';
import 'package:shared_widgets/containers/canvas_top_bookend.dart';
import 'package:shared_widgets/containers/standard_canvas.dart';
import 'package:shared_widgets/drawers/menu_drawer.dart';
import 'package:shared_widgets/tabs/lazy_tab_view.dart';
import 'package:shared_widgets/tabs/standard_tab.dart';

class TaskDetailsTabs extends ConsumerStatefulWidget {
  final String routineId;
  final String companyId;
  final String? teamId;

  const TaskDetailsTabs({
    super.key,
    required this.companyId,
    required this.routineId,
    this.teamId,
  });

  @override
  ConsumerState<TaskDetailsTabs> createState() => _TaskDetailsTabsState();
}

class _TaskDetailsTabsState extends ConsumerState<TaskDetailsTabs>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

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
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging ||
          _tabController.index == _tabController.animation?.value) {
        ref.read(teamTabIndexProvider.notifier).state = _tabController.index;
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
    const bool hideChrome = false;
    final docRef =
        FirebaseFirestore.instance.collection('timeline').doc(widget.routineId);
    final baseAiContext = AiContextPresets.detailScreen(
      key: 'tasksTaskDetails',
      sectionKey: 'tasks',
      entityId: widget.routineId,
      label: widget.routineId,
      entityPath: docRef.path,
    );

    Widget buildBottomBar({
      VoidCallback? onAiPressed,
      MenuDrawerSections? menuSections,
    }) {
      if (hideChrome) return const SizedBox.shrink();
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DetailsAppBar(
            title: 'Task Details',
            onAiPressed: onAiPressed,
            menuSections: menuSections,
          ),
          const HomeNavBarAdapter(highlightSelected: false),
        ],
      );
    }

    final media = MediaQuery.of(context);
    final bottomInset = hideChrome ? 16.0 + media.padding.bottom : 16.0;

    return Scaffold(
      appBar: null,
      body: AiScreenContext(
        context: baseAiContext,
        child: _wrapCanvas(
          Column(
            children: [
              Container(
                color: Colors.white,
                child: StandardTabBar(
                  controller: _tabController,
                  isScrollable: true,
                  dividerColor: Colors.grey[300],
                  indicatorWeight: 3,
                  labelColor: Colors.black,
                  unselectedLabelColor: Colors.grey[600],
                  tabs: const [
                    Tab(text: 'Contributors'),
                    Tab(text: 'Duration'),
                    Tab(text: 'Completion'),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(bottom: bottomInset),
                  child: LazyTabView(
                    physics: const NeverScrollableScrollPhysics(),
                    controller: _tabController,
                    children: [
                      TaskContributorList(
                        companyId: widget.companyId,
                        docId: widget.routineId,
                      ),
                      // TaskScatterPlot not ported in admin (no scatter widget).
                      const Center(child: Text('Duration chart unavailable.')),
                      TaskCompletion(
                        companyId: widget.companyId,
                        docId: widget.routineId,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
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
