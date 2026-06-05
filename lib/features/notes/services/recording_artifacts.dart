import 'dart:typed_data';

/// Describes the audio artifacts produced by a live transcription session.
class RecordingArtifacts {
  const RecordingArtifacts({
    this.filePath,
    this.bytes,
    this.mimeType,
    this.fileExtension,
  });

  /// Local file system path for the combined audio recording (mobile/desktop).
  final String? filePath;

  /// In-memory audio bytes (web).
  final Uint8List? bytes;

  /// Optional MIME type, for example `audio/mp4` or `audio/webm`.
  final String? mimeType;

  /// Suggested file extension associated with the audio payload.
  final String? fileExtension;

  bool get hasFilePath => filePath != null && filePath!.isNotEmpty;

  bool get hasBytes => bytes != null && bytes!.isNotEmpty;
}
