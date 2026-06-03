// lib/common/communications/email/widgets/email_control_strip.dart
// Ported from the kleenops app. Thin adapter over the shared
// [ControlStripBottom]: delete = left endpoint, reply/reply-all/forward =
// centre, star = right endpoint.

import 'package:flutter/material.dart';
import 'package:shared_widgets/buttons/control_strip_bottom.dart';

class EmailControlStrip extends StatelessWidget {
  const EmailControlStrip({
    super.key,
    required this.isStarred,
    required this.onDelete,
    required this.onReply,
    required this.onReplyAll,
    required this.onForward,
    required this.onStar,
  });

  final bool isStarred;
  final VoidCallback onDelete;
  final VoidCallback onReply;
  final VoidCallback onReplyAll;
  final VoidCallback onForward;
  final VoidCallback onStar;

  @override
  Widget build(BuildContext context) {
    return ControlStripBottom(
      leftAction: ControlStripAction(
        icon: Icons.delete,
        tooltip: 'Delete',
        onTap: onDelete,
      ),
      centerActions: [
        ControlStripAction(
          icon: Icons.reply,
          tooltip: 'Reply',
          onTap: onReply,
        ),
        ControlStripAction(
          icon: Icons.reply_all,
          tooltip: 'Reply All',
          onTap: onReplyAll,
        ),
        ControlStripAction(
          icon: Icons.forward,
          tooltip: 'Forward',
          onTap: onForward,
        ),
      ],
      rightAction: ControlStripAction(
        icon: Icons.star,
        tooltip: 'Star',
        iconColor: isStarred ? Colors.amber : null,
        onTap: onStar,
      ),
    );
  }
}
