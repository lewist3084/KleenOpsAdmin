import 'recording_artifacts.dart';

/// Common interface for live, chunked transcription engines.
///
/// Implemented by the Google transcription engines so the UI can swap
/// providers without changing its control flow.
abstract class LiveChunkedTranscriber {
  Stream<String> get transcriptStream;

  Future<void> start({bool freshSession = false});
  Future<void> pause();
  Future<void> stop();
  Future<void> dispose();

  Future<void> clearArtifacts();
  Future<RecordingArtifacts> buildRecordingArtifacts();
}
