// lib/services/google_streaming_transcriber.dart
// Stub — admin app does not use Google streaming transcriber.

import 'dart:async';

class GoogleStreamingTranscriber {
  final StreamController<String> _controller =
      StreamController<String>.broadcast();

  Stream<String> get transcriptStream => _controller.stream;

  Future<void> start({bool freshSession = false}) async {}
  Future<void> stop() async {}
  Future<void> dispose() async {
    await _controller.close();
  }
}
