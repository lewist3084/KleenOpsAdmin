// lib/common/communications/email/widgets/email_tile.dart
// Ported from the kleenops app.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_widgets/tiles/standard_bubble_tile.dart';
import '../models/email_message.dart';

/// A tile widget for displaying an email in a list. Thin wrapper over
/// [StandardBubbleTile] that maps email-specific fields (sender avatar,
/// AI summary, star/attachment trailing column, action/junk badges).
class EmailTile extends StatelessWidget {
  final EmailMessage email;
  final VoidCallback onTap;
  final VoidCallback? onStarTap;

  const EmailTile({
    super.key,
    required this.email,
    required this.onTap,
    this.onStarTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isUnread = !email.isRead;
    final showJunk =
        email.junkConfidence != null && email.junkConfidence! > 0.5;
    final showAction = email.emailHasActionItem;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: StandardBubbleTile(
        title: email.senderDisplayName,
        description: email.subject,
        onTap: onTap,
        unread: isUnread,
        leadingBackgroundColor: _getAvatarColor(email.from),
        leadingChild: Text(
          _getInitials(email.senderDisplayName),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        titleTrailing: Text(
          _formatDate(email.receivedAt),
          style: TextStyle(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            fontSize: 12,
          ),
        ),
        metaWidget: _buildSummaryLine(theme),
        extraSubtitleRows: (showAction || showJunk)
            ? [
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
                            'Junk ${(email.junkConfidence! * 100).round()}%',
                        color: Colors.orange,
                      ),
                    ],
                  ],
                ),
              ]
            : null,
        trailing: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(
                email.isStarred ? Icons.star : Icons.star_border,
                color: email.isStarred
                    ? Colors.amber
                    : theme.colorScheme.onSurface.withValues(alpha: 0.4),
                size: 20,
              ),
              onPressed: onStarTap,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
            if (email.hasAttachments)
              Icon(
                Icons.attach_file,
                size: 16,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryLine(ThemeData theme) {
    final summary = email.displaySummary;
    if (summary == null) {
      return Text(
        'Generating summary…',
        style: TextStyle(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
          fontSize: 12,
          fontStyle: FontStyle.italic,
        ),
      );
    }
    final isAi = email.emailSummary != null && email.emailSummary!.isNotEmpty;
    return Text(
      summary,
      style: TextStyle(
        color: theme.colorScheme.onSurface.withValues(alpha: isAi ? 0.7 : 0.6),
        fontSize: 12,
        fontStyle: isAi ? FontStyle.italic : FontStyle.normal,
      ),
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
    );
  }

  String _getInitials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      return parts[0].substring(0, 1).toUpperCase();
    }
    return '${parts[0][0]}${parts.last[0]}'.toUpperCase();
  }

  Color _getAvatarColor(String email) {
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.pink,
      Colors.indigo,
      Colors.cyan,
    ];
    final index = email.hashCode.abs() % colors.length;
    return colors[index];
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
}

class _Badge extends StatelessWidget {
  const _Badge({
    required this.icon,
    required this.label,
    required this.color,
  });

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
          Text(
            label,
            style: TextStyle(
                fontSize: 10, color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
