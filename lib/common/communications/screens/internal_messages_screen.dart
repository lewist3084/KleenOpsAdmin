import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:kleenops_admin/app/shared_widgets/navigation/details_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/home_navbar_adapter.dart';
import 'package:kleenops_admin/common/communications/comm_menu.dart';
import 'package:kleenops_admin/features/auth/providers/auth_provider.dart';
import 'package:shared_widgets/drawers/menu_drawer.dart';
import '../models/text_conversation.dart';
import '../services/texting_service.dart';
import 'message_detail_screen.dart';

class InternalMessagesScreen extends ConsumerWidget {
  const InternalMessagesScreen({super.key});

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
              return const Center(child: Text('No company selected.'));
            }
            return userAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (userData) {
                final memberRef = userData['memberRef']
                    as DocumentReference<Map<String, dynamic>>?;
                final memberName = (userData['name'] as String?) ??
                    (userData['displayName'] as String?) ??
                    '';
                if (memberRef == null) {
                  return const Center(child: Text('No member record.'));
                }
                final service = TextingService(
                  companyRef: companyRef,
                  memberRef: memberRef,
                  memberName: memberName,
                );
                return _ConversationsList(
                  service: service,
                  currentMemberId: memberRef.id,
                );
              },
            );
          },
        ),
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DetailsAppBar(title: 'Internal Messages', menuSections: menuSections),
          const HomeNavBarAdapter(),
        ],
      ),
    );
  }
}

class _ConversationsList extends StatelessWidget {
  const _ConversationsList({
    required this.service,
    required this.currentMemberId,
  });
  final TextingService service;
  final String currentMemberId;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<TextConversation>>(
      stream: service.watchConversations(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final convos = snap.data ?? [];
        if (convos.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.chat_outlined, size: 64, color: Colors.grey.shade400),
                const SizedBox(height: 16),
                Text('No messages yet',
                    style: TextStyle(fontSize: 16, color: Colors.grey.shade600)),
              ],
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: convos.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final convo = convos[index];
            final title = convo.getDisplayTitle(currentMemberId);
            final timeStr = convo.lastMessageAt != null
                ? DateFormat.jm().format(convo.lastMessageAt!)
                : '';
            return ListTile(
              leading: CircleAvatar(
                child: Icon(convo.isGroup ? Icons.group : Icons.person),
              ),
              title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: convo.lastMessageText != null
                  ? Text(
                      '${convo.lastMessageSenderName ?? ''}: ${convo.lastMessageText}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    )
                  : null,
              trailing: Text(timeStr,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => MessageDetailScreen(
                    conversationRef: convo.ref,
                    conversationTitle: title,
                    service: service,
                    currentMemberId: currentMemberId,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
