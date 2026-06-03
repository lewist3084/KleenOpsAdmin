// lib/common/communications/email/screens/email_settings_screen.dart
// Ported from the kleenops app. ADMIN ADAPTATIONS: no AI canvas / BookendedCanvas.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/home_navbar_adapter.dart';
import 'package:shared_widgets/theme/app_palette.dart';
import '../models/email_account.dart';
import '../providers/email_providers.dart';

class EmailSettingsScreen extends ConsumerWidget {
  const EmailSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts = ref.watch(currentUserMailboxesProvider);
    final current = ref.watch(currentEmailAccountProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Email Settings')),
      body: SafeArea(
        child: accounts.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (list) {
            if (list.isEmpty) return _buildEmptyState();
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: list.length,
              itemBuilder: (context, i) {
                final acct = list[i];
                return _MailboxCard(
                  mailbox: acct,
                  isSelected: current?.id == acct.id,
                  onSelect: () => ref
                      .read(selectedMailboxAddressProvider.notifier)
                      .state = acct.emailAddress,
                );
              },
            );
          },
        ),
      ),
      bottomNavigationBar: const HomeNavBarAdapter(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.email_outlined, size: 80, color: Colors.grey.shade400),
            const SizedBox(height: 24),
            Text(
              'No mailboxes assigned',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Ask an admin to grant you access to a company email address.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }
}

class _MailboxCard extends StatelessWidget {
  const _MailboxCard({
    required this.mailbox,
    required this.isSelected,
    required this.onSelect,
  });

  final EmailAccount mailbox;
  final bool isSelected;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onSelect,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor:
                    AppPaletteScope.of(context).primary2.withValues(alpha: 0.2),
                child: Icon(Icons.email,
                    color: AppPaletteScope.of(context).primary2),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            mailbox.displayName.isNotEmpty
                                ? mailbox.displayName
                                : mailbox.emailAddress,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        if (mailbox.isPrimary) _badge('Primary', Colors.green),
                        if (mailbox.isShared) _badge('Shared', Colors.orange),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      mailbox.emailAddress,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Icon(Icons.check_circle,
                    color: AppPaletteScope.of(context).primary2),
            ],
          ),
        ),
      ),
    );
  }

  Widget _badge(String label, MaterialColor color) {
    return Container(
      margin: const EdgeInsets.only(left: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          color: color.shade700,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
