/// A finalized chunk of speech from the streaming transcriber.
///
/// Emitted only when STT marks a result as final, so each utterance is
/// stable text that can be persisted with a stable timestamp.
class TranscriptUtterance {
  TranscriptUtterance({required this.text, required this.timestamp});

  final String text;
  final DateTime timestamp;
}
