// lib/common/communications/email/widgets/email_attachment_picker_sheet.dart
//
// Adapted from the kleenops app. The overlord app has no company Files
// browser, so the "Attach from Files" branch is omitted — attachments are
// picked + uploaded from the device only. Uses ScaffoldMessenger for the
// over-cap notice (kleenops used its SnackbarService singleton).

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_widgets/theme/app_palette.dart';

import '../models/email_attachment.dart';
import '../services/email_attachment_uploader.dart';

/// Pick + upload a device file as an email attachment. Returns the attachments
/// the user selected (possibly empty if they cancelled). The caller enforces
/// any aggregate size cap.
Future<List<EmailAttachment>?> showEmailAttachmentPickerSheet(
  BuildContext context, {
  required DocumentReference<Map<String, dynamic>> companyRef,
  DocumentReference<Map<String, dynamic>>? userRef,
  DocumentReference<Map<String, dynamic>>? memberRef,
  DocumentReference<Map<String, dynamic>>? teamRef,
  int? maxTotalBytes,
  int currentTotalBytes = 0,
}) async {
  final confirmed = await showModalBottomSheet<bool>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => const _AttachSourceSheet(),
  );
  if (confirmed != true || !context.mounted) return null;

  final messenger = ScaffoldMessenger.of(context);
  try {
    final uploaded = await EmailAttachmentUploader(
      companyRef: companyRef,
      userRef: userRef,
      memberRef: memberRef,
      teamRef: teamRef,
    ).pickAndUpload();
    if (uploaded == null) return const <EmailAttachment>[];

    if (maxTotalBytes != null) {
      final additional = uploaded.sizeBytes ?? 0;
      if (currentTotalBytes + additional > maxTotalBytes) {
        messenger.showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 5),
            content: Text(
              '"${uploaded.fileName}" was uploaded to Files but exceeds the '
              '${(maxTotalBytes / (1024 * 1024)).toStringAsFixed(0)} MB '
              'attachment cap and was not attached.',
            ),
          ),
        );
        return const <EmailAttachment>[];
      }
    }
    return [uploaded];
  } catch (e) {
    messenger.showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 5),
        content: Text('Upload failed: $e'),
      ),
    );
    return const <EmailAttachment>[];
  }
}

class _AttachSourceSheet extends StatelessWidget {
  const _AttachSourceSheet();

  @override
  Widget build(BuildContext context) {
    final palette = AppPaletteScope.of(context);
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: Icon(Icons.upload_file, color: palette.primary2),
            title: const Text('Upload from device'),
            subtitle: const Text('Pick a file; it\'s saved to Files for reuse'),
            onTap: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );
  }
}
