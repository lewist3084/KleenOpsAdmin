// lib/widgets/viewers/image_viewer.dart

import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:kleenops_admin/widgets/fields/pin_image_field.dart';

/// Full-screen, tappable, zoomable image viewer that can overlay a pin and optional
/// flood-fill overlays when provided.
class ImageViewer extends StatelessWidget {
  final String imageUrl;
  final double? floorImgWidth;
  final double? floorImgHeight;
  final double? pinXAbsolute;
  final double? pinYAbsolute;
  final List<PinImageOverlay> overlays;

  const ImageViewer({
    super.key,
    required this.imageUrl,
    this.floorImgWidth,
    this.floorImgHeight,
    this.pinXAbsolute,
    this.pinYAbsolute,
    this.overlays = const <PinImageOverlay>[],
  });

  @override
  Widget build(BuildContext context) {
    final hasPin = floorImgWidth != null &&
        floorImgHeight != null &&
        pinXAbsolute != null &&
        pinYAbsolute != null;
    final hasOverlays = overlays.isNotEmpty;

    Widget buildImage({double? width, double? height}) {
      const fit = BoxFit.contain;
      if (imageUrl.startsWith('data:image')) {
        final bytes = base64Decode(imageUrl.split(',').last);
        return Image.memory(
          bytes,
          width: width,
          height: height,
          fit: fit,
          errorBuilder: (ctx, error, stack) => const Center(
            child: Text(
              'Failed to load image',
              style: TextStyle(color: Colors.white),
            ),
          ),
        );
      }

      return Image.network(
        imageUrl,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (ctx, error, stack) => const Center(
          child: Text(
            'Failed to load image',
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.of(context).pop(),
        child: SafeArea(
          child: InteractiveViewer(
            boundaryMargin: const EdgeInsets.all(999999),
            minScale: 1.0,
            maxScale: 4.0,
            panEnabled: true,
            clipBehavior: Clip.none,
            child: Center(
              child: hasPin || hasOverlays
                  ? LayoutBuilder(
                      builder: (context, constraints) {
                        final cw = constraints.maxWidth;
                        final ch = constraints.maxHeight;
                        const iconSize = 24.0;
                        const pinAnchorX = 0.5;
                        const pinAnchorY = 1.0;

                        double resolvedBaseWidth =
                            (floorImgWidth ?? 0) > 0 ? floorImgWidth! : cw;
                        double resolvedBaseHeight =
                            (floorImgHeight ?? 0) > 0 ? floorImgHeight! : ch;
                        if (resolvedBaseWidth <= 0) resolvedBaseWidth = 1;
                        if (resolvedBaseHeight <= 0) resolvedBaseHeight = 1;

                        final scale = math.min(
                          cw / resolvedBaseWidth,
                          ch / resolvedBaseHeight,
                        );
                        final dw = resolvedBaseWidth * scale;
                        final dh = resolvedBaseHeight * scale;
                        final ox = (cw - dw) / 2;
                        final oy = (ch - dh) / 2;

                        double? pinLeft;
                        double? pinTop;
                        if (hasPin) {
                          final nx = pinXAbsolute! / resolvedBaseWidth;
                          final ny = pinYAbsolute! / resolvedBaseHeight;
                          pinLeft = ox + nx * dw - iconSize * pinAnchorX;
                          pinTop = oy + ny * dh - iconSize * pinAnchorY;
                        }

                        return SizedBox(
                          width: cw,
                          height: ch,
                          child: Stack(
                            children: [
                              Positioned(
                                left: ox,
                                top: oy,
                                child: buildImage(width: dw, height: dh),
                              ),
                              for (final overlay in overlays)
                                Positioned(
                                  left:
                                      ox + overlay.normalizedBounds.left * dw,
                                  top: oy + overlay.normalizedBounds.top * dh,
                                  width: overlay.normalizedBounds.width * dw,
                                  height: overlay.normalizedBounds.height * dh,
                                  child: IgnorePointer(
                                    child: Image.memory(
                                      overlay.bytes,
                                      fit: BoxFit.fill,
                                      gaplessPlayback: true,
                                      errorBuilder: (_, __, ___) =>
                                          const SizedBox.shrink(),
                                    ),
                                  ),
                                ),
                              if (pinLeft != null && pinTop != null)
                                Positioned(
                                  left: pinLeft,
                                  top: pinTop,
                                  child: const Icon(
                                    Icons.location_on,
                                    size: iconSize,
                                    color: Colors.red,
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    )
                  : buildImage(),
            ),
          ),
        ),
      ),
    );
  }
}
