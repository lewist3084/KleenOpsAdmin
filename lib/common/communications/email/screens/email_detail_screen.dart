// lib/common/communications/email/screens/email_detail_screen.dart
// Ported from the kleenops app to mirror its look & workflow exactly. ADMIN
// ADAPTATIONS are backend-only: navigation via Navigator.push; snackbars via
// ScaffoldMessenger. The AI canvas chrome (AiScreenContext + BookendedCanvas) is
// a no-op stub in admin but keeps the identical bookend/home-nav-bar look.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:intl/intl.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/details_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/home_navbar_adapter.dart';
import 'package:kleenops_admin/services/ai/ai_context_service.dart';
import 'package:kleenops_admin/widgets/ai/ai_screen_context.dart';
import 'package:kleenops_admin/widgets/layout/bookended_canvas.dart';
import 'package:shared_widgets/dialogs/dialog_action.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/email_attachment.dart';
import '../models/email_message.dart';
import '../models/email_thread.dart';
import '../providers/email_providers.dart';
import '../widgets/email_attachment_chip.dart';
import '../widgets/email_control_strip.dart';
import 'email_compose_screen.dart';

class EmailDetailScreen extends ConsumerStatefulWidget {
  final String emailId;

  const EmailDetailScreen({super.key, required this.emailId});

  @override
  ConsumerState<EmailDetailScreen> createState() => _EmailDetailScreenState();
}

class _EmailDetailScreenState extends ConsumerState<EmailDetailScreen> {
  /// Message ids currently expanded in the conversation. The opened email
  /// starts expanded; the rest are rolled up under tap-to-expand bars.
  late final Set<String> _expandedIds = {widget.emailId};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _markAsRead();
    });
  }

  Future<void> _markAsRead() async {
    try {
      final email = await ref.read(emailByIdProvider(widget.emailId).future);
      if (!mounted) return;
      if (email == null || email.isRead || email.ref == null) return;
      await ref.read(kleenopsEmailServiceProvider).markAsRead(email.ref!);
    } catch (_) {
      // Silently fail
    }
  }

  @override
  Widget build(BuildContext context) {
    final emailAsync = ref.watch(emailByIdProvider(widget.emailId));
    final convo = ref.watch(conversationEmailsProvider(widget.emailId)).value ??
        const <EmailMessage>[];
    final myAddress =
        ref.watch(currentEmailAccountProvider.select((a) => a?.emailAddress));
    final canvasController = ref.read(aiCanvasControllerProvider);
    final email = emailAsync.value;

    return Scaffold(
      body: AiScreenContext(
        context: AiContextPresets.emailDetail(
          emailId: widget.emailId,
          label: email?.subject,
        ),
        child: BookendedCanvas(
          child: emailAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (email) {
              if (email == null) {
                return const Center(child: Text('Email not found'));
              }
              final messages = convo.isEmpty ? <EmailMessage>[email] : convo;
              return _buildConversation(messages, email, myAddress);
            },
          ),
        ),
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (email != null)
            EmailControlStrip(
              isStarred: email.isStarred,
              onDelete: () => _deleteEmail(context),
              onReply: () => _reply(email),
              onReplyAll: () => _replyAll(email),
              onForward: () => _forward(email),
              onStar: () => _toggleStar(email),
            ),
          DetailsAppBar(
            title: 'Email',
            onAiPressed: canvasController.toggle,
          ),
          const HomeNavBarAdapter(),
        ],
      ),
    );
  }

  bool _isMine(EmailMessage e, String? myAddress) {
    if (e.folder == 'Sent') return true;
    return myAddress != null && e.from.toLowerCase() == myAddress.toLowerCase();
  }

  String _label(EmailMessage e, String? myAddress) {
    if (_isMine(e, myAddress)) return 'You';
    final person = e.emailSenderPerson;
    if (person != null && person.trim().isNotEmpty) return person.trim();
    return e.senderDisplayName;
  }

  Widget _buildConversation(
    List<EmailMessage> messages,
    EmailMessage opened,
    String? myAddress,
  ) {
    final theme = Theme.of(context);
    final multi = messages.length > 1;
    return SelectionArea(
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Text(
                stripSubjectPrefixes(opened.subject),
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            if (multi)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(
                  '${messages.length} messages',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: Colors.grey.shade600),
                ),
              ),
            Divider(height: 1, thickness: 1, color: Colors.grey.shade300),
            for (final e in messages)
              _expandedIds.contains(e.id)
                  ? _buildExpandedMessage(e, myAddress, collapsible: multi)
                  : _buildCollapsedMessage(e, myAddress),
          ],
        ),
      ),
    );
  }

  Widget _buildCollapsedMessage(EmailMessage e, String? myAddress) {
    final theme = Theme.of(context);
    final summary = e.emailSummary;
    final gist = (summary != null && summary.trim().isNotEmpty)
        ? summary
        : e.preview;
    return InkWell(
      onTap: () => setState(() => _expandedIds.add(e.id)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _label(e, myAddress),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight:
                                e.isRead ? FontWeight.w500 : FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        DateFormat.MMMd().add_jm().format(e.receivedAt),
                        style: TextStyle(
                          fontSize: 11,
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    gist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      color:
                          theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            if (e.nonInlineAttachments.isNotEmpty)
              Icon(Icons.attach_file,
                  size: 14,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.4)),
            Icon(Icons.expand_more,
                size: 22,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
          ],
        ),
      ),
    );
  }

  Widget _buildExpandedMessage(
    EmailMessage e,
    String? myAddress, {
    required bool collapsible,
  }) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: collapsible
                ? () => setState(() => _expandedIds.remove(e.id))
                : null,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _label(e, myAddress),
                          style: theme.textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      Text(
                        '${DateFormat.yMMMd().format(e.receivedAt)} · ${DateFormat.jm().format(e.receivedAt)}',
                        style: TextStyle(
                          fontSize: 11,
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.55),
                        ),
                      ),
                      if (collapsible)
                        Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: Icon(Icons.expand_less,
                              size: 22,
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.5)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  _buildRecipientRow('From', [e.from]),
                  _buildRecipientRow('To', e.to),
                  if (e.cc.isNotEmpty) _buildRecipientRow('Cc', e.cc),
                ],
              ),
            ),
          ),
          if (e.nonInlineAttachments.isNotEmpty) _buildAttachments(e),
          Padding(
            padding: const EdgeInsets.all(16),
            child: e.bodyHtml.isNotEmpty
                ? HtmlWidget(
                    e.bodyHtml,
                    textStyle: const TextStyle(fontSize: 14),
                    onTapUrl: _openExternalUrl,
                  )
                : Text(
                    e.bodyPlain,
                    style: const TextStyle(fontSize: 14),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecipientRow(String label, List<String> recipients) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 60,
            child: Text(
              '$label:',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.6),
              ),
            ),
          ),
          Expanded(
            child: Text(
              recipients.join(', '),
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttachments(EmailMessage email) {
    return Container(
      padding: const EdgeInsets.all(12),
      color: Colors.grey.shade100,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${email.nonInlineAttachments.length} Attachment${email.nonInlineAttachments.length > 1 ? 's' : ''}',
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: email.nonInlineAttachments
                .map((a) => EmailAttachmentChip(
                      attachment: a,
                      onTap: () => _openAttachment(a),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }

  void _reply(EmailMessage email) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => EmailComposeScreen(replyToId: email.id),
    ));
  }

  void _replyAll(EmailMessage email) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => EmailComposeScreen(replyToId: email.id, replyAll: true),
    ));
  }

  void _forward(EmailMessage email) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => EmailComposeScreen(forwardId: email.id),
    ));
  }

  Future<void> _toggleStar(EmailMessage email) async {
    if (email.ref == null) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(kleenopsEmailServiceProvider)
          .toggleStar(email.ref!, !email.isStarred);
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
            duration: const Duration(seconds: 5),
            content: Text('Failed to update star: $e')),
      );
    }
  }

  Future<bool> _openExternalUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }

  Future<void> _openAttachment(EmailAttachment attachment) async {
    final messenger = ScaffoldMessenger.of(context);
    final url = attachment.url;
    if (url == null || url.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(
          duration: Duration(seconds: 4),
          content: Text("This attachment isn't available to download."),
        ),
      );
      return;
    }
    final opened = await _openExternalUrl(url);
    if (!opened) {
      messenger.showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 4),
          content: Text('Could not open ${attachment.fileName}.'),
        ),
      );
    }
  }

  Future<void> _deleteEmail(BuildContext context) async {
    final email = ref.read(emailByIdProvider(widget.emailId)).value;
    if (email == null || email.ref == null) return;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => DialogAction(
        title: 'Delete Email',
        content: const Text('Are you sure you want to delete this email?'),
        cancelText: 'Cancel',
        onCancel: () => Navigator.of(ctx).pop(false),
        actionText: 'Delete',
        onAction: () => Navigator.of(ctx).pop(true),
        actionButtonColor: Colors.red[600],
        buttonTextColor: Colors.white,
      ),
    );

    if (confirmed != true) return;

    try {
      await ref.read(kleenopsEmailServiceProvider).moveToTrash(email.ref!);
      if (mounted) navigator.pop();
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
            duration: const Duration(seconds: 5),
            content: Text('Failed to delete email: $e')),
      );
    }
  }
}
