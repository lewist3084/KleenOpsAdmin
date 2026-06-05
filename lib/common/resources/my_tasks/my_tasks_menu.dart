// Injects a "My Tasks" entry into every screen's drawer Actions section.
// Mirrors the kleenops helper so a single hook in the appbar adapters makes
// it universal. Opens the My Tasks list (pending action items under
// kleenops/{id}/member/{mid}/myTask).

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kleenops_admin/app/routes.dart';
import 'package:kleenops_admin/common/resources/menu_badges.dart';
import 'package:shared_widgets/drawers/menu_drawer.dart';

const String kMyTasksMenuLabel = 'My Tasks';

MenuDrawerSections withMyTasksInSections(
  BuildContext context,
  MenuDrawerSections sections,
) {
  return MenuDrawerSections(
    actions: withMyTasksActionMenuItem(context, sections.actions),
    resources: sections.resources,
    communications: sections.communications,
  );
}

List<ContentMenuItem> withMyTasksActionMenuItem(
  BuildContext context,
  List<ContentMenuItem> actions,
) {
  final normalized = kMyTasksMenuLabel.toLowerCase();
  final hasEntry =
      actions.any((item) => item.label.trim().toLowerCase() == normalized);
  if (hasEntry) return actions;
  return [
    buildMyTasksMenuItem(context),
    ...actions,
  ];
}

ContentMenuItem buildMyTasksMenuItem(BuildContext context) {
  return ContentMenuItem(
    icon: Icons.checklist,
    label: kMyTasksMenuLabel,
    badge: menuBadge(myTasksPendingCountProvider),
    onTap: () => context.push(AppRoutePaths.drawerMyTasks),
  );
}
