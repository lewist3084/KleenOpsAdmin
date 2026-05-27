// lib/features/processes/tabs/processes_tabs.dart
// DEGRADED: dropped AiScreenContext+UserDrawer+AiContextPresets.processesList
// (admin's preset registry doesn't include them); chrome via DetailsAppBar+HomeNavBarAdapter.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod/legacy.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/details_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/home_navbar_adapter.dart';
import 'package:kleenops_admin/features/processes/providers/processes_provider.dart';
import 'package:kleenops_admin/features/processes/screens/processes_category_list.dart';
import 'package:kleenops_admin/features/processes/screens/processes_processes.dart';
import 'package:kleenops_admin/services/ai/ai_context_service.dart';
import 'package:shared_widgets/containers/canvas_top_bookend.dart';
import 'package:shared_widgets/containers/standard_canvas.dart';
import 'package:shared_widgets/tabs/lazy_tab_view.dart';
import 'package:shared_widgets/tabs/standard_tab.dart';

final processesTabsSearchVisibleProvider = StateProvider<bool>((_) => false);

/// Top-level screen with its own Scaffold (app bar + content + bottom nav)
class ProcessesTabsScreen extends StatelessWidget {
  const ProcessesTabsScreen({super.key});

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
      required bool searchActive,
      required VoidCallback onSearchToggle,
    }) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DetailsAppBar(
            title: 'Processes',
            onAiPressed: onAiPressed,
            showSearchToggle: true,
            searchActive: searchActive,
            onSearchToggle: onSearchToggle,
          ),
          const HomeNavBarAdapter(),
        ],
      );
    }

    return Scaffold(
      appBar: null,
      body: _wrapCanvas(const ProcessesTabs()),
      bottomNavigationBar: Consumer(
        builder: (context, ref, _) {
          final controller = ref.read(aiCanvasControllerProvider);
          final searchActive = ref.watch(processesTabsSearchVisibleProvider);
          return buildBottomBar(
            onAiPressed: controller.toggle,
            searchActive: searchActive,
            onSearchToggle: () {
              final notifier =
                  ref.read(processesTabsSearchVisibleProvider.notifier);
              notifier.state = !notifier.state;
            },
          );
        },
      ),
    );
  }
}

class ProcessesTabs extends ConsumerStatefulWidget {
  /// Pass in a teamId (from a query parameter) to filter the teams view.
  final String? teamId;
  const ProcessesTabs({super.key, this.teamId});

  @override
  ConsumerState<ProcessesTabs> createState() => _ProcessesTabsState();
}

class _ProcessesTabsState extends ConsumerState<ProcessesTabs>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging ||
          _tabController.index == _tabController.animation?.value) {
        ref.read(processesTabIndexProvider.notifier).state =
            _tabController.index;
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
    return Column(
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
              Tab(text: 'Processes'),
              Tab(text: 'Categories'),
            ],
          ),
        ),
        Expanded(
          child: LazyTabView(
            physics: const NeverScrollableScrollPhysics(),
            controller: _tabController,
            children: const [
              ProcessesProcessesContent(),
              ProcessesCategoryListScreen(),
            ],
          ),
        ),
      ],
    );
  }
}
