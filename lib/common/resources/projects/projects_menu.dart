// lib/common/resources/projects/projects_menu.dart
//
// Injects a "Projects" entry into the menu drawer's Resources section, but only
// while the current route is inside the `scheduling` section — tasks can be
// assigned a project, so the project roster lives alongside scheduling. Mirrors
// the kleenops `projects_menu.dart`; modeled on `resources_menu.dart` (Files)
// except this one is section-gated rather than global.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kleenops_admin/app/routes.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/section_resolver.dart';
import 'package:shared_widgets/drawers/menu_drawer.dart';

const String kProjectsMenuLabel = 'Projects';

MenuDrawerSections withProjectsInSections(
  BuildContext context,
  MenuDrawerSections sections,
) {
  return MenuDrawerSections(
    actions: sections.actions,
    resources: withProjectsResourceMenuItem(context, sections.resources),
    communications: sections.communications,
  );
}

List<ContentMenuItem> withProjectsResourceMenuItem(
  BuildContext context,
  List<ContentMenuItem> resources,
) {
  if (currentAppSection(context) != 'scheduling') return resources;

  final normalized = kProjectsMenuLabel.toLowerCase();
  final hasEntry =
      resources.any((item) => item.label.trim().toLowerCase() == normalized);
  if (hasEntry) return resources;

  return [...resources, buildProjectsMenuItem(context)];
}

/// The drawer "Projects" entry. Opens the project roster, which owns the
/// `/scheduling/projects` location and a Home/Projects bottom nav bar.
ContentMenuItem buildProjectsMenuItem(BuildContext context) {
  return ContentMenuItem(
    icon: Icons.folder_special,
    label: kProjectsMenuLabel,
    onTap: () => context.push(AppRoutePaths.schedulingProjects),
  );
}
