import 'package:flutter/material.dart';

class TextValueInlineCheckbox extends StatelessWidget {
  final String header;
  final bool value;
  final IconData icon;
  final VoidCallback? onInfoPressed;
  final Color? color;
  final bool boldHeader;

  const TextValueInlineCheckbox({
    super.key,
    required this.header,
    required this.value,
    required this.icon,
    this.onInfoPressed,
    this.color,
    this.boldHeader = true,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? Theme.of(context).primaryColor;
    final baseLabelStyle =
        Theme.of(context).textTheme.titleSmall?.copyWith(fontSize: 16) ??
            const TextStyle(fontSize: 16);
    final labelStyle = boldHeader
        ? baseLabelStyle.copyWith(fontWeight: FontWeight.w500)
        : baseLabelStyle.copyWith(fontWeight: FontWeight.normal);

    Widget infoIcon = Icon(Icons.info, size: 16, color: effectiveColor);
    if (onInfoPressed != null) {
      infoIcon = GestureDetector(onTap: onInfoPressed, child: infoIcon);
    }

    final checkboxColor =
        value ? effectiveColor : Theme.of(context).disabledColor;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(header, style: labelStyle),
        const SizedBox(width: 8),
        infoIcon,
        const Spacer(),
        Icon(icon, size: 20, color: effectiveColor),
        const SizedBox(width: 8),
        Icon(
          value ? Icons.check_box : Icons.check_box_outline_blank,
          color: checkboxColor,
        ),
      ],
    );
  }
}
