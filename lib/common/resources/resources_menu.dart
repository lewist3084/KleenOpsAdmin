import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kleenops_admin/app/routes.dart';
import 'package:shared_widgets/drawers/menu_drawer.dart';

const String kFilesMenuLabel = 'Files';

/// Inject the "Files" entry into the drawer's Resources section (mirrors the
/// kleenops `withFilesInSections`). Idempotent.
MenuDrawerSections withFilesInSections(
  BuildContext context,
  MenuDrawerSections sections,
) {
  return MenuDrawerSections(
    actions: sections.actions,
    resources: withFilesResourceMenuItem(context, sections.resources),
    communications: sections.communications,
  );
}

List<ContentMenuItem> withFilesResourceMenuItem(
  BuildContext context,
  List<ContentMenuItem> resources,
) {
  final normalized = kFilesMenuLabel.toLowerCase();
  final hasFiles =
      resources.any((item) => item.label.trim().toLowerCase() == normalized);
  if (hasFiles) return resources;
  return [...resources, buildFilesMenuItem(context)];
}

ContentMenuItem buildFilesMenuItem(BuildContext context) {
  return ContentMenuItem(
    icon: Icons.insert_drive_file_outlined,
    label: kFilesMenuLabel,
    onTap: () => context.push(AppRoutePaths.drawerFiles),
  );
}

/// Back-compat: the Resources list (just Files) for any caller that still
/// passes `resources:` explicitly.
List<ContentMenuItem> buildAdminResourceMenuItems(BuildContext context) {
  return [buildFilesMenuItem(context)];
}
