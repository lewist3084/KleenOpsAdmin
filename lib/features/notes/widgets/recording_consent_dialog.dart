import 'package:flutter/material.dart';
import 'package:shared_widgets/dialogs/dialog_action.dart';

/// Shows a consent dialog before recording external calls.
///
/// Returns `true` if the user confirmed recording, `false` if declined.
/// For internal calls (intercom), this is not needed — handled at hiring/policy level.
class RecordingConsentDialog {
  RecordingConsentDialog._();

  static Future<bool> show(
    BuildContext context, {
    required String callType,
  }) async {
    final label = callType == 'phone' ? 'phone call' : 'video call';

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => DialogAction(
        title: 'Recording Notice',
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This $label may be recorded and transcribed for quality '
              'assurance and record-keeping purposes.',
            ),
            const SizedBox(height: 16),
            const Text(
              'All participants will be notified that this call is '
              'being recorded. You can stop recording at any time.',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            const Text(
              'Do you want to enable transcription for this call?',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
          ],
        ),
        cancelText: 'No, Skip',
        onCancel: () => Navigator.pop(ctx, false),
        actionText: 'Yes, Record & Transcribe',
        onAction: () => Navigator.pop(ctx, true),
      ),
    );

    return confirmed ?? false;
  }
}
