// lib/common/communications/screens/directory_screen.dart
//
// Company directory — People (internal staff + external contacts) and
// Organizations (external companies). Ported from the kleenops app's HR
// Directory so the admin app surfaces the same People | Organizations tabs,
// All/Internal/External people filter, and per-entity detail (communications
// + notes). Launched from the menu drawer's Communications → Directory.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kleenops_admin/app/shared_widgets/drawers/appbar_logout_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/details_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/home_navbar_adapter.dart';
import 'package:kleenops_admin/common/communications/comm_menu.dart';
import 'package:kleenops_admin/features/directory/providers/directory_providers.dart';
import 'package:kleenops_admin/features/directory/screens/directory_tab_content.dart';
import 'package:kleenops_admin/services/ai/ai_context_service.dart';
import 'package:kleenops_admin/widgets/ai/ai_screen_context.dart';
import 'package:shared_widgets/containers/canvas_top_bookend.dart';
import 'package:shared_widgets/containers/standard_canvas.dart';
import 'package:shared_widgets/drawers/menu_drawer.dart';
import 'package:shared_widgets/tabs/lazy_tab_view.dart';
import 'package:shared_widgets/tabs/standard_tab.dart';

/// People | Organizations directory landing screen.
class AdminDirectoryScreen extends StatelessWidget {
  const AdminDirectoryScreen({super.key});

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
    final menuSections = MenuDrawerSections(
      communications: buildAdminCommunicationMenuItems(context),
    );

    return Scaffold(
      backgroundColor: Colors.grey[100],
      drawer: const UserDrawer(),
      body: AiScreenContext(
        context: const AiContextState(
          key: 'directory',
          sectionKey: 'directory',
          screenType: 'list',
        ),
        child: _wrapCanvas(const _DirectoryTabs()),
      ),
      bottomNavigationBar: Consumer(
        builder: (context, ref, _) {
          final controller = ref.read(aiCanvasControllerProvider);
          final filter = ref.watch(directoryPeopleFilterProvider);
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DetailsAppBar(
                title: 'Directory',
                onAiPressed: controller.toggle,
                menuSections: menuSections,
                // All/Internal/External people filter, surfaced on the appbar.
                showFilterToggle: true,
                filterActive: filter != DirectoryPeopleFilter.all,
                onFilterToggle: () => _showPeopleFilterSheet(context, ref),
              ),
              const HomeNavBarAdapter(),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showPeopleFilterSheet(BuildContext context, WidgetRef ref) {
    final current = ref.read(directoryPeopleFilterProvider);
    return showModalBottomSheet<void>(
      context: context,
      builder: (sheetCtx) {
        Widget option(
          String label,
          DirectoryPeopleFilter value,
          IconData icon,
        ) {
          final selected = current == value;
          return ListTile(
            leading: Icon(icon),
            title: Text(label),
            trailing: selected
                ? Icon(Icons.check,
                    color: Theme.of(sheetCtx).colorScheme.primary)
                : null,
            selected: selected,
            onTap: () {
              ref.read(directoryPeopleFilterProvider.notifier).state = value;
              Navigator.of(sheetCtx).pop();
            },
          );
        }

        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Show people',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              option('All', DirectoryPeopleFilter.all, Icons.people_outline),
              option('Internal', DirectoryPeopleFilter.internal,
                  Icons.badge_outlined),
              option('External', DirectoryPeopleFilter.external,
                  Icons.person_outline),
            ],
          ),
        );
      },
    );
  }
}

/// People | Organizations tabs. People = internal staff + external contacts
/// (with suggestions); Organizations = external companies (with suggestions).
class _DirectoryTabs extends StatelessWidget {
  const _DirectoryTabs();

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const StandardTabBar(
            tabs: [
              Tab(text: 'People'),
              Tab(text: 'Organizations'),
            ],
          ),
          Expanded(
            child: Builder(
              builder: (context) => LazyTabView(
                controller: DefaultTabController.of(context),
                children: const [
                  PeopleTabContent(),
                  OrganizationsTabContent(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
