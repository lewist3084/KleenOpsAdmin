// lib/common/communications/email/widgets/email_attachment_chip.dart
// Ported from the kleenops app.

import 'package:flutter/material.dart';
import '../models/email_attachment.dart';

/// A chip widget for displaying an email attachment.
class EmailAttachmentChip extends StatelessWidget {
  final EmailAttachment attachment;
  final VoidCallback? onTap;

  const EmailAttachmentChip({
    super.key,
    required this.attachment,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _getIconForType(attachment.type),
                size: 18,
                color: _getColorForType(attachment.type),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 150),
                    child: Text(
                      attachment.fileName,
                      style: const TextStyle(fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (attachment.sizeBytes != null)
                    Text(
                      attachment.humanReadableSize,
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade600,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getIconForType(EmailAttachmentType type) {
    switch (type) {
      case EmailAttachmentType.image:
        return Icons.image_outlined;
      case EmailAttachmentType.video:
        return Icons.videocam_outlined;
      case EmailAttachmentType.audio:
        return Icons.audiotrack_outlined;
      case EmailAttachmentType.document:
        return Icons.description_outlined;
      case EmailAttachmentType.other:
        return Icons.attach_file;
    }
  }

  Color _getColorForType(EmailAttachmentType type) {
    switch (type) {
      case EmailAttachmentType.image:
        return Colors.green;
      case EmailAttachmentType.video:
        return Colors.red;
      case EmailAttachmentType.audio:
        return Colors.purple;
      case EmailAttachmentType.document:
        return Colors.blue;
      case EmailAttachmentType.other:
        return Colors.grey;
    }
  }
}
