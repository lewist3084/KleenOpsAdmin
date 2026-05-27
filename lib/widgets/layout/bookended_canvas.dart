import 'package:flutter/material.dart';
import 'package:shared_widgets/containers/canvas_top_bookend.dart';
import 'package:shared_widgets/containers/standard_canvas.dart';

class BookendedCanvas extends StatelessWidget {
  const BookendedCanvas({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
    this.backgroundColor = Colors.white,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color backgroundColor;

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
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}
