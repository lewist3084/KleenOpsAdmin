// lib/common/communications/messageboard/widgets/pdf_preview.dart

import 'package:flutter/material.dart';

import 'pdf_preview_io.dart'
    if (dart.library.js_interop) 'pdf_preview_web.dart';

/// Inline, non-interactive preview of a PDF's first page.
///
/// Used by both the message board card grid and the post detail screen so
/// web and mobile render the same preview. Tap handling is left to the
/// caller (wrap this in a [GestureDetector] with
/// `behavior: HitTestBehavior.opaque` â€” the preview ignores pointer events
/// itself).
///
/// Mobile uses Syncfusion's [SfPdfViewer]. Web uses a browser-native
/// `<iframe>` (Syncfusion's web renderer is unreliable for some Storage
/// URLs). If the mobile renderer fails to load, the widget swaps to
/// [fallback].
class PdfPreviewBox extends StatelessWidget {
  const PdfPreviewBox({
    super.key,
    required this.url,
    required this.fallback,
  });

  /// Network URL of the PDF to preview.
  final String url;

  /// Widget shown when the PDF fails to load (mobile only â€” the web build
  /// relies on the browser's native PDF viewer and doesn't surface a
  /// load-failed callback).
  final Widget fallback;

  @override
  Widget build(BuildContext context) {
    return PdfPreviewBoxImpl(url: url, fallback: fallback);
  }
}

