import 'dart:async';

import 'package:shared_widgets/fields/ai_text.dart' as shared;
import 'package:flutter/material.dart';
import 'google_streaming_transcriber.dart';

/// App wrapper for the shared AI text field.
/// - Uses the streaming STT transcriber adapter by default.
class AITextField extends StatelessWidget {
  const AITextField({
    super.key,
    required this.labelText,
    this.initialValue,
    this.controller,
    this.minLines,
    this.maxLines,
    this.onChanged,
    this.validator,
    this.onSaved,
    this.enabled = true,
    this.rewriteModel = 'gemini-2.5-flash',
    this.rewriteTemperature = 0.2,
    this.height = shared.StreamingSpeechFieldHeight.expanded,
    this.createTranscriber,
  });

  final String labelText;
  final String? initialValue;
  final TextEditingController? controller;
  final int? minLines;
  final int? maxLines;
  final ValueChanged<String>? onChanged;
  final FormFieldValidator<String>? validator;
  final FormFieldSetter<String>? onSaved;
  final bool enabled;
  final String rewriteModel;
  final double rewriteTemperature;
  final shared.StreamingSpeechFieldHeight height;
  final shared.LiveChunkedTranscriber Function()? createTranscriber;

  @override
  Widget build(BuildContext context) {
    return shared.AITextField(
      labelText: labelText,
      initialValue: initialValue,
      controller: controller,
      minLines: minLines,
      maxLines: maxLines,
      onChanged: onChanged,
      validator: validator,
      onSaved: onSaved,
      enabled: enabled,
      rewriteModel: rewriteModel,
      rewriteTemperature: rewriteTemperature,
      height: height,
      createTranscriber: createTranscriber ?? createGoogleStreamingTranscriber,
    );
  }
}

/// Minimal no-op transcriber for apps that only need the text/rewrite
/// features of the shared AITextField (no microphone/streaming).
class NoOpTranscriber implements shared.LiveChunkedTranscriber {
  NoOpTranscriber();

  final StreamController<String> _controller =
      StreamController<String>.broadcast();

  @override
  Stream<String> get transcriptStream => _controller.stream;

  @override
  Future<void> start({bool freshSession = false}) async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() async {
    await _controller.close();
  }
}

shared.LiveChunkedTranscriber createNoOpTranscriber() => NoOpTranscriber();
shared.LiveChunkedTranscriber createGoogleStreamingTranscriber() =>
    GoogleStreamingTranscriberAdapter();

/// Adapter that bridges the app's Google streaming transcriber to the
/// shared_widgets LiveChunkedTranscriber contract.
class GoogleStreamingTranscriberAdapter
    implements shared.LiveChunkedTranscriber {
  GoogleStreamingTranscriberAdapter({GoogleStreamingTranscriber? delegate})
      : _delegate = delegate ?? GoogleStreamingTranscriber();

  final GoogleStreamingTranscriber _delegate;

  @override
  Stream<String> get transcriptStream => _delegate.transcriptStream;

  @override
  Future<void> start({bool freshSession = false}) =>
      _delegate.start(freshSession: freshSession);

  @override
  Future<void> stop() => _delegate.stop();

  @override
  Future<void> dispose() => _delegate.dispose();
}

/// Backwards compatibility alias for prior SpeechTextField usage.
typedef SpeechTextField = AITextField;
