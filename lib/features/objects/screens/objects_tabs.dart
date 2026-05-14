// lib/features/objects/screens/objects_tabs.dart
//
// Admin-side mirror of the regular CleanOps `objects_tabs.dart` screen.
// Provides the Objects + Charts tabs, the standard admin chrome
// (DetailsAppBar + HomeNavBarAdapter) and a bulk-edit control strip on the
// Objects tab — same layout the regular CleanOps app uses so the admin and
// the customer-facing app look identical when the user lands on Objects.

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod/legacy.dart';
import 'package:shared_widgets/buttons/control_strip_bottom.dart';
import 'package:shared_widgets/containers/canvas_top_bookend.dart';
import 'package:shared_widgets/containers/standard_canvas.dart';
import 'package:shared_widgets/drawers/menu_drawer.dart';
import 'package:shared_widgets/tabs/standard_tab.dart';

import '../../../app/shared_widgets/drawers/user_drawer.dart';
import '../../../app/shared_widgets/navigation/details_appbar_adapter.dart';
import '../../../app/shared_widgets/navigation/home_navbar_adapter.dart';
import '../../../common/communications/comm_menu.dart';
import 'objects_objects.dart';

/// Tracks which Objects tab the user is on so the bulk-edit control strip
/// can hide on tabs other than the Objects list.
final objectsTabIndexProvider = StateProvider<int>((_) => 0);

class ObjectsTabsScreen extends ConsumerStatefulWidget {
  const ObjectsTabsScreen({super.key});

  @override
  ConsumerState<ObjectsTabsScreen> createState() => _ObjectsTabsScreenState();
}

class _ObjectsTabsScreenState extends ConsumerState<ObjectsTabsScreen> {
  bool _searchVisible = false;
  /// Bumped each time the user taps the DetailsAppBar filter icon. The
  /// Objects tab content listens and opens its category filter dialog.
  final ValueNotifier<int> _filterTickVN = ValueNotifier<int>(0);

  void _toggleSearch() => setState(() => _searchVisible = !_searchVisible);

  @override
  void dispose() {
    _filterTickVN.dispose();
    super.dispose();
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

  Widget _buildBulkEditControlStrip(BuildContext context) {
    const placeholder = ControlStripAction(
      icon: Icons.circle,
      tooltip: '',
      enabled: false,
      iconColor: Colors.transparent,
    );

    return const ControlStripBottom(
      leftAction: placeholder,
      rightAction: placeholder,
      centerActions: [
        ControlStripAction(
          icon: Icons.copy,
          tooltip: 'Bulk edit objects',
          enabled: false,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeTabIndex = ref.watch(objectsTabIndexProvider);

    final menuSections = MenuDrawerSections(
      actions: const [],
      communications: buildAdminCommunicationMenuItems(context),
    );

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: null,
      drawer: const UserDrawer(),
      body: _wrapCanvas(_ObjectsTabs(
        searchVisible: _searchVisible,
        filterTickVN: _filterTickVN,
      )),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (activeTabIndex == 0) _buildBulkEditControlStrip(context),
          DetailsAppBar(
            title: 'Objects',
            menuSections: menuSections,
            onSearchToggle: _toggleSearch,
            searchActive: _searchVisible,
            // Only the Objects tab has a filter dialog.
            showSearchToggle: true,
            showFilterToggle: activeTabIndex == 0,
            onFilterToggle: activeTabIndex == 0
                ? () => _filterTickVN.value = _filterTickVN.value + 1
                : null,
            filterTooltipInactive: 'Filter by category',
            filterTooltipActive: 'Filter by category',
          ),
          const HomeNavBarAdapter(),
        ],
      ),
    );
  }
}

class _ObjectsTabs extends ConsumerStatefulWidget {
  const _ObjectsTabs({this.searchVisible = false, this.filterTickVN});

  final bool searchVisible;
  final ValueListenable<int>? filterTickVN;

  @override
  ConsumerState<_ObjectsTabs> createState() => _ObjectsTabsState();
}

class _ObjectsTabsState extends ConsumerState<_ObjectsTabs>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(objectsTabIndexProvider.notifier).state = _tabController.index;
    });
    _tabController.addListener(() {
      if (_tabController.indexIsChanging ||
          _tabController.index == _tabController.animation?.value) {
        ref.read(objectsTabIndexProvider.notifier).state =
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
            indicatorColor: Theme.of(context).primaryColor,
            indicatorWeight: 3.0,
            labelColor: Colors.black,
            unselectedLabelColor: Colors.grey[600],
            tabs: const [
              Tab(text: 'Objects'),
              Tab(text: 'Charts'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            physics: const NeverScrollableScrollPhysics(),
            controller: _tabController,
            children: [
              ObjectsObjectsContent(
                searchVisible: widget.searchVisible,
                filterTickVN: widget.filterTickVN,
              ),
              const Center(
                key: PageStorageKey('objects-charts'),
                child: Text('Charts coming soon'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
