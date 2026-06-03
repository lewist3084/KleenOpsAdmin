// lib/common/communications/email/widgets/compose_email_control_strip.dart
// Ported from the kleenops app.
// Layout: [X] | (📎  To  Cc  Bcc) centered | [Send].

import 'package:flutter/material.dart';
import 'package:shared_widgets/theme/app_palette.dart';

import '../screens/email_recipient_picker_screen.dart';

class ComposeEmailControlStrip extends StatelessWidget {
  const ComposeEmailControlStrip({
    super.key,
    required this.onTapField,
    required this.onClose,
    required this.onAttach,
    required this.onSend,
    this.isSending = false,
  });

  final ValueChanged<EmailRecipientField> onTapField;
  final VoidCallback onClose;
  final VoidCallback onAttach;
  final VoidCallback onSend;
  final bool isSending;

  static const double kStripHeight = 44.0;

  @override
  Widget build(BuildContext context) {
    final palette = AppPaletteScope.of(context);
    final accent = palette.primary2;

    return Container(
      height: kStripHeight,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Colors.grey.shade300, width: 1),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          _IconAction(
            icon: Icons.close,
            tooltip: 'Discard',
            color: accent,
            onTap: onClose,
          ),
          const _StripDivider(),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _IconAction(
                  icon: Icons.attach_file,
                  tooltip: 'Attach file',
                  color: accent,
                  onTap: onAttach,
                ),
                const SizedBox(width: 4),
                _RecipientButton(
                  label: 'To',
                  color: accent,
                  onTap: () => onTapField(EmailRecipientField.to),
                ),
                const SizedBox(width: 4),
                _RecipientButton(
                  label: 'Cc',
                  color: accent,
                  onTap: () => onTapField(EmailRecipientField.cc),
                ),
                const SizedBox(width: 4),
                _RecipientButton(
                  label: 'Bcc',
                  color: accent,
                  onTap: () => onTapField(EmailRecipientField.bcc),
                ),
              ],
            ),
          ),
          const _StripDivider(),
          _IconAction(
            icon: Icons.send,
            tooltip: 'Send',
            color: accent,
            onTap: isSending ? null : onSend,
            child: isSending
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : null,
          ),
        ],
      ),
    );
  }
}

class _StripDivider extends StatelessWidget {
  const _StripDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: VerticalDivider(
        width: 1,
        thickness: 1,
        color: Colors.grey.shade300,
        indent: 6,
        endIndent: 6,
      ),
    );
  }
}

class _RecipientButton extends StatelessWidget {
  const _RecipientButton({
    required this.label,
    required this.color,
    required this.onTap,
  });

  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(4),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _IconAction extends StatelessWidget {
  const _IconAction({
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.onTap,
    this.child,
  });

  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback? onTap;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return SizedBox(
      width: 36,
      height: 32,
      child: IconButton(
        padding: EdgeInsets.zero,
        iconSize: 22,
        splashRadius: 18,
        tooltip: tooltip,
        onPressed: onTap,
        icon: child ??
            Icon(icon, color: enabled ? color : Colors.grey.shade400),
      ),
    );
  }
}
