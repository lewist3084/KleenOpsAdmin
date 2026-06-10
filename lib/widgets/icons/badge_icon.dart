/// File: lib/widgets/icons/badge_icon.dart
library;
import 'package:flutter/material.dart';

class BadgeIcon extends StatelessWidget {
  /// Diameter of the orbital badges. They keep a fixed *outer* corner (the
  /// `*Offset` values), so enlarging this grows the badge inward — overlapping
  /// the center icon's corners rather than expanding the tile's footprint.
  static const double _badgeSize = 18;

  /// Glyph size inside each orbital badge. Kept close to [_badgeSize] so the
  /// icon fills most of the bubble, leaving only a thin ring of background.
  static const double _badgeGlyphSize = 14;

  /// The base widget (icon, avatar, etc.) to display.
  final Widget child;
  final int? badgeCount;
  final bool showEditBadge;
  final bool showFlagBadge;
  final Color? timerBadgeColor;
  final double topOffset;
  final double rightOffset;
  final double leftOffset;
  final double bottomOffset;

  /// Background color for badges.
  final Color badgeColor;
  final TextStyle? textStyle;

  const BadgeIcon({
    super.key,
    required this.child,
    this.badgeCount,
    this.showEditBadge = false,
    this.showFlagBadge = false,
    this.timerBadgeColor,
    this.topOffset = -2,
    this.rightOffset = -2,
    this.leftOffset = -2,
    this.bottomOffset = -2,
    this.badgeColor = const Color(0xFFE0E0E0),
    this.textStyle,
  });

  @override
  Widget build(BuildContext context) {
    if ((badgeCount == null || badgeCount! <= 0) &&
        !showEditBadge &&
        !showFlagBadge &&
        timerBadgeColor == null) {
      return child;
    }

    final style = textStyle ??
        TextStyle(
          fontSize: 12,
          color: Colors.grey.shade600,
          fontWeight: FontWeight.bold,
        );

    final overlays = <Widget>[];

    // Numeric badge at top-right
    if (badgeCount != null && badgeCount! > 0) {
      overlays.add(
        Positioned(
          top: topOffset,
          right: rightOffset,
          child: Container(
            padding: const EdgeInsets.all(1),
            decoration: BoxDecoration(
              color: badgeColor,
              shape: BoxShape.circle,
            ),
            constraints: const BoxConstraints(
              minWidth: _badgeSize,
              minHeight: _badgeSize,
            ),
            child: Center(child: Text('$badgeCount', style: style)),
          ),
        ),
      );
    }

    // Edit-note badge at top-left
    if (showEditBadge) {
      overlays.add(
        Positioned(
          top: topOffset,
          left: leftOffset,
          child: Container(
            width: _badgeSize,
            height: _badgeSize,
            decoration: BoxDecoration(
              color: badgeColor,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.edit,
                size: _badgeGlyphSize, color: Colors.grey[600]),
          ),
        ),
      );
    }

    // Flag badge  (bottom-right)  ─────────────── NEW
    if (showFlagBadge) {
      overlays.add(
        Positioned(
          bottom: bottomOffset,
          right : rightOffset,
          child : Container(
            width: _badgeSize,
            height: _badgeSize,
            decoration: BoxDecoration(
              color: badgeColor,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.flag_rounded,
                size: _badgeGlyphSize, color: Colors.grey[600]),
          ),
        ),
      );
    }

    // Timer badge (bottom-left)
    if (timerBadgeColor != null) {
      overlays.add(
        Positioned(
          bottom: bottomOffset,
          left: leftOffset,
          child: Container(
            width: _badgeSize,
            height: _badgeSize,
            decoration: BoxDecoration(
              color: badgeColor,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.timer_outlined,
                size: _badgeGlyphSize, color: timerBadgeColor),
          ),
        ),
      );
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        ...overlays,
      ],
    );
  }
}
