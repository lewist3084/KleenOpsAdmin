import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kleenops_admin/app/routes.dart';
import 'package:shared_widgets/drawers/menu_drawer.dart';

/// Resource menu items for the admin app menu drawer's "Resources" section.
/// Mirrors the main KleenOps app — currently the drive-style Files browser.
List<ContentMenuItem> buildAdminResourceMenuItems(BuildContext context) {
  return [
    ContentMenuItem(
      icon: Icons.insert_drive_file_outlined,
      label: 'Files',
      onTap: () => context.push(AppRoutePaths.drawerFiles),
    ),
  ];
}
