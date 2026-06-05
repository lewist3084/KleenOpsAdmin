// lib/common/communications/texting/screens/text_conversations_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:kleenops_admin/app/shared_widgets/navigation/details_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/home_navbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/search/search_control_strip_adapter.dart';
import 'package:kleenops_admin/services/ai/ai_context_service.dart';
import 'package:kleenops_admin/features/auth/providers/auth_provider.dart';
import 'package:shared_widgets/theme/app_palette.dart';
import 'package:shared_widgets/tiles/standard_bubble_tile.dart';
import 'package:kleenops_admin/widgets/layout/bookended_canvas.dart';
import 'package:shared_widgets/drawers/menu_drawer.dart';
import 'package:shared_widgets/dialogs/dialog_action.dart';
import '../models/text_conversation.dart';
import '../services/texting_service.dart';
import '../services/external_sms_service.dart';
import '../providers/external_sms_providers.dart';
import 'text_conversation_detail_screen.dart';
import 'new_conversation_screen.dart';

class TextConversationsScreen extends ConsumerStatefulWidget {
  const TextConversationsScreen({super.key});

  @override
  ConsumerState<TextConversationsScreen> createState() =>
      _TextConversationsScreenState();
}

class _TextConversationsScreenState
    extends ConsumerState<TextConversationsScreen> {
  // The drawer's text badge is `member.unreadTextCount`, kept in sync by the
  // `reconcileUnreadText` Cloud Function from per-message `readByMemberIds`
  // writes. Opening a conversation calls `markMessagesAsRead`, which lets the
  // trigger drop the badge naturally — no blanket-zero on this list screen.

  final TextEditingController _searchCtl = TextEditingController();
  bool _searchVisible = false;
  String _searchQuery = '';

  @override
  void dispose() {
    _searchCtl.dispose();
    super.dispose();
  }

  void _toggleSearch() {
    setState(() {
      _searchVisible = !_searchVisible;
      if (!_searchVisible) {
        _searchCtl.clear();
        _searchQuery = '';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.read(aiCanvasControllerProvider);
    final menuSections = MenuDrawerSections(
      actions: const <ContentMenuItem>[],
      resources: const <ContentMenuItem>[],
    );

    return Scaffold(
      appBar: null,
      body: BookendedCanvas(
        child: Column(
          children: [
            if (_searchVisible)
              SearchControlStrip(
                controller: _searchCtl,
                hintText: 'Search messages',
                autofocus: true,
                onChanged: (t) => setState(() => _searchQuery = t.trim()),
              ),
            Expanded(child: _ConversationsList(searchQuery: _searchQuery)),
          ],
        ),
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DetailsAppBar(
            title: 'Messages',
            onAiPressed: controller.toggle,
            menuSections: menuSections,
            showSearchToggle: true,
            searchActive: _searchVisible,
            onSearchToggle: _toggleSearch,
          ),
          const HomeNavBarAdapter(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'textNewConversationFab',
        onPressed: () => _startNewConversation(context),
        tooltip: 'New Message',
        child: const Icon(Icons.add),
      ),
    );
  }

  void _startNewConversation(BuildContext context) {
    // Members with an assigned texting number can also start an external SMS;
    // everyone else goes straight to the internal member picker.
    if (!ref.read(hasAssignedSmsNumberProvider)) {
      _openInternalNewConversation(context);
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.person_add_alt_1_outlined),
              title: const Text('New message'),
              subtitle: const Text('To a team member'),
              onTap: () {
                Navigator.pop(sheetCtx);
                _openInternalNewConversation(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.sms_outlined),
              title: const Text('New external text'),
              subtitle: const Text('To an outside phone number'),
              onTap: () {
                Navigator.pop(sheetCtx);
                _composeExternal(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _openInternalNewConversation(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const NewConversationScreen(),
      ),
    );
  }

  Future<void> _composeExternal(BuildContext context) async {
    final companyRef = ref.read(companyIdProvider).value;
    if (companyRef == null) return;

    final phoneCtl = TextEditingController();
    final nameCtl = TextEditingController();
    final input = await showDialog<bool>(
      context: context,
      builder: (ctx) => DialogAction(
        title: 'New external text',
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: phoneCtl,
              autofocus: true,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Phone number',
                hintText: '(555) 123-4567',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: nameCtl,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Name (optional)',
              ),
            ),
          ],
        ),
        cancelText: 'Cancel',
        onCancel: () => Navigator.of(ctx).pop(false),
        actionText: 'Start',
        onAction: () => Navigator.of(ctx).pop(true),
      ),
    );
    final phone = phoneCtl.text.trim();
    final name = nameCtl.text.trim();
    phoneCtl.dispose();
    nameCtl.dispose();
    if (input != true || phone.isEmpty) return;

    try {
      final convId = await ExternalSmsService.instance.getOrCreateConversation(
        companyId: companyRef.id,
        toPhone: phone,
        title: name.isEmpty ? null : name,
      );
      if (!context.mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => TextConversationDetailScreen(
            conversationRef:
                companyRef.collection('textConversation').doc(convId),
          ),
        ),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not start text: $e')),
        );
      }
    }
  }
}

class _ConversationsList extends ConsumerWidget {
  const _ConversationsList({this.searchQuery = ''});

  final String searchQuery;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final companyAsync = ref.watch(companyIdProvider);
    final userDocAsync = ref.watch(userDocumentProvider);

    return companyAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (companyRef) {
        if (companyRef == null) {
          return const Center(child: Text('No company selected.'));
        }

        return userDocAsync.when(
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

            return StreamBuilder<List<TextConversation>>(
              stream: service.watchConversations(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final conversations = snapshot.data ?? [];
                if (conversations.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No messages yet',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Start a conversation using the + button',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final filtered = _applySearch(
                  conversations,
                  searchQuery,
                  memberRef.id,
                );
                if (filtered.isEmpty) {
                  return Center(
                    child: Text(
                      'No matches for "$searchQuery"',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final conv = filtered[index];
                    return _ConversationTile(
                      conversation: conv,
                      currentMemberId: memberRef.id,
                      onTap: () => _openConversation(context, conv),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  void _openConversation(BuildContext context, TextConversation conversation) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TextConversationDetailScreen(
          conversationRef: conversation.ref,
        ),
      ),
    );
  }

  List<TextConversation> _applySearch(
    List<TextConversation> conversations,
    String query,
    String currentMemberId,
  ) {
    final q = query.toLowerCase();
    if (q.isEmpty) return conversations;
    return conversations.where((c) {
      if (c.getDisplayTitle(currentMemberId).toLowerCase().contains(q)) {
        return true;
      }
      for (final name in c.participantNames) {
        if (name.toLowerCase().contains(q)) return true;
      }
      if (c.teamName?.toLowerCase().contains(q) ?? false) return true;
      if (c.lastMessageText?.toLowerCase().contains(q) ?? false) return true;
      return false;
    }).toList();
  }
}

class _ConversationTile extends StatelessWidget {
  final TextConversation conversation;
  final String currentMemberId;
  final VoidCallback onTap;

  const _ConversationTile({
    required this.conversation,
    required this.currentMemberId,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = AppPaletteScope.of(context);
    final title = conversation.getDisplayTitle(currentMemberId);
    final hasUnread = conversation.unreadCount > 0;

    String timeLabel = '';
    if (conversation.lastMessageAt != null) {
      final now = DateTime.now();
      final msgDate = conversation.lastMessageAt!;
      final diff = now.difference(msgDate);

      if (diff.inDays == 0) {
        timeLabel = DateFormat.jm().format(msgDate);
      } else if (diff.inDays == 1) {
        timeLabel = 'Yesterday';
      } else if (diff.inDays < 7) {
        timeLabel = DateFormat.E().format(msgDate);
      } else {
        timeLabel = DateFormat.MMMd().format(msgDate);
      }
    }

    final lastMessage = conversation.lastMessageText == null
        ? null
        : (conversation.lastMessageSenderName != null
            ? '${conversation.lastMessageSenderName}: ${conversation.lastMessageText}'
            : conversation.lastMessageText!);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: StandardBubbleTile(
        title: title,
        description: lastMessage,
        onTap: onTap,
        unread: hasUnread,
        leadingBackgroundColor: palette.primary2.withValues(alpha: 0.1),
        leadingChild: conversation.avatarUrl != null
            ? CircleAvatar(
                radius: 20,
                backgroundImage: NetworkImage(conversation.avatarUrl!),
              )
            : Icon(
                conversation.isExternal
                    ? Icons.sms_outlined
                    : (conversation.isGroup ? Icons.group : Icons.person),
                color: palette.primary2,
              ),
        titleTrailing: timeLabel.isEmpty
            ? null
            : Text(
                timeLabel,
                style: theme.textTheme.bodySmall?.copyWith(
                  color:
                      hasUnread ? palette.primary2 : Colors.grey.shade500,
                ),
              ),
        subtitleTrailing: hasUnread
            ? Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: palette.primary2,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${conversation.unreadCount}',
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            : null,
      ),
    );
  }
}

