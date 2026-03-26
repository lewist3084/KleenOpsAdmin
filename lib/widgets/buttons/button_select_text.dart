//  button_select_text.dart
import 'package:flutter/material.dart';

/// A tappable text button that shows a label flanked by optional images.
///
/// * **leadingImageUrl** – image from the *companyObject* document (left side)
/// * **trailingImageUrl** – image from the *processId* reference (right side)
class ButtonSelectText extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  /// Left-side image (companyObject header)
  final String? leadingImageUrl;

  /// Right‑side image (processId → imageUrl)
  final String? trailingImageUrl;

  /// Size (width & height) of each image box
  final double imageSize;
  final Color? selectedColor;
  final Color? borderColor;
  final double borderWidth;
  final TextStyle? textStyle;

  /// Padding when **no** images are present
  final EdgeInsetsGeometry noImagePadding;

  /// Padding applied directly to the label
  final EdgeInsetsGeometry labelPadding;

  final BorderRadiusGeometry borderRadius;
  final double imageCornerRadius;

  const ButtonSelectText({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.leadingImageUrl,
    this.trailingImageUrl,
    this.imageSize = 36.0,
    this.selectedColor,
    this.borderColor,
    this.borderWidth = 1.0,
    this.textStyle,
    this.noImagePadding = const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
    this.labelPadding = const EdgeInsets.symmetric(horizontal: 6),
    this.borderRadius = const BorderRadius.all(Radius.circular(4)),
    this.imageCornerRadius = 3.0,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = selectedColor ?? theme.colorScheme.primary;
    final outline = borderColor ?? Colors.grey;
    final bgColor = selected ? primary : Colors.white;
    final txtColor = selected ? Colors.black : Colors.grey;

    // Dynamically compute outer padding so images sit flush on the edges
        // Outer padding – remove vertical pads when any image exists
    final EdgeInsets containerPadding = EdgeInsets.only(
      left: leadingImageUrl != null ? 0 : 6,
      right: trailingImageUrl != null ? 0 : 6,
      top: (leadingImageUrl != null || trailingImageUrl != null) ? 0 : 8,
      bottom: (leadingImageUrl != null || trailingImageUrl != null) ? 0 : 8,
    );

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: containerPadding,
        decoration: BoxDecoration(
          color: bgColor,
          border: Border.all(color: outline, width: borderWidth),
          borderRadius: borderRadius,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Leading image ─────────────────────────────────────────────
            if (leadingImageUrl != null)
              Padding(
                padding: const EdgeInsets.only(left: 0, right: 6),
                child: _ImageBox(
                  url: leadingImageUrl!,
                  size: imageSize,
                  radius: imageCornerRadius,
                  border: const Border(right: BorderSide(color: Colors.grey)),
                  topLeft: true,
                ),
              ),

            // ── Label (ellipsis if too long) ───────────────────────────────
            Flexible(
              child: Padding(
                padding: labelPadding,
                child: Text(
                  label,
                  style: textStyle ?? TextStyle(color: txtColor),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),

            // ── Trailing image ────────────────────────────────────────────
            if (trailingImageUrl != null)
              Padding(
                padding: const EdgeInsets.only(left: 6, right: 0),
                child: _ImageBox(
                  url: trailingImageUrl!,
                  size: imageSize,
                  radius: imageCornerRadius,
                  border: const Border(left: BorderSide(color: Colors.grey)),
                  topLeft: false,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/* ─────────────────────────── helper ─────────────────────────── */
class _ImageBox extends StatelessWidget {
  final String url;
  final double size;
  final double radius;
  final Border border;
  final bool topLeft; // true ⇒ leading image, affects corner rounding

  const _ImageBox({
    super.key,
    required this.url,
    required this.size,
    required this.radius,
    required this.border,
    required this.topLeft,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        border: border,
        borderRadius: topLeft
            ? BorderRadius.only(
                topLeft: Radius.circular(radius),
                bottomLeft: Radius.circular(radius),
              )
            : BorderRadius.only(
                topRight: Radius.circular(radius),
                bottomRight: Radius.circular(radius),
              ),
      ),
      child: ClipRRect(
        borderRadius: topLeft
            ? BorderRadius.only(
                topLeft: Radius.circular(radius),
                bottomLeft: Radius.circular(radius),
              )
            : BorderRadius.only(
                topRight: Radius.circular(radius),
                bottomRight: Radius.circular(radius),
              ),
        child: Image.network(
          url,
          width: size,
          height: size,
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}
