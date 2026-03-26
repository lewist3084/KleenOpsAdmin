// lib/widgets/viewers/pdf_viewer.dart

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:shared_widgets/viewers/pdf_viewer.dart' as shared;

/// KleenOps wrapper for the shared PDF viewer.
class PdfViewer extends StatelessWidget {
  /// URL of the PDF to display. Provide either [pdfUrl] or [pdfBytes].
  final String? pdfUrl;

  /// Raw PDF bytes to display. Provide either [pdfBytes] or [pdfUrl].
  final Uint8List? pdfBytes;

  /// Optional callback when the user cancels the preview.
  final VoidCallback? onCancel;

  /// Optional callback when the user chooses to save the document.
  final Future<void> Function()? onSave;

  /// When true, hides app chrome in landscape.
  final bool hideChromeInLandscape;

  const PdfViewer({
    super.key,
    this.pdfUrl,
    this.pdfBytes,
    this.onCancel,
    this.onSave,
    this.hideChromeInLandscape = true,
  })  : assert(pdfUrl != null || pdfBytes != null,
            'Either pdfUrl or pdfBytes must be provided');

  @override
  Widget build(BuildContext context) {
    return shared.PdfViewer(
      pdfUrl: pdfUrl,
      pdfBytes: pdfBytes,
      onCancel: onCancel,
      onSave: onSave,
      hideChromeInLandscape: hideChromeInLandscape,
    );
  }
}
