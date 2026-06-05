// Kleenops Admin adapter for the shared AppBarLogout user drawer.
//
// Mirrors the kleenops `appbar_logout_adapter.dart`. Wires the shared widget to:
//   - Settings ("Me") -> /me/info
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
import 'package:kleenops_admin/app/shared_widgets/navigation/import_actions.dart';
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
      settingsLabel: 'Me',
      settingsIcon: Icons.person_outline,
      logoutLabel: 'Logout',
      popOnSettingsTap: false,
      popOnLogoutTap: false,
      // Meeting Minutes, Notes and Import are always available here,
      // independent of which screen the user is on.
      extraItems: [
        shared.UserDrawerItem(
          icon: Icons.record_voice_over_outlined,
          label: 'Meeting Minutes',
          onTap: (ctx) => ctx.push(AppRoutePaths.drawerMeetingMinutes),
        ),
        shared.UserDrawerItem(
          icon: Icons.note_alt_outlined,
          label: 'Notes',
          onTap: (ctx) => ctx.push(AppRoutePaths.drawerNotes),
        ),
        shared.UserDrawerItem(
          icon: kImportActionIcon,
          label: kImportActionLabel,
          onTap: (ctx) => showImportDialog(ctx),
        ),
      ],
      onSettingsTap: (ctx) async {
        Navigator.of(ctx).pop();
        await Future.microtask(() {});
        if (ctx.mounted) ctx.go(AppRoutePaths.meInfo);
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
