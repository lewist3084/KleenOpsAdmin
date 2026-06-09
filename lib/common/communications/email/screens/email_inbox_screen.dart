// lib/common/communications/email/screens/email_inbox_screen.dart
// Ported from the kleenops app to mirror its look & workflow exactly. ADMIN
// ADAPTATIONS are backend-only: navigation via Navigator.push and mailbox routed
// through the company collection; snackbars via ScaffoldMessenger. The AI canvas
// chrome (AiScreenContext + BookendedCanvas) is a no-op stub in admin but keeps
// the identical bookend/home-nav-bar look. The client-side Gemini summarizer
// fallback writes back to the shared `company/{cid}/member/{mid}/email` docs.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/details_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/home_navbar_adapter.dart';
import 'package:kleenops_admin/common/communications/comm_menu.dart';
import 'package:kleenops_admin/services/ai/ai_context_service.dart';
import 'package:kleenops_admin/widgets/ai/ai_screen_context.dart';
import 'package:kleenops_admin/widgets/layout/bookended_canvas.dart';
import 'package:shared_widgets/drawers/menu_drawer.dart';
import 'package:shared_widgets/tabs/lazy_tab_view.dart';
import 'package:shared_widgets/tabs/standard_tab.dart';
import '../models/email_account.dart';
import '../models/email_message.dart';
import '../models/email_thread.dart';
import '../providers/email_providers.dart';
import '../services/gemini_email_analyzer.dart';
import '../widgets/email_thread_tile.dart';
import '../widgets/email_tile.dart';
import 'email_compose_screen.dart';
import 'email_detail_screen.dart';
import 'email_settings_screen.dart';

class EmailInboxScreen extends ConsumerStatefulWidget {
  const EmailInboxScreen({super.key});

  @override
  ConsumerState<EmailInboxScreen> createState() => _EmailInboxScreenState();
}

class _EmailInboxScreenState extends ConsumerState<EmailInboxScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasAccount = ref.watch(hasEmailAccountProvider);
    final controller = ref.read(aiCanvasControllerProvider);
    final currentAccount = ref.watch(currentEmailAccountProvider);

    final menuSections = MenuDrawerSections(
      communications: buildAdminCommunicationMenuItems(context),
      resources: [
        ContentMenuItem(
          icon: Icons.settings,
          label: 'Settings',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const EmailSettingsScreen()),
          ),
        ),
      ],
    );

    return Scaffold(
      body: AiScreenContext(
        context: AiContextPresets.emailInbox(),
        child: BookendedCanvas(
          child: hasAccount
              ? _buildTabbedEmail(currentAccount)
              : _buildNoMailboxState(),
        ),
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DetailsAppBar(
            title: 'All Mailboxes',
            onAiPressed: controller.toggle,
            menuSections: menuSections,
          ),
          const HomeNavBarAdapter(),
        ],
      ),
      floatingActionButton: hasAccount
          ? FloatingActionButton(
              heroTag: 'emailComposeFab',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const EmailComposeScreen()),
              ),
              tooltip: 'Compose',
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Widget _buildTabbedEmail(EmailAccount? account) {
    final unread = ref.watch(inboxUnreadCountProvider);
    final trashCount = ref.watch(trashCountProvider);
    return Column(
      children: [
        StandardTabBar(
          controller: _tabController,
          badgeCounts: [unread, 0, trashCount],
          tabs: const [
            Tab(text: 'Inbox'),
            Tab(text: 'Sent'),
            Tab(text: 'Trash'),
          ],
        ),
        Expanded(
          child: LazyTabView(
            controller: _tabController,
            children: [
              _EmailListTab(
                emailsProvider: inboxEmailsProvider,
                emptyIcon: Icons.inbox_outlined,
                emptyText: 'No messages yet',
                mergeSentReplies: true,
                enableSwipe: true,
              ),
              _EmailListTab(
                emailsProvider: sentEmailsProvider,
                emptyIcon: Icons.outbox_outlined,
                emptyText: 'No sent messages',
              ),
              const _TrashListTab(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNoMailboxState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.email_outlined, size: 80, color: Colors.grey.shade400),
            const SizedBox(height: 24),
            Text(
              'No mailbox assigned',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your signed-in account is not a member of a company with a '
              'mailbox routed to it.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }
}

void _openEmail(BuildContext context, EmailMessage email) {
  Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => EmailDetailScreen(emailId: email.id)),
  );
}

class _EmailListTab extends ConsumerWidget {
  const _EmailListTab({
    required this.emailsProvider,
    required this.emptyIcon,
    required this.emptyText,
    this.mergeSentReplies = false,
    this.enableSwipe = false,
  });

  final StreamProvider<List<EmailMessage>> emailsProvider;
  final IconData emptyIcon;
  final String emptyText;
  final bool mergeSentReplies;
  final bool enableSwipe;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final emails = ref.watch(emailsProvider);
    final service = ref.watch(kleenopsEmailServiceProvider);
    final myAddress =
        ref.watch(currentEmailAccountProvider.select((a) => a?.emailAddress));

    return emails.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (inboxList) {
        final sentList = mergeSentReplies
            ? (ref.watch(sentEmailsProvider).value ?? const [])
            : const <EmailMessage>[];
        final working = mergeSentReplies
            ? ([...inboxList, ...sentList]
              ..sort((a, b) => b.receivedAt.compareTo(a.receivedAt)))
            : inboxList;

        if (working.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(emptyIcon, size: 64, color: Colors.grey.shade400),
                const SizedBox(height: 16),
                Text(emptyText,
                    style:
                        TextStyle(fontSize: 16, color: Colors.grey.shade600)),
              ],
            ),
          );
        }

        // Summarize INBOX/Sent messages lacking a usable summary. Re-runs the
        // ones the old engine left empty (but not hard-'failed' ones, to avoid
        // looping). Never touches trash/junk/archive. This is a fallback for
        // emails the server-side summarizer trigger hasn't stamped yet, and
        // writes back to the shared member/email docs so both apps see results.
        for (final email in working) {
          if (email.folder != 'INBOX' && email.folder != 'Sent') continue;
          final needs =
              (email.emailSummary == null || email.emailSummary!.isEmpty) &&
                  email.emailSummaryEngine != 'failed';
          if (needs && email.ref != null) {
            GeminiEmailAnalyzer.instance.analyzeAndPersist(
              emailRef: email.ref!,
              subject: email.subject,
              from: email.from,
              snippet: email.preview,
              body: email.bodyPlain.isNotEmpty ? email.bodyPlain : null,
              isSent: email.folder == 'Sent',
            );
          }
        }

        // Collapse "Re: Re: Re:" chains into one expandable conversation tile.
        final allThreads = groupEmailThreads(working);
        final threads = mergeSentReplies
            ? allThreads
                .where((t) => t.emails.any((e) => e.folder == 'INBOX'))
                .toList()
            : allThreads;

        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: threads.length,
          itemBuilder: (context, index) {
            final thread = threads[index];
            final Widget tile;
            if (!thread.isSingle) {
              tile = EmailThreadTile(
                thread: thread,
                myAddress: myAddress,
                onOpenEmail: (email) => _openEmail(context, email),
              );
            } else {
              final email = thread.latest;
              tile = EmailTile(
                email: email,
                onTap: () => _openEmail(context, email),
                onStarTap: () async {
                  if (email.ref == null) return;
                  final messenger = ScaffoldMessenger.of(context);
                  try {
                    await service.toggleStar(email.ref!, !email.isStarred);
                  } catch (e) {
                    messenger.showSnackBar(
                      SnackBar(content: Text('Failed to update star: $e')),
                    );
                  }
                },
              );
            }

            if (!enableSwipe) return tile;
            final inboxEmails = thread.emails
                .where((e) => e.folder == 'INBOX' && e.ref != null)
                .toList();
            final inboxRefs = inboxEmails.map((e) => e.ref!).toList();
            if (inboxRefs.isEmpty) return tile;

            return Dismissible(
              key: ValueKey('inbox_${thread.key}'),
              background: _swipeBg(
                color: Colors.red,
                icon: Icons.delete,
                label: 'Trash',
                alignLeft: true,
              ),
              secondaryBackground: _swipeBg(
                color: Colors.teal,
                icon: Icons.archive_outlined,
                label: 'Archive',
                alignLeft: false,
              ),
              confirmDismiss: (direction) async {
                final messenger = ScaffoldMessenger.of(context);
                if (direction == DismissDirection.startToEnd) {
                  for (final r in inboxRefs) {
                    await service.moveToTrash(r);
                  }
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(inboxRefs.length > 1
                          ? '${inboxRefs.length} moved to Trash'
                          : 'Moved to Trash'),
                      action: SnackBarAction(
                        label: 'Undo',
                        onPressed: () async {
                          for (final r in inboxRefs) {
                            await service.restoreToInbox(r);
                          }
                        },
                      ),
                    ),
                  );
                } else {
                  for (final r in inboxRefs) {
                    await service.archive(r);
                  }
                  messenger.showSnackBar(
                    SnackBar(
                      content: const Text('Archived'),
                      action: SnackBarAction(
                        label: 'Undo',
                        onPressed: () async {
                          for (final r in inboxRefs) {
                            await service.restoreToInbox(r);
                          }
                        },
                      ),
                    ),
                  );
                }
                return true;
              },
              child: tile,
            );
          },
        );
      },
    );
  }
}

/// Shared full-bleed swipe background for the email list rows.
Widget _swipeBg({
  required Color color,
  required IconData icon,
  required String label,
  required bool alignLeft,
}) {
  final children = [
    Icon(icon, color: Colors.white),
    const SizedBox(width: 8),
    Text(label,
        style:
            const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
  ];
  return Container(
    color: color,
    alignment: alignLeft ? Alignment.centerLeft : Alignment.centerRight,
    padding: const EdgeInsets.symmetric(horizontal: 20),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: alignLeft ? children : children.reversed.toList(),
    ),
  );
}

/// Trash review surface: lists trashed + AI-junked emails individually so each
/// can be triaged. Swipe right to delete (with a 5s undo), swipe left to
/// restore; tap to read.
class _TrashListTab extends ConsumerWidget {
  const _TrashListTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final emails = ref.watch(trashEmailsProvider);
    final service = ref.watch(kleenopsEmailServiceProvider);

    return emails.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (emailList) {
        if (emailList.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.delete_outline,
                    size: 64, color: Colors.grey.shade400),
                const SizedBox(height: 16),
                Text('Trash is empty',
                    style:
                        TextStyle(fontSize: 16, color: Colors.grey.shade600)),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: emailList.length,
          itemBuilder: (context, index) {
            final email = emailList[index];
            final tile = EmailTile(
              email: email,
              onTap: () => _openEmail(context, email),
            );
            if (email.ref == null) return tile;
            return Dismissible(
              key: ValueKey('trash_${email.id}'),
              background: _swipeBg(
                color: Colors.red,
                icon: Icons.delete_forever,
                label: 'Delete',
                alignLeft: true,
              ),
              secondaryBackground: _swipeBg(
                color: Colors.green,
                icon: Icons.restore,
                label: 'Restore',
                alignLeft: false,
              ),
              confirmDismiss: (direction) async {
                final messenger = ScaffoldMessenger.of(context);
                if (direction == DismissDirection.startToEnd) {
                  final restoreData = {
                    ...email.toMap(),
                    'folder': 'Trash',
                    'isDeleted': true,
                  };
                  final eref = email.ref!;
                  await service.deleteForever(eref);
                  messenger.showSnackBar(
                    SnackBar(
                      content: const Text('Deleted'),
                      action: SnackBarAction(
                        label: 'Undo',
                        onPressed: () => eref.set(restoreData),
                      ),
                    ),
                  );
                } else {
                  await service.restoreToInbox(email.ref!);
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Restored to Inbox')),
                  );
                }
                return true;
              },
              child: tile,
            );
          },
        );
      },
    );
  }
}
