// Admin adapter around the shared SmsControlStrip. Defaults the mic
// transcriber to the app's Google streaming transcriber so every compose
// surface gets dictation for free (mirrors kleenops + the SearchControlStrip
// adapter pattern).

import 'package:flutter/material.dart';
import 'package:shared_widgets/fields/ai_text.dart' as shared_ai;
import 'package:shared_widgets/messaging/sms_control_strip.dart' as shared;

import 'package:kleenops_admin/services/ai_text_adapter.dart'
    show createGoogleStreamingTranscriber;

class SmsControlStrip extends StatelessWidget {
  const SmsControlStrip({
    super.key,
    required this.controller,
    required this.onSend,
    this.hintText = 'Type a message...',
    this.onAttachmentTap,
    this.attachmentTooltip,
    this.createTranscriber,
    this.sending = false,
    this.enabled = true,
    this.focusNode,
    this.autofocus = false,
    this.onSubmitted,
    this.maxLength,
    this.onTypingChanged,
    this.enableAiActions = true,
    this.aiFieldLabel = 'text message',
    this.aiFieldContext,
  });

  final TextEditingController controller;
  final VoidCallback onSend;
  final String hintText;
  final VoidCallback? onAttachmentTap;
  final String? attachmentTooltip;
  final shared_ai.LiveChunkedTranscriber Function()? createTranscriber;
  final bool sending;
  final bool enabled;
  final FocusNode? focusNode;
  final bool autofocus;
  final ValueChanged<String>? onSubmitted;
  final int? maxLength;
  final ValueChanged<bool>? onTypingChanged;
  final bool enableAiActions;
  final String aiFieldLabel;
  final String? aiFieldContext;

  @override
  Widget build(BuildContext context) {
    return shared.SmsControlStrip(
      controller: controller,
      onSend: onSend,
      hintText: hintText,
      onAttachmentTap: onAttachmentTap,
      attachmentTooltip: attachmentTooltip,
      createTranscriber: createTranscriber ?? createGoogleStreamingTranscriber,
      sending: sending,
      enabled: enabled,
      focusNode: focusNode,
      autofocus: autofocus,
      onSubmitted: onSubmitted,
      maxLength: maxLength,
      onTypingChanged: onTypingChanged,
      enableAiActions: enableAiActions,
      aiFieldLabel: aiFieldLabel,
      aiFieldContext: aiFieldContext,
    );
  }
}
