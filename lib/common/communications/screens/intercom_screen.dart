import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kleenops_admin/app/shared_widgets/navigation/details_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/home_navbar_adapter.dart';
import 'package:kleenops_admin/common/communications/comm_menu.dart';
import 'package:kleenops_admin/features/auth/providers/auth_provider.dart';
import 'package:shared_widgets/drawers/menu_drawer.dart';

/// Intercom screen for the admin app.
///
/// Provides the same mode selection as the main app (Open Channel,
/// Push to Talk, Voice Call) then connects via the same Firestore
/// collections used by OpenChannelController / VideoCallService.
class AdminIntercomScreen extends ConsumerWidget {
  const AdminIntercomScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final companyAsync = ref.watch(companyIdProvider);
    final userAsync = ref.watch(userDocumentProvider);
    final menuSections = MenuDrawerSections(
      communications: buildAdminCommunicationMenuItems(context),
    );

    return Scaffold(
      body: SafeArea(
        child: companyAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (companyRef) {
            if (companyRef == null) {
              return const Center(child: Text('No company.'));
            }
            return userAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (userData) => _IntercomModeSelector(
                companyRef: companyRef,
                userData: userData,
              ),
            );
          },
        ),
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DetailsAppBar(title: 'Intercom', menuSections: menuSections),
          const HomeNavBarAdapter(),
        ],
      ),
    );
  }
}

class _IntercomModeSelector extends StatelessWidget {
  const _IntercomModeSelector({
    required this.companyRef,
    required this.userData,
  });
  final DocumentReference<Map<String, dynamic>> companyRef;
  final Map<String, dynamic> userData;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 32),
          Text(
            'Choose Intercom Mode',
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          _ModeCard(
            icon: Icons.podcasts,
            title: 'Open Channel',
            subtitle: 'Broadcast to a group — everyone listens',
            onTap: () => _showTeamPicker(context, 'openChannel'),
          ),
          const SizedBox(height: 12),
          _ModeCard(
            icon: Icons.mic_none,
            title: 'Push to Talk',
            subtitle: 'Walkie-talkie style — press to speak',
            onTap: () => _showTeamPicker(context, 'walkieTalkie'),
          ),
          const SizedBox(height: 12),
          _ModeCard(
            icon: Icons.record_voice_over,
            title: 'Voice Call',
            subtitle: 'One-to-one or conference call',
            onTap: () => _showTeamPicker(context, 'voice'),
          ),
        ],
      ),
    );
  }

  void _showTeamPicker(BuildContext context, String mode) {
    // The admin app creates intercom sessions via the same Firestore
    // collections (openChannel / videoRooms) that the main app uses.
    // WebRTC signaling is handled through Firestore documents.
    //
    // For now, show a snackbar indicating the session type selected.
    // Full WebRTC peer connection setup mirrors the main app's
    // OpenChannelSession / VideoChatPanel once flutter_webrtc is wired.
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Intercom mode: $mode — select team members to connect.'),
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon, size: 32),
        title: Text(title),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
