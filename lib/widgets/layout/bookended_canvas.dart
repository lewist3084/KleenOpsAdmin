import 'package:flutter/material.dart';
import 'package:shared_widgets/containers/canvas_top_bookend.dart';
import 'package:shared_widgets/containers/standard_canvas.dart';
import 'package:shared_widgets/layout/content_width_clamp.dart';

class BookendedCanvas extends StatelessWidget {
  const BookendedCanvas({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
    this.backgroundColor = Colors.white,
    this.clampContentWidth = true,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color backgroundColor;

  /// Caps body width on wide layouts (see [ContentWidthClamp]). The bookend
  /// divider stays full-width; only the scrollable content is centred. Set
  /// false for full-bleed screens (maps, video call, AR, screen share).
  final bool clampContentWidth;

  @override
  Widget build(BuildContext context) {
    return StandardCanvas(
      backgroundColor: backgroundColor,
      padding: padding,
      child: SafeArea(
        top: true,
        bottom: false,
        child: Column(
          children: [
            const CanvasTopBookend(),
            Expanded(
              child: ContentWidthClamp(
                enabled: clampContentWidth,
                child: child,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
