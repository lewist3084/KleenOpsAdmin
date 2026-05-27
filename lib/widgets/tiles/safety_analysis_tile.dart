// lib/widgets/tiles/safety_analysis_tile.dart
//
// Admin-app stub for the kleenops SafetyAnalysisTile. The real widget pulls
// in heavy media viewers (PDF, video, image) and is out of scope for the
// admin port. This stub preserves the same constructor so callers compile
// and renders a lightweight ListTile-style fallback at runtime.

import 'package:flutter/material.dart';

class SafetyAnalysisTile extends StatelessWidget {
  final String imageUrl;
  final String firstLine;
  final IconData? firstLineIcon;
  final String secondLine;
  final IconData? secondLineIcon;
  final String? thirdLine;
  final IconData? thirdLineIcon;
  final String? fourthLine;
  final IconData? fourthLineIcon;
  final IconData? trailingIcon1;
  final VoidCallback? trailingAction1;
  final IconData? trailingIcon2;
  final VoidCallback? trailingAction2;
  final IconData? trailingIcon3;
  final VoidCallback? trailingAction3;
  final String? trailingText;
  final String? bottomRightText;
  final VoidCallback? onImageTap;
  final String? mediaType;
  final String? videoUrl;
  final BoxFit fit;
  final IconData? overlayIcon;
  final VoidCallback? overlayAction;
  final bool showImage;

  const SafetyAnalysisTile({
    super.key,
    required this.imageUrl,
    required this.firstLine,
    this.firstLineIcon,
    this.secondLine = '',
    this.secondLineIcon,
    this.thirdLine,
    this.thirdLineIcon,
    this.fourthLine,
    this.fourthLineIcon,
    this.trailingIcon1,
    this.trailingAction1,
    this.trailingIcon2,
    this.trailingAction2,
    this.trailingIcon3,
    this.trailingAction3,
    this.trailingText,
    this.bottomRightText,
    this.onImageTap,
    this.mediaType,
    this.videoUrl,
    this.fit = BoxFit.contain,
    this.overlayIcon,
    this.overlayAction,
    this.showImage = true,
  });

  @override
  Widget build(BuildContext context) {
    final actions = <Widget>[];
    void addAction(IconData? icon, VoidCallback? cb) {
      if (icon != null) {
        actions.add(IconButton(icon: Icon(icon), onPressed: cb));
      }
    }

    addAction(trailingIcon1, trailingAction1);
    addAction(trailingIcon2, trailingAction2);
    addAction(trailingIcon3, trailingAction3);

    return Card(
      child: ListTile(
        leading: firstLineIcon == null ? null : Icon(firstLineIcon),
        title: Text(firstLine),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (secondLine.isNotEmpty) Text(secondLine),
            if ((thirdLine ?? '').isNotEmpty) Text(thirdLine!),
            if ((fourthLine ?? '').isNotEmpty) Text(fourthLine!),
            if ((bottomRightText ?? '').isNotEmpty)
              Align(
                alignment: Alignment.centerRight,
                child: Text(bottomRightText!,
                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ),
          ],
        ),
        trailing: actions.isEmpty
            ? (trailingText == null ? null : Text(trailingText!))
            : Row(mainAxisSize: MainAxisSize.min, children: actions),
      ),
    );
  }
}
