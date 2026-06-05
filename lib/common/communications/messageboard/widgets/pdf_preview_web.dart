// lib/common/communications/messageboard/widgets/pdf_preview_web.dart

import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

/// Web build of [PdfPreviewBox]: renders the PDF inline via a browser-native
/// `<iframe>`. Syncfusion's web renderer is unreliable for some Firebase
/// Storage URLs, while every modern browser ships with a built-in PDF viewer
/// that handles them fine. `pointer-events: none` on the iframe lets taps
/// fall through to the parent `GestureDetector` so the tap-to-fullscreen
/// behavior still works.
class PdfPreviewBoxImpl extends StatefulWidget {
  const PdfPreviewBoxImpl({
    super.key,
    required this.url,
    required this.fallback,
  });

  final String url;
  final Widget fallback;

  @override
  State<PdfPreviewBoxImpl> createState() => _PdfPreviewBoxImplState();
}

class _PdfPreviewBoxImplState extends State<PdfPreviewBoxImpl> {
  late String _viewType;

  @override
  void initState() {
    super.initState();
    _viewType = _registerIframe(widget.url);
  }

  @override
  void didUpdateWidget(covariant PdfPreviewBoxImpl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _viewType = _registerIframe(widget.url);
    }
  }

  String _registerIframe(String url) {
    final viewType = 'pdf-preview-${url.hashCode}';
    ui_web.platformViewRegistry.registerViewFactory(viewType, (int _) {
      final iframe = web.HTMLIFrameElement()
        ..src = _decorate(url)
        ..allowFullscreen = false;
      iframe.style.border = '0';
      iframe.style.width = '100%';
      iframe.style.height = '100%';
      iframe.style.pointerEvents = 'none';
      return iframe as JSObject;
    });
    return viewType;
  }

  String _decorate(String url) {
    final separator = url.contains('#') ? '&' : '#';
    return '$url${separator}toolbar=0&navpanes=0&scrollbar=0&view=FitH';
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(viewType: _viewType);
  }
}

