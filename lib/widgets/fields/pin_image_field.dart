//  pin_image_field.dart

import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';

class PinImageOverlay {
  final Rect normalizedBounds;
  final Uint8List bytes;

  const PinImageOverlay({
    required this.normalizedBounds,
    required this.bytes,
  });
}

class PinImageField extends StatefulWidget {
  final String imageUrl;
  final double? imageWidth;
  final double? imageHeight;

  /// Normalized coordinates (0..1) for the pin.
  final double initialX;
  final double initialY;

  /// Callback to notify the parent of pin's new (normalized) x/y.
  final Function(double newX, double newY) onPinChanged;
  final bool showCoordinates;
  final List<PinImageOverlay> overlays;

  const PinImageField({
    super.key,
    required this.imageUrl,
    this.imageWidth,
    this.imageHeight,
    required this.initialX,
    required this.initialY,
    required this.onPinChanged,
    this.showCoordinates = true,
    this.overlays = const <PinImageOverlay>[],
  });

  @override
  State<PinImageField> createState() => _PinImageFieldState();
}

class _PinImageFieldState extends State<PinImageField> {
  final TransformationController _transformController = TransformationController();
  late double _normX;
  late double _normY;

  @override
  void initState() {
    super.initState();
    _normX = widget.initialX;
    _normY = widget.initialY;
  }

  @override
  void didUpdateWidget(covariant PinImageField oldWidget) {
    super.didUpdateWidget(oldWidget);
    final bool coordsChanged = oldWidget.initialX != widget.initialX ||
        oldWidget.initialY != widget.initialY;
    if (coordsChanged) {
      final double nextX = widget.initialX.clamp(0.0, 1.0).toDouble();
      final double nextY = widget.initialY.clamp(0.0, 1.0).toDouble();
      if (_normX != nextX || _normY != nextY) {
        setState(() {
          _normX = nextX;
          _normY = nextY;
        });
      }
    }
  }

  /// Zoom in by scaling the current transformation matrix.
  void _zoomIn() {
    final currentMatrix = _transformController.value;
    _transformController.value = currentMatrix.scaled(1.2, 1.2);
  }

  /// Zoom out by scaling the current transformation matrix.
  void _zoomOut() {
    final currentMatrix = _transformController.value;
    _transformController.value = currentMatrix.scaled(0.8, 0.8);
  }

  @override
  Widget build(BuildContext context) {
    // Fallback dimensions if not provided.
    const double fallbackWidth = 600.0;
    const double fallbackHeight = 400.0;

    final usedWidth = widget.imageWidth ?? fallbackWidth;
    final usedHeight = widget.imageHeight ?? fallbackHeight;
    const double pinIconSize = 24.0;
    const double pinAnchorX = 0.5; // center horizontally
    const double pinAnchorY = 1.0; // tip/bottom of icon aligns with target

    return Container(
      margin: const EdgeInsets.only(bottom: 16.0),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(4.0),
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Top image area using AspectRatio so it scales based on the image ratio.
          ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(4.0),
              topRight: Radius.circular(4.0),
            ),
            child: AspectRatio(
              aspectRatio: usedWidth / usedHeight,
              child: InteractiveViewer(
                transformationController: _transformController,
                boundaryMargin: const EdgeInsets.all(999999),
                minScale: 1.0,
                maxScale: 4.0,
                panEnabled: true,
                clipBehavior: Clip.none,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final containerWidth = constraints.maxWidth;
                    final containerHeight = constraints.maxHeight;

                    // Scale the image to fit the container.
                    final baseScale = math.min(
                      containerWidth / usedWidth,
                      containerHeight / usedHeight,
                    );
                    final displayedWidth = usedWidth * baseScale;
                    final displayedHeight = usedHeight * baseScale;
                    final offsetX = (containerWidth - displayedWidth) / 2;
                    final offsetY = (containerHeight - displayedHeight) / 2;

                    // Calculate the draggable pin's absolute position.
                    final baseX = offsetX + _normX * displayedWidth;
                    final baseY = offsetY + _normY * displayedHeight;
                    final pinLeft = baseX - (pinIconSize * pinAnchorX);
                    final pinTop = baseY - (pinIconSize * pinAnchorY);

                    return Stack(
                      clipBehavior: Clip.none,
                      children: [
                        // The underlying image.
                        Image.network(
                          widget.imageUrl,
                          fit: BoxFit.contain,
                          width: containerWidth,
                          height: containerHeight,
                          errorBuilder: (ctx, error, stack) =>
                              const Center(child: Text('Could not load image.')),
                        ),
                        for (final overlay in widget.overlays)
                          Positioned(
                            left: offsetX +
                                overlay.normalizedBounds.left * displayedWidth,
                            top: offsetY +
                                overlay.normalizedBounds.top * displayedHeight,
                            width:
                                overlay.normalizedBounds.width * displayedWidth,
                            height: overlay.normalizedBounds.height *
                                displayedHeight,
                            child: IgnorePointer(
                              child: Image.memory(
                                overlay.bytes,
                                fit: BoxFit.fill,
                                gaplessPlayback: true,
                              ),
                            ),
                          ),
                        // Draggable pin.
                        Positioned(
                          left: pinLeft,
                          top: pinTop,
                          child: GestureDetector(
                            onPanUpdate: (details) {
                              setState(() {
                                final dx = details.delta.dx;
                                final dy = details.delta.dy;
                                final deltaNormX = dx / displayedWidth;
                                final deltaNormY = dy / displayedHeight;
                                _normX = (_normX + deltaNormX).clamp(0.0, 1.0);
                                _normY = (_normY + deltaNormY).clamp(0.0, 1.0);
                              });
                              widget.onPinChanged(_normX, _normY);
                            },
                            child: const Icon(
                              Icons.location_on,
                              color: Colors.red,
                              size: pinIconSize,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
          // Bottom row with pin coordinates and zoom buttons in one row.
          ClipRRect(
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(4.0),
              bottomRight: Radius.circular(4.0),
            ),
            child: Container(
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(color: Colors.grey, width: 1),
                ),
                color: Colors.white,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Coordinates text.
                  if (widget.showCoordinates)
                    Text(
                      'Pin Coordinates: x=${(_normX * 100).toStringAsFixed(0)}%, '
                      'y=${(_normY * 100).toStringAsFixed(0)}%',
                      style: const TextStyle(fontSize: 14),
                    )
                  else
                    const SizedBox.shrink(),
                  // Zoom buttons using system (primary) color.
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(
                          Icons.zoom_in,
                          color: Theme.of(context).primaryColor,
                        ),
                        tooltip: 'Zoom In',
                        onPressed: _zoomIn,
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.zoom_out,
                          color: Theme.of(context).primaryColor,
                        ),
                        tooltip: 'Zoom Out',
                        onPressed: _zoomOut,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
