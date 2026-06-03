// lib/common/communications/email/widgets/email_thread_tile.dart
// Ported verbatim from the kleenops app (no app-specific dependencies).

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/email_message.dart';
import '../models/email_thread.dart';

/// Collapsible conversation tile rendered as ONE card. Collapsed it shows the
/// most recent message (counterparty name, clean subject, a one-line gist +
/// count chip). Expanded, the per-message AI summaries cascade INSIDE the same
/// card — newest at the top. Tapping a summary row opens that actual email.
class EmailThreadTile extends StatefulWidget {
  const EmailThreadTile({
    super.key,
    required this.thread,
    required this.onOpenEmail,
    this.myAddress,
    this.initiallyExpanded = false,
  });

  final EmailThread thread;
  final void Function(EmailMessage email) onOpenEmail;

  /// The signed-in user's mailbox address — used to label their own messages
  /// as "You" and to pick the counterparty for the collapsed header.
  final String? myAddress;

  final bool initiallyExpanded;

  @override
  State<EmailThreadTile> createState() => _EmailThreadTileState();
}

class _EmailThreadTileState extends State<EmailThreadTile> {
  late bool _expanded = widget.initiallyExpanded;

  bool _isMine(EmailMessage e) {
    if (e.folder == 'Sent') return true;
    final mine = widget.myAddress;
    return mine != null && e.from.toLowerCase() == mine.toLowerCase();
  }

  String _personLabel(EmailMessage e) {
    if (_isMine(e)) return 'You';
    final person = e.emailSenderPerson;
    if (person != null && person.trim().isNotEmpty) return person.trim();
    return e.senderDisplayName;
  }

  String _counterpartyLabel() {
    for (final e in widget.thread.emails) {
      if (!_isMine(e)) return _personLabel(e);
    }
    return 'You';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final thread = widget.thread;
    final latest = thread.latest;
    final counterparty = _counterpartyLabel();
    final avatarSeed =
        thread.emails.firstWhere(_notMineOr(latest), orElse: () => latest).from;
    final showJunk =
        thread.junkConfidence != null && thread.junkConfidence! > 0.5;
    final showAction = thread.hasAction;

    // Attachment de-dup: walk oldest → newest, only flag the message that
    // FIRST introduced a given (non-inline) file.
    final showClip = <String, bool>{};
    final seenKeys = <String>{};
    for (final e in thread.emails.reversed) {
      var hasNew = false;
      for (final a in e.nonInlineAttachments) {
        if (seenKeys.add('${a.fileName}|${a.sizeBytes}')) hasNew = true;
      }
      showClip[e.id] = hasNew;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      child: Material(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Header (the most-recent message at a glance) ──
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: _avatarColor(avatarSeed),
                        child: Text(
                          _initials(counterparty),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    counterparty,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodyLarge?.copyWith(
                                      fontWeight: thread.hasUnread
                                          ? FontWeight.w700
                                          : FontWeight.w600,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _formatDate(latest.receivedAt),
                                  style: TextStyle(
                                    color: theme.colorScheme.onSurface
                                        .withValues(alpha: 0.6),
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                _CountChip(count: thread.count),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              thread.subjectClean,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 3),
                            _summaryText(theme, latest),
                            if (showAction || showJunk) ...[
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  if (showAction)
                                    const _Badge(
                                      icon: Icons.task_alt,
                                      label: 'Action',
                                      color: Colors.blue,
                                    ),
                                  if (showJunk) ...[
                                    if (showAction) const SizedBox(width: 6),
                                    _Badge(
                                      icon: Icons.report,
                                      label:
                                          'Junk ${(thread.junkConfidence! * 100).round()}%',
                                      color: Colors.orange,
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        _expanded ? Icons.expand_less : Icons.expand_more,
                        size: 22,
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ],
                  ),
                ),

                // ── Expanded conversation (newest first, inside the card) ──
                if (_expanded)
                  Container(
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(color: Colors.grey.shade200),
                      ),
                    ),
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (var i = 0; i < thread.emails.length; i++)
                          _ThreadSummaryRow(
                            email: thread.emails[i],
                            label: _personLabel(thread.emails[i]),
                            mine: _isMine(thread.emails[i]),
                            showAttachment:
                                showClip[thread.emails[i].id] ?? false,
                            isLast: i == thread.emails.length - 1,
                            onTap: () => widget.onOpenEmail(thread.emails[i]),
                          ),
                        _ContactsFooter(thread: thread),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  bool Function(EmailMessage) _notMineOr(EmailMessage fallback) =>
      (e) => !_isMine(e);

  Widget _summaryText(ThemeData theme, EmailMessage e) {
    final summary = e.emailSummary;
    if (summary != null && summary.trim().isNotEmpty) {
      return Text(
        summary,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
          fontSize: 12.5,
          height: 1.3,
        ),
      );
    }
    if (e.emailSummaryEngine == 'failed' && e.preview.isNotEmpty) {
      return Text(
        e.preview,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          fontSize: 12.5,
        ),
      );
    }
    return Text(
      'Summarizing…',
      style: TextStyle(
        color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
        fontSize: 12.5,
        fontStyle: FontStyle.italic,
      ),
    );
  }
}

class _ThreadSummaryRow extends StatelessWidget {
  const _ThreadSummaryRow({
    required this.email,
    required this.label,
    required this.mine,
    required this.showAttachment,
    required this.isLast,
    required this.onTap,
  });

  final EmailMessage email;
  final String label;
  final bool mine;
  final bool showAttachment;
  final bool isLast;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final summary = email.emailSummary;
    final hasSummary = summary != null && summary.trim().isNotEmpty;
    final isUnread = !email.isRead && !mine;

    final String body;
    final bool placeholder;
    if (hasSummary) {
      body = summary;
      placeholder = false;
    } else if (email.emailSummaryEngine == 'failed' &&
        email.preview.isNotEmpty) {
      body = email.preview;
      placeholder = false;
    } else {
      body = 'Summarizing…';
      placeholder = true;
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
        decoration: BoxDecoration(
          border: isLast
              ? null
              : Border(bottom: BorderSide(color: Colors.grey.shade200)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  margin: const EdgeInsets.only(right: 6),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isUnread
                        ? theme.colorScheme.primary
                        : Colors.grey.shade400,
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isUnread ? FontWeight.w700 : FontWeight.w600,
                    color: mine
                        ? theme.colorScheme.primary.withValues(alpha: 0.9)
                        : theme.colorScheme.onSurface.withValues(alpha: 0.85),
                  ),
                ),
                const Spacer(),
                Text(
                  _formatDate(email.receivedAt),
                  style: TextStyle(
                    fontSize: 11,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
                if (showAttachment) ...[
                  const SizedBox(width: 4),
                  Icon(Icons.attach_file,
                      size: 13,
                      color:
                          theme.colorScheme.onSurface.withValues(alpha: 0.45)),
                ],
                const SizedBox(width: 2),
                Icon(Icons.chevron_right,
                    size: 16,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.3)),
              ],
            ),
            const SizedBox(height: 3),
            Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Text(
                body,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.3,
                  fontStyle: placeholder ? FontStyle.italic : FontStyle.normal,
                  color: theme.colorScheme.onSurface
                      .withValues(alpha: placeholder ? 0.45 : 0.75),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContactsFooter extends StatelessWidget {
  const _ContactsFooter({required this.thread});

  final EmailThread thread;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final addresses = thread.participantAddresses;
    if (addresses.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 8, left: 2, bottom: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.contacts_outlined,
              size: 14,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.4)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              addresses.join('  ·  '),
              style: TextStyle(
                fontSize: 11,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CountChip extends StatelessWidget {
  const _CountChip({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$count',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.icon, required this.label, required this.color});

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 3),
          Text(label,
              style: TextStyle(
                  fontSize: 10, color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.isEmpty || parts.first.isEmpty) return '?';
  if (parts.length == 1) return parts[0].substring(0, 1).toUpperCase();
  return '${parts[0][0]}${parts.last[0]}'.toUpperCase();
}

Color _avatarColor(String email) {
  const colors = [
    Colors.blue,
    Colors.green,
    Colors.orange,
    Colors.purple,
    Colors.teal,
    Colors.pink,
    Colors.indigo,
    Colors.cyan,
  ];
  return colors[email.hashCode.abs() % colors.length];
}

String _formatDate(DateTime date) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final emailDate = DateTime(date.year, date.month, date.day);

  if (emailDate == today) {
    return DateFormat.jm().format(date);
  } else if (emailDate == today.subtract(const Duration(days: 1))) {
    return 'Yesterday';
  } else if (now.difference(date).inDays < 7) {
    return DateFormat.E().format(date);
  } else if (date.year == now.year) {
    return DateFormat.MMMd().format(date);
  } else {
    return DateFormat.yMMMd().format(date);
  }
}
