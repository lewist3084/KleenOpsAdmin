// Kleenops Admin adapter for the shared AppBarLogout user drawer.
//
// Wires the shared widget to:
//   - Settings -> no-op (just closes drawer for now)
//   - Report Issue -> AppOwnerReport cloud function
//   - Log out -> FirebaseAuth.signOut + /login
//   - Delete account -> deleteUserAccount callable
//
// Note: AppBarLogout is itself a Drawer; do NOT wrap it in another Drawer.

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kleenops_admin/app/routes.dart';
import 'package:shared_widgets/dialogs/report_issue_dialog.dart';
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

    return shared.AppBarLogout(
      headerTitle: headerTitle,
      settingsLabel: 'Settings',
      logoutLabel: 'Logout',
      popOnSettingsTap: false,
      popOnLogoutTap: false,
      onSettingsTap: (ctx) async {
        Navigator.of(ctx).pop();
      },
      onReportIssueTap: (ctx) async {
        // Drawer is already popped by the shared widget.
        await showReportIssueDialog(ctx, sourceApp: 'kleenops_admin');
      },
      onLogoutTap: (ctx) async {
        Navigator.of(ctx).pop();
        await Future.microtask(() {});
        await FirebaseAuth.instance.signOut();
        if (ctx.mounted) ctx.go(AppRoutePaths.login);
      },
      onDeleteAccountTap: (ctx) => _confirmDeleteAccount(ctx),
    );
  }

  Future<void> _confirmDeleteAccount(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text(
          'This will permanently delete your account and all associated data.\n\n'
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete My Account'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final callable = FirebaseFunctions.instanceFor(region: 'us-central1')
          .httpsCallable('deleteUserAccount');
      await callable.call();

      if (context.mounted) {
        Navigator.of(context).pop(); // dismiss loading
        context.go(AppRoutePaths.login);
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop(); // dismiss loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Account deletion failed: $e')),
        );
      }
    }
  }
}
