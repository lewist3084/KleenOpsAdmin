// lib/common/communications/messageboard/widgets/pdf_preview_io.dart

import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

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
  bool _failed = false;

  @override
  void didUpdateWidget(covariant PdfPreviewBoxImpl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _failed = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) return widget.fallback;
    return IgnorePointer(
      child: SfPdfViewer.network(
        widget.url,
        key: ValueKey(widget.url),
        canShowScrollHead: false,
        canShowScrollStatus: false,
        onDocumentLoadFailed: (_) {
          if (mounted) setState(() => _failed = true);
        },
      ),
    );
  }
}

