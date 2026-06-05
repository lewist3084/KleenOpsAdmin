import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:kleenops_admin/app/routes.dart';
import 'package:kleenops_admin/common/communications/calendar/calendar.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/home_navbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/details_appbar_adapter.dart';
import 'package:kleenops_admin/widgets/layout/bookended_canvas.dart';

/// Drawer-accessible communications calendar screen.
///
/// Top bookend sits just below the status bar, the calendar fills the middle,
/// and the [DetailsAppBar] is stacked above the [HomeNavBarAdapter] at the
/// bottom â€” same layout as the rest of the app. A FAB shares the design with
/// the list view for adding a new event.
class CommunicationsCalendarScreen extends ConsumerWidget {
  const CommunicationsCalendarScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searchActive = ref.watch(calendarSearchVisibleProvider);
    final layers = ref.watch(calendarLayersProvider);
    // "Active" whenever the selection differs from the default load
    // (calendar events + absences) â€” signals the user has scoped the view.
    final layersCustomized = layers.length != kDefaultCalendarLayers.length ||
        !layers.containsAll(kDefaultCalendarLayers);
    return Scaffold(
      body: const BookendedCanvas(child: CalendarContent()),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DetailsAppBar(
            title: 'Calendar',
            showSearchToggle: true,
            searchActive: searchActive,
            onSearchToggle: () {
              final notifier = ref.read(calendarSearchVisibleProvider.notifier);
              notifier.state = !notifier.state;
            },
            showFilterToggle: true,
            filterActive: layersCustomized,
            filterTooltipInactive: 'Filter calendar layers',
            filterTooltipActive: 'Calendar layers filtered',
            onFilterToggle: () => showCalendarLayerPicker(context, ref),
          ),
          const HomeNavBarAdapter(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'calendarAddFab',
        tooltip: 'Add event',
        onPressed: () => context.push(AppRoutes.drawerCalendarForm),
        child: const Icon(Icons.add),
      ),
    );
  }
}

