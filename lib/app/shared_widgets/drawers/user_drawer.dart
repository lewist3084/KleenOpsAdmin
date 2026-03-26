// Kleenops Admin adapter for the shared AppBarLogout drawer.

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kleenops_admin/app/routes.dart';
import 'package:shared_widgets/drawers/appbar_logout.dart' as shared;

class UserDrawer extends StatelessWidget {
  const UserDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final displayName = FirebaseAuth.instance.currentUser?.displayName;
    final headerTitle =
        (displayName != null && displayName.trim().isNotEmpty)
            ? displayName
            : 'Me';

    return Drawer(
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        child: shared.AppBarLogout(
          headerTitle: headerTitle,
          settingsLabel: 'Settings',
          logoutLabel: 'Logout',
          popOnSettingsTap: false,
          popOnLogoutTap: false,
          onSettingsTap: (ctx) async {
            Navigator.of(ctx).pop();
          },
          onLogoutTap: (ctx) async {
            Navigator.of(ctx).pop();
            await Future.microtask(() {});
            await FirebaseAuth.instance.signOut();
            if (ctx.mounted) ctx.go(AppRoutePaths.login);
          },
        ),
      ),
    );
  }
}
