// lib/features/training/tabs/training_employees_tabs.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod/legacy.dart';
import 'package:go_router/go_router.dart';
import 'package:kleenops_admin/app/routes.dart';
import 'package:kleenops_admin/app/shared_widgets/drawers/appbar_logout_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/details_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/home_navbar_adapter.dart';
import 'package:kleenops_admin/features/auth/providers/auth_provider.dart';
import 'package:kleenops_admin/features/training/forms/training_training_form.dart';
import 'package:kleenops_admin/services/ai/ai_context_service.dart';
import 'package:kleenops_admin/widgets/ai/ai_screen_context.dart';
import 'package:shared_widgets/containers/canvas_top_bookend.dart';
import 'package:shared_widgets/containers/container_header.dart';
import 'package:shared_widgets/containers/standard_canvas.dart';
import 'package:shared_widgets/drawers/menu_drawer.dart';
import 'package:shared_widgets/tabs/lazy_tab_view.dart';
import 'package:shared_widgets/tabs/standard_tab.dart';

import '../screens/training_employees.dart';
import '../screens/training_employees_charts.dart';
import '../screens/training_employee_records.dart';
import '../screens/training_employee_schedule.dart';

final trainingEmployeesTabsSearchVisibleProvider =
    StateProvider<bool>((_) => false);

/// Top-level screen with its own Scaffold (app bar + content + bottom nav)
class TrainingEmployeesTabsScreen extends StatelessWidget {
  final String? teamId;
  const TrainingEmployeesTabsScreen({super.key, this.teamId});

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
            title: 'Training Employees',
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
      appBar: null,
      drawer: const UserDrawer(),
      body: AiScreenContext(
        context: AiContextPresets.trainingEmployees(),
        child: _wrapCanvas(
          TrainingEmployeesTabs(teamId: teamId),
        ),
      ),
      bottomNavigationBar: Consumer(
        builder: (context, ref, _) {
          final controller = ref.read(aiCanvasControllerProvider);
          final companyRef = ref.watch(companyIdProvider).value;
          final menuSections = MenuDrawerSections(
            actions: [
              ContentMenuItem(
                icon: Icons.groups_outlined,
                label: 'Teams',
                onTap: () => context.push(AppRoutePaths.trainingTraining),
              ),
              ContentMenuItem(
                icon: Icons.menu_book_outlined,
                label: 'Library',
                onTap: () => context.push(AppRoutePaths.trainingStats),
              ),
              ContentMenuItem(
                icon: Icons.add,
                label: 'New Training',
                onTap: () {
                  if (companyRef == null) return;
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => TrainingTrainingForm(
                        companyId: companyRef,
                      ),
                    ),
                  );
                },
              ),
            ],
          );
          final searchActive =
              ref.watch(trainingEmployeesTabsSearchVisibleProvider);
          return buildBottomBar(
            onAiPressed: controller.toggle,
            menuSections: menuSections,
            searchActive: searchActive,
            onSearchToggle: () {
              final notifier = ref
                  .read(trainingEmployeesTabsSearchVisibleProvider.notifier);
              notifier.state = !notifier.state;
            },
          );
        },
      ),
    );
  }
}

class TrainingEmployeesTabs extends ConsumerWidget {
  final String? teamId;
  const TrainingEmployeesTabs({super.key, this.teamId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final companyRef = ref.watch(companyIdProvider).value;
    final bool hideChrome = false;
    final bottomInset = hideChrome
        ? 16.0 + MediaQuery.of(context).padding.bottom
        : 0.0;

    return DefaultTabController(
      length: 4,
      child: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          if (companyRef != null && teamId != null && teamId!.isNotEmpty)
            SliverToBoxAdapter(
              child: _TeamHeader(companyRef: companyRef, teamId: teamId!),
            ),
          SliverToBoxAdapter(
            child: Container(
              color: Colors.white,
              child: StandardTabBar(
                isScrollable: true,
                dividerColor: Colors.grey[300],
                indicatorWeight: 3,
                labelColor: Colors.black,
                unselectedLabelColor: Colors.grey[600],
                tabs: const [
                  Tab(text: 'Team Members'),
                  Tab(text: 'Charts'),
                  Tab(text: 'Records'),
                  Tab(text: 'Schedule'),
                ],
              ),
            ),
          ),
        ],
        body: Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: Builder(
            builder: (context) => LazyTabView(
              controller: DefaultTabController.of(context),
              physics: const NeverScrollableScrollPhysics(),
              children: [
                TrainingEmployeesContent(teamId: teamId),
                TrainingEmployeesChartsContent(teamId: teamId),
                TrainingEmployeeRecordsContent(teamId: teamId),
                TrainingEmployeeScheduleContent(teamId: teamId),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TeamHeader extends StatefulWidget {
  const _TeamHeader({
    required this.companyRef,
    required this.teamId,
  });

  final DocumentReference<Map<String, dynamic>> companyRef;
  final String teamId;

  @override
  State<_TeamHeader> createState() => _TeamHeaderState();
}

class _TeamHeaderState extends State<_TeamHeader> {
  Stream<DocumentSnapshot<Map<String, dynamic>>>? _teamHeaderStream;

  @override
  Widget build(BuildContext context) {
    final teamRef = FirebaseFirestore.instance.collection('team').doc(widget.teamId);
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _teamHeaderStream ??= teamRef.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const ContainerHeader(
            titleHeader: 'Team',
            title: 'Loading...',
            descriptionHeader: '',
            description: '',
            textIcon: Icons.groups_outlined,
            showImage: false,
          );
        }
        if (snapshot.hasError) {
          return const ContainerHeader(
            titleHeader: 'Team',
            title: 'Team info unavailable',
            descriptionHeader: '',
            description: '',
            textIcon: Icons.groups_outlined,
            showImage: false,
          );
        }

        final data = snapshot.data?.data();
        final name = (data?['name'] as String?) ??
            (data?['team'] as String?) ??
            widget.teamId;
        final description = (data?['description'] as String?) ?? '';
        final trimmedDescription = description.trim();

        return ContainerHeader(
          titleHeader: 'Team',
          title: name,
          descriptionHeader:
              trimmedDescription.isNotEmpty ? 'Description' : '',
          description: trimmedDescription,
          textIcon: Icons.groups_outlined,
          descriptionIcon: Icons.description_outlined,
          showImage: false,
        );
      },
    );
  }
}
