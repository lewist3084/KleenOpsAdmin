// lib/features/tasks/screens/tasks_tasks_tabs.dart

import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kleenops_admin/features/tasks/screens/tasks_tasks.dart';
import 'package:kleenops_admin/features/tasks/screens/tasks_employee_tasks.dart';
import 'package:kleenops_admin/features/tasks/screens/tasks_performance.dart';
import 'package:kleenops_admin/features/tasks/screens/tasks_message.dart';
import 'package:kleenops_admin/features/tasks/screens/tasks_quality.dart';
import 'package:kleenops_admin/features/tasks/screens/dialogs/task_settings_dialog.dart';
import 'package:kleenops_admin/features/tasks/providers/tasks_provider.dart';
import 'package:kleenops_admin/features/tasks/providers/task_list_controller.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kleenops_admin/features/auth/providers/auth_provider.dart';
import 'package:kleenops_admin/repositories/task_repository.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/details_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/home_navbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/drawers/appbar_logout_adapter.dart';
import 'package:kleenops_admin/app/routes.dart';
import 'package:kleenops_admin/services/ai/ai_context_service.dart';
import 'package:kleenops_admin/widgets/ai/ai_screen_context.dart';
import 'package:shared_widgets/containers/canvas_top_bookend.dart';
import 'package:shared_widgets/containers/standard_canvas.dart';
import 'package:shared_widgets/drawers/menu_drawer.dart';
import 'package:kleenops_admin/features/tasks/logic/time_based_rebuild_mixin.dart';
import 'package:shared_widgets/tabs/lazy_tab_view.dart';
import 'package:shared_widgets/tabs/standard_tab.dart';

String _debugLocation(BuildContext context) {
  final router = GoRouter.maybeOf(context);
  if (router == null) return 'no-router';
  final info = router.routeInformationProvider.value;
  final uri = info.uri;
  if (uri != null && uri.toString().isNotEmpty) return uri.toString();
  final location = info.location;
  if (location != null && location.isNotEmpty) return location;
  return 'unknown';
}

/// Top-level screen with its own Scaffold (app bar + content + bottom nav)
class TasksTasksTabsScreen extends ConsumerWidget {
  const TasksTasksTabsScreen({super.key});

  void _debugLog(String message) {
    if (!kDebugMode) return;
    debugPrint('[TasksTasksTabsScreen] $message');
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
  Widget build(BuildContext context, WidgetRef ref) {
    _debugLog(
      'build location=${_debugLocation(context)}',
    );
    final tabIndex = ref.watch(tasksTabIndexProvider);
    final isTasksTab = tabIndex == 0;
    final bool hideChrome = false;

    Widget buildBottomBar({
      VoidCallback? onAiPressed,
      MenuDrawerSections? menuSections,
      required bool searchActive,
      required VoidCallback onSearchToggle,
      VoidCallback? onFilterToggle,
    }) {
      if (hideChrome) return const SizedBox.shrink();
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DetailsAppBar(
            title: 'Tasks',
            onAiPressed: onAiPressed,
            menuSections: menuSections,
            showSearchToggle: isTasksTab,
            searchActive: searchActive,
            onSearchToggle: isTasksTab ? onSearchToggle : null,
            showFilterToggle: isTasksTab && onFilterToggle != null,
            onFilterToggle: onFilterToggle,
            filterTooltipInactive: 'Filters',
          ),
          const HomeNavBarAdapter(),
        ],
      );
    }

    return Scaffold(
      appBar: null,
      drawer: const UserDrawer(),
      body: AiScreenContext(
        context: AiContextPresets.tasksTabs(),
        child: _wrapCanvas(
          const TasksTasksTabs(),
        ),
      ),
      bottomNavigationBar: hideChrome
          ? null
          : Consumer(
              builder: (context, ref, _) {
                final controller = ref.read(aiCanvasControllerProvider);
                // Admin has no `buildTaskActionMenuItems` helper; mirror the
                // hand-rolled task hub menu used by admin's TasksHome.
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
                      onTap: () =>
                          context.push(AppRoutePaths.tasksDependability),
                    ),
                    ContentMenuItem(
                      icon: Icons.trending_up_outlined,
                      label: 'Performance',
                      onTap: () => context.push(AppRoutePaths.tasksPerformance),
                    ),
                    ContentMenuItem(
                      icon: Icons.timer_outlined,
                      label: 'Timecard',
                      onTap: () =>
                          context.push(AppRoutePaths.tasksTimecardTabs),
                    ),
                    ContentMenuItem(
                      icon: Icons.assignment_ind_outlined,
                      label: 'Employee Tasks',
                      onTap: () =>
                          context.push(AppRoutePaths.tasksEmployeeTasks),
                    ),
                  ],
                );
                final searchActive = ref.watch(
                  taskListControllerProvider
                      .select((s) => s.searchBarVisible),
                );
                final userDoc =
                    ref.watch(userDocumentProvider).asData?.value;
                final memberRef = userDoc?['memberRef']
                    as DocumentReference<Map<String, dynamic>>?;
                final onFilterToggle = (userDoc != null && memberRef != null)
                    ? () => showTaskSettingsDialog(
                          context,
                          memberRef,
                          userDoc,
                        )
                    : null;
                return buildBottomBar(
                  onAiPressed: controller.toggle,
                  menuSections: menuSections,
                  searchActive: searchActive,
                  onSearchToggle: () => ref
                      .read(taskListControllerProvider.notifier)
                      .toggleSearchBar(),
                  onFilterToggle: onFilterToggle,
                );
              },
            ),
    );
  }
}

class TasksTasksTabs extends ConsumerStatefulWidget {
  const TasksTasksTabs({super.key});

  @override
  _TasksTasksTabsState createState() => _TasksTasksTabsState();
}

class _TasksTasksTabsState extends ConsumerState<TasksTasksTabs>
    with
        TickerProviderStateMixin,
        WidgetsBindingObserver,
        TimeBasedRebuildMixin<TasksTasksTabs> {
  TabController? _tabController;
  int _previousTabCount = 0;

  // Memoized streams for the four queries that decide tab existence. Without
  // this cache, every parent rebuild (`TimeBasedRebuildMixin` ticks every
  // 5 min, plus tab swaps and boundary timers) creates fresh `.snapshots()`
  // subscriptions = 4 full re-reads on every tick.
  Stream<QuerySnapshot<Map<String, dynamic>>>? _trainingStream;
  Stream<QuerySnapshot<Map<String, dynamic>>>? _performanceStream;
  Stream<QuerySnapshot<Map<String, dynamic>>>? _qualityStream;
  Stream<QuerySnapshot<Map<String, dynamic>>>? _messageStream;
  String? _streamsKey;

  void _ensureStreams({
    required TaskRepository repo,
    required String companyId,
    required DocumentReference<Map<String, dynamic>> companyRef,
    required DocumentReference<Map<String, dynamic>> memberRef,
  }) {
    final key = '$companyId|${memberRef.path}';
    if (_streamsKey == key && _trainingStream != null) return;
    _streamsKey = key;
    _trainingStream = companyRef
        .collection('assignedTraining')
        .where('memberId', isEqualTo: memberRef)
        .snapshots();
    _performanceStream = _pendingTimelineQuery(
      repo: repo,
      companyId: companyId,
      categoryId: 'tduBfySxxvZulBq6Qqv6',
      memberRef: memberRef,
    ).limit(1).snapshots();
    _qualityStream = _pendingTimelineQuery(
      repo: repo,
      companyId: companyId,
      categoryId: 'VdjzT5izZVSWmrhfRRq0',
      memberRef: memberRef,
    ).limit(1).snapshots();
    _messageStream = _pendingMessageBoardQuery(
      repo: repo,
      companyId: companyId,
      memberRef: memberRef,
    ).limit(50).snapshots();
  }

  void _debugLog(String message) {
    if (!kDebugMode) return;
    debugPrint('[TasksTasksTabs] $message');
  }

  Query<Map<String, dynamic>> _pendingTimelineQuery({
    required TaskRepository repo,
    required String companyId,
    required String categoryId,
    required DocumentReference<Map<String, dynamic>> memberRef,
  }) {
    return repo
        .timelineCollection(companyId)
        .where('timelineCategory', isEqualTo: categoryId)
        .where('opened', isEqualTo: false)
        .where('memberId', isEqualTo: memberRef);
  }

  Query<Map<String, dynamic>> _pendingMessageBoardQuery({
    required TaskRepository repo,
    required String companyId,
    required DocumentReference<Map<String, dynamic>> memberRef,
  }) {
    final categoryRef = repo.timelineCategoryDoc('S9V5v5L4ZJVujaMyemzP');
    return repo
        .timelineCollection(companyId)
        .where('timelineCategoryId', isEqualTo: categoryRef)
        .where('memberIds', arrayContains: memberRef)
        .orderBy('createdAt');
  }

  Set<String> _coerceRefPathSet(dynamic raw) {
    final paths = <String>{};
    if (raw is Iterable) {
      for (final item in raw) {
        if (item is DocumentReference) {
          paths.add(item.path);
        } else if (item is String) {
          paths.add(item);
        }
      }
    }
    return paths;
  }

  Widget _buildTabbedScaffold({
    required List<Tab> tabs,
    required List<Widget> tabViews,
  }) {
    assert(tabs.length == tabViews.length && tabs.isNotEmpty);

    final tabCount = tabs.length;
    if (_tabController == null || _previousTabCount != tabCount) {
      _tabController?.dispose();
      _tabController = TabController(length: tabCount, vsync: this);
      _previousTabCount = tabCount;

      ref.read(tasksTabIndexProvider.notifier).state = _tabController!.index;

      _tabController!.addListener(() {
        if (_tabController!.indexIsChanging ||
            _tabController!.index == _tabController!.animation?.value) {
          ref.read(tasksTabIndexProvider.notifier).state =
              _tabController!.index;
        }
      });
    }

    final media = MediaQuery.of(context);
    final bool hideChrome = false;
    final bottomInset = hideChrome ? 16.0 + media.padding.bottom : 0.0;

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
            tabs: tabs,
          ),
        ),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: bottomInset),
            child: LazyTabView(
              physics: const NeverScrollableScrollPhysics(),
              controller: _tabController,
              children: tabViews,
            ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _debugLog(
      'build location=${_debugLocation(context)} '
      'tabIndex=${_tabController?.index ?? -1}',
    );
    final userDocAsync = ref.watch(userDocumentProvider);

    return userDocAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      // Show a friendly sign-in prompt instead of raw error text
      error: (err, _) =>
          const Center(child: Text('Please sign-in to view tasks')),
      data: (data) {
        final bool isClockedIn = data['clockedIn'] == true;
        final bool overrideClockIn = data['overrideClockIn'] == true;
        final bool canTasksEngagement = data['canTasksEngagement'] == true;

        final memberRef =
            data['memberRef'] as DocumentReference<Map<String, dynamic>>?;
        if (memberRef == null) {
          return const Center(child: Text('Member not linked.'));
        }

        return ref.watch(companyIdProvider).when(
              loading: () => const Center(
                child: CircularProgressIndicator(),
              ),
              error: (error, _) =>
                  Center(child: Text('Error loading company: $error')),
              data: (companyRef) {
                if (companyRef == null || companyRef.id.isEmpty) {
                  return const Center(child: Text('No company found.'));
                }

                _ensureStreams(
                  repo: ref.read(taskRepositoryProvider),
                  companyId: companyRef.id,
                  companyRef: companyRef,
                  memberRef: memberRef,
                );

                Widget buildMainContent() {
                  return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: _trainingStream,
                    builder: (context, trainingSnap) {
                      // Only block tabs when training is definitively expired.
                      // Initial-assignment grace and renewal warnings are handled
                      // inside the Tasks tab content (overlay with acknowledge).
                      var needsTraining = false;
                      if (trainingSnap.hasData) {
                        final now = DateTime.now();
                        for (final d in trainingSnap.data!.docs) {
                          final t = d.data();
                          final goodUntil =
                              (t['goodUntil'] as Timestamp?)?.toDate();
                          final taskLock =
                              t['taskLockout'] == true || t['lockout'] == true;
                          if (goodUntil != null &&
                              taskLock &&
                              now.isAfter(goodUntil)) {
                            needsTraining = true;
                            break;
                          }
                        }
                      }

                      // Existence-only checks — perf / quality / message
                      // streams are memoized on State (see `_ensureStreams`)
                      // so they don't re-subscribe on each 5-min rebuild tick.
                      return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: _performanceStream,
                        builder: (context, perfSnap) {
                          final hasPendingPerformance = perfSnap.hasData &&
                              perfSnap.data!.docs.isNotEmpty;

                          return StreamBuilder<
                              QuerySnapshot<Map<String, dynamic>>>(
                            stream: _qualityStream,
                            builder: (context, qualSnap) {
                              final hasPendingQuality = qualSnap.hasData &&
                                  qualSnap.data!.docs.isNotEmpty;

                              // Build tabs based on priority
                              final List<Tab> tabs = [];
                              final List<Widget> tabViews = [];

                              if (hasPendingPerformance) {
                                tabs.add(const Tab(text: 'Performance'));
                                tabViews.add(const TasksPerformanceContent(
                                    key: PageStorageKey('performance-tab')));
                              } else if (hasPendingQuality) {
                                tabs.add(const Tab(text: 'Quality'));
                                tabViews.add(const TasksQualityContent(
                                    key: PageStorageKey('quality-tab')));
                              } else {
                                // ───────── Tasks tab ─────────
                                tabs.add(const Tab(text: 'Tasks'));
                                tabViews.add(
                                  (isClockedIn || overrideClockIn)
                                      ? (needsTraining
                                          ? const Center(
                                              key: PageStorageKey(
                                                  'tasks-training-msg'),
                                              child: Text(
                                                'Please complete required training under Training',
                                              ),
                                            )
                                          : const TasksTasksContent(
                                              key: PageStorageKey('tasks-tab'),
                                            ))
                                      : const Center(
                                          key: PageStorageKey(
                                              'tasks-clockin-msg'),
                                          child: Text(
                                              'Please clock-in under Timecard'),
                                        ),
                                );

                                // ───────── Employee Tasks tab ─────────
                                tabs.add(const Tab(text: 'My Tasks'));
                                tabViews.add(
                                  (isClockedIn || overrideClockIn)
                                      ? (needsTraining
                                          ? const Center(
                                              key: PageStorageKey(
                                                  'employee-tasks-training-msg'),
                                              child: Text(
                                                'Please complete required training under Training',
                                              ),
                                            )
                                          : const TasksEmployeeTasksContent(
                                              key: PageStorageKey(
                                                  'employee-tasks-tab'),
                                            ))
                                      : const Center(
                                          key: PageStorageKey(
                                              'employee-tasks-clockin-msg'),
                                          child: Text(
                                              'Please clock-in under Timecard'),
                                        ),
                                );

                                // ───────── Engagement tab (optional) ─────────
                                if (canTasksEngagement) {
                                  tabs.add(const Tab(text: 'Engagement'));
                                  tabViews.add(const Center(
                                    key: PageStorageKey('engagement-tab'),
                                    child: Text('Engagement Tab Content Placeholder'),
                                  ));
                                }
                              }

                              return _buildTabbedScaffold(
                                tabs: tabs,
                                tabViews: tabViews,
                              );
                            },
                          );
                        },
                      );
                    },
                  );
                }

                if (memberRef == null) {
                  return buildMainContent();
                }

                // Acknowledgment dedup happens client-side (Firestore can't
                // express array-not-contains), so the stream caps the live
                // window to 50 (see _ensureStreams).
                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _messageStream,
                  builder: (context, messageSnap) {
                    if (messageSnap.connectionState ==
                            ConnectionState.waiting &&
                        !messageSnap.hasData) {
                      return const Center(
                        child: CircularProgressIndicator(),
                      );
                    }

                    final docs = messageSnap.data?.docs ??
                        const <QueryDocumentSnapshot<Map<String, dynamic>>>[];
                    final pendingDocs = docs.where((doc) {
                      final ackPaths = _coerceRefPathSet(
                          doc.data()['acknowledgedMemberIds']);
                      return !ackPaths.contains(memberRef.path);
                    }).toList();

                    if (pendingDocs.isNotEmpty) {
                      final tabs = <Tab>[
                        const Tab(text: 'Message Board'),
                      ];
                      final tabViews = <Widget>[
                        TasksMessageContent(
                          key: const PageStorageKey('message-board-tab'),
                          pendingDocs: List<
                              QueryDocumentSnapshot<
                                  Map<String, dynamic>>>.unmodifiable(
                            pendingDocs,
                          ),
                          memberRef: memberRef,
                        ),
                      ];
                      return _buildTabbedScaffold(
                        tabs: tabs,
                        tabViews: tabViews,
                      );
                    }

                    return buildMainContent();
                  },
                );
              },
            );
      },
    );
  }
}
