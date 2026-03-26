import 'package:flutter/material.dart';

/// A simple checkbox row with an optional leading icon and text.
class IconTextCheckbox extends StatelessWidget {
  final IconData? leadingIcon;
  final String text;
  final bool value;
  final ValueChanged<bool?> onChanged;
  final Color? activeColor;

  const IconTextCheckbox({
    super.key,
    this.leadingIcon,
    required this.text,
    required this.value,
    required this.onChanged,
    this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    final color = activeColor ?? Theme.of(context).primaryColor;
    return SizedBox(
      height: 34,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              if (leadingIcon != null) ...[
                Icon(leadingIcon, size: 16, color: color),
                const SizedBox(width: 8),
              ],
              Text(
                text,
                style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontSize: 16) ??
                    const TextStyle(fontSize: 16),
              ),
            ],
          ),
          Checkbox(
            value: value,
            onChanged: onChanged,
            activeColor: color,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ),
    );
  }
}
