// lib/common/communications/email/widgets/email_attachment_picker_sheet.dart
//
// Modal bottom sheet that asks "where from?" when the user taps the paperclip
// in compose. Forks between picking from the mailbox company's existing files
// and picking + uploading a fresh file from the device. Mirrors the kleenops
// app; uses ScaffoldMessenger for the over-cap notice.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_widgets/theme/app_palette.dart';

import '../models/email_attachment.dart';
import '../screens/email_company_files_picker_screen.dart';
import '../services/email_attachment_uploader.dart';

enum _Choice { fromFiles, fromDevice }

/// Show the attach-source sheet. Returns the attachments the user selected
/// (possibly empty / null if they cancelled). The caller is responsible for
/// enforcing any aggregate size cap.
Future<List<EmailAttachment>?> showEmailAttachmentPickerSheet(
  BuildContext context, {
  required DocumentReference<Map<String, dynamic>> companyRef,
  DocumentReference<Map<String, dynamic>>? userRef,
  DocumentReference<Map<String, dynamic>>? memberRef,
  DocumentReference<Map<String, dynamic>>? teamRef,
  int? maxTotalBytes,
  int currentTotalBytes = 0,
}) async {
  final choice = await showModalBottomSheet<_Choice>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => const _AttachSourceSheet(),
  );
  if (choice == null || !context.mounted) return null;

  switch (choice) {
    case _Choice.fromFiles:
      final remaining = maxTotalBytes == null
          ? null
          : (maxTotalBytes - currentTotalBytes).clamp(0, maxTotalBytes);
      final selected = await Navigator.of(context).push<List<EmailAttachment>>(
        MaterialPageRoute(
          builder: (_) => EmailCompanyFilesPickerScreen(
            maxTotalBytes: remaining,
          ),
        ),
      );
      return selected ?? const <EmailAttachment>[];

    case _Choice.fromDevice:
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
                  '"${uploaded.fileName}" was uploaded to Files but exceeds '
                  'the '
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
            leading: Icon(Icons.folder_outlined, color: palette.primary2),
            title: const Text('Attach from Files'),
            subtitle: const Text('Pick from this company\'s existing files'),
            onTap: () => Navigator.of(context).pop(_Choice.fromFiles),
          ),
          ListTile(
            leading: Icon(Icons.upload_file, color: palette.primary2),
            title: const Text('Upload from device'),
            subtitle: const Text('Pick a file; it\'s saved to Files for reuse'),
            onTap: () => Navigator.of(context).pop(_Choice.fromDevice),
          ),
        ],
      ),
    );
  }
}
