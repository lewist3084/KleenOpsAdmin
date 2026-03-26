// lib/widgets/fields/text_value_inline.dart
// – rev 2025-07-02 – adds optional trailing icon + action

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TextValueInline extends StatelessWidget {
  final String header;
  final dynamic value;
  final IconData icon;
  final VoidCallback? onInfoPressed;
  final Color? color;

  /// Optional trailing action (e.g., calculator icon)
  final IconData? trailingIcon;
  final VoidCallback? onTrailingPressed;
  final bool boldValue;
  final bool boldHeader;

  const TextValueInline({
    super.key,
    required this.header,
    required this.value,
    required this.icon,
    this.onInfoPressed,
    this.color,
    this.trailingIcon,
    this.onTrailingPressed,
    this.boldValue = false,
    this.boldHeader = true,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? Theme.of(context).primaryColor;
    final baseLabelStyle = Theme.of(context)
            .textTheme
            .titleSmall
            ?.copyWith(fontSize: 16) ??
        const TextStyle(fontSize: 16);
    final labelStyle = boldHeader
        ? baseLabelStyle.copyWith(fontWeight: FontWeight.w500)
        : baseLabelStyle.copyWith(fontWeight: FontWeight.normal);
    final baseValueStyle =
        Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 16) ??
            const TextStyle(fontSize: 16);
    final valueStyle = boldValue
        ? baseValueStyle.copyWith(fontWeight: FontWeight.bold)
        : baseValueStyle;

    // Info icon (constant)
    Widget infoIcon = Icon(Icons.info, size: 16, color: effectiveColor);
    if (onInfoPressed != null) {
      infoIcon = GestureDetector(onTap: onInfoPressed, child: infoIcon);
    }

    // Determine display string
    String displayValue;
    if (value is Timestamp) {
      displayValue = DateFormat.jm().format((value as Timestamp).toDate());
    } else if (value is DateTime) {
      displayValue = DateFormat.jm().format(value as DateTime);
    } else if (value is List) {
      displayValue = (value as List).map((e) => e.toString()).join(', ');
    } else {
      displayValue = value?.toString() ?? '';
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(header, style: labelStyle),
        const SizedBox(width: 8),
        infoIcon,
        const Spacer(),
        Icon(icon, size: 20, color: effectiveColor),
        const SizedBox(width: 8),
        Text(displayValue, style: valueStyle),
        if (trailingIcon != null) ...[
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onTrailingPressed,
            child: Icon(trailingIcon, size: 20, color: effectiveColor),
          ),
        ],
      ],
    );
  }
}
