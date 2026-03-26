// widgets/tiles/icon_text_icon_text.dart

import 'package:flutter/material.dart';

/// A tile showing an icon and text on the left,
/// and an icon and text on the right, with minimal spacing around icons,
/// default right padding, and optional vertical padding.
class IconTextIconTextTile extends StatelessWidget {
  // Left side
  final IconData? leftIcon;
  final VoidCallback? leftIconAction;
  final String leftText;
  final double? leftTextSize;
  final Color? leftTextColor;
  final Color? leftIconColor;

  // Right side
  final IconData? rightIcon;
  final VoidCallback? rightIconAction;
  final String rightText;
  final double? rightTextSize;
  final Color? rightTextColor;
  final Color? rightIconColor;

  /// Optional action icon displayed at the far right.
  final IconData? actionIcon;

  /// Callback when the action icon is tapped.
  final VoidCallback? actionIconAction;

  // Styling
  /// General override padding. If provided, this is used.
  final EdgeInsetsGeometry? padding;
  /// Vertical padding around content, defaults to 0.0.
  final double verticalPadding;
  /// Background color of the tile
  final Color? backgroundColor;

  /// If true, reduces spacing between the left and right sections
  /// and constrains the left text to a small width suitable for a
  /// few characters. Useful when the left text is numeric and short.
  final bool compact;

  const IconTextIconTextTile({
    super.key,
    // left
    this.leftIcon,
    this.leftIconAction,
    required this.leftText,
    this.leftTextSize,
    this.leftTextColor,
    this.leftIconColor,
    // right
    this.rightIcon,
    this.rightIconAction,
    required this.rightText,
    this.rightTextSize,
    this.rightTextColor,
    this.rightIconColor,
    this.actionIcon,
    this.actionIconAction,
    // styling
    this.padding,
    this.verticalPadding = 4.0,
    this.backgroundColor,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    const double leftSpacing = 0.0;
    const double rightSpacing = 8.0;

    // Determine padding: use override if provided, otherwise apply vertical + default right
    final effectivePadding = padding ??
        EdgeInsets.only(
          top: verticalPadding,
          bottom: verticalPadding,
          right: rightSpacing,
        );

    if (compact) {
      return Container(
        color: backgroundColor ?? Colors.white,
        padding: effectivePadding,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (leftIcon != null) ...[
              GestureDetector(
                onTap: leftIconAction,
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Icon(
                    leftIcon,
                    size: 16.0,
                    color: leftIconColor ?? Theme.of(context).primaryColor,
                  ),
                ),
              ),
              SizedBox(width: leftSpacing),
            ],
            SizedBox(
              width: 40.0,
              child: Text(
                leftText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: leftTextSize ?? 14.0,
                  color: leftTextColor ?? Colors.black,
                ),
              ),
            ),
            const SizedBox(width: rightSpacing),
            if (rightIcon != null) ...[
              GestureDetector(
                onTap: rightIconAction,
                child: Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: Icon(
                    rightIcon,
                    size: 16.0,
                    color: rightIconColor ?? Theme.of(context).primaryColor,
                  ),
                ),
              ),
              SizedBox(width: rightSpacing),
            ],
            Flexible(
              child: Text(
                rightText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: rightTextSize ?? 14.0,
                  color: rightTextColor ?? Colors.black,
                ),
              ),
            ),
            SizedBox(width: rightSpacing),
            if (actionIcon != null)
              GestureDetector(
                onTap: actionIconAction,
                child: Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: Icon(
                    actionIcon,
                    size: 16.0,
                    color: rightIconColor ?? Theme.of(context).primaryColor,
                  ),
                ),
              ),
          ],
        ),
      );
    }

    return Container(
      color: backgroundColor ?? Colors.white,
      padding: effectivePadding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Flexible(
            fit: FlexFit.loose,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (leftIcon != null) ...[
                  GestureDetector(
                    onTap: leftIconAction,
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Icon(
                        leftIcon,
                        size: 16.0,
                        color: leftIconColor ?? Theme.of(context).primaryColor,
                      ),
                    ),
                  ),
                  SizedBox(width: leftSpacing),
                ],
                Flexible(
                  child: Text(
                    leftText,
                    style: TextStyle(
                      fontSize: leftTextSize ?? 14.0,
                      color: leftTextColor ?? Colors.black,
                    ),
                    softWrap: true,
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (rightIcon != null) ...[
                  GestureDetector(
                    onTap: rightIconAction,
                    child: Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: Icon(
                      rightIcon,
                      size: 16.0,
                      color: rightIconColor ?? Theme.of(context).primaryColor,
                    ),
                  ),
                ),
                SizedBox(width: rightSpacing),
              ],
                Flexible(
                  child: Text(
                    rightText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: rightTextSize ?? 14.0,
                      color: rightTextColor ?? Colors.black,
                    ),
                  ),
                ),
                const Spacer(),
                if (actionIcon != null)
                  GestureDetector(
                    onTap: actionIconAction,
                    child: Padding(
                      padding: const EdgeInsets.all(4.0),
                      child: Icon(
                        actionIcon,
                        size: 16.0,
                        color: rightIconColor ?? Theme.of(context).primaryColor,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
