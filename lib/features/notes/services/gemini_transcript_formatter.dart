import 'package:firebase_ai/firebase_ai.dart';

/// Formats raw transcripts using Gemini.
class GeminiTranscriptFormatter {
  GeminiTranscriptFormatter._();

  static final GenerativeModel _model =
      FirebaseAI.vertexAI().generativeModel(
    model: 'gemini-2.5-flash',
    generationConfig: GenerationConfig(
      temperature: 0.1,
      maxOutputTokens: 2048,
    ),
  );

  /// Format a single chunk of transcript text.
  static Future<String> format(String rawTranscript) async {
    final trimmed = rawTranscript.trim();
    if (trimmed.isEmpty) return '';

    final prompt = StringBuffer()
      ..writeln(
        'Rewrite the transcript with proper casing, punctuation, and sensible paragraph breaks.',
      )
      ..writeln(
        'Preserve the intent and details: do not summarize or omit anything.',
      )
      ..writeln(
        'Fix obvious transcription mistakes when context makes the intended wording clear, but never add new ideas.',
      )
      ..writeln(
        'Insert blank lines between speakers or topic changes. Output plain text only; no bullet points.',
      )
      ..writeln('\nTranscript:\n$trimmed');

    final response = await _model.generateContent(
      [Content.text(prompt.toString())],
    );
    return response.text?.trim() ?? '';
  }

  /// Format a full (potentially long) transcript by chunking it.
  static Future<String> formatFullTranscript(
    String rawTranscript, {
    int maxChunkChars = 2600,
  }) async {
    final trimmed = rawTranscript.trim();
    if (trimmed.isEmpty) return '';

    final chunks = _chunkTranscript(trimmed, maxChunkChars: maxChunkChars);
    final buffer = StringBuffer();

    for (final chunk in chunks) {
      final formatted = await format(chunk);
      if (formatted.isEmpty) continue;
      if (buffer.isNotEmpty) buffer.writeln('\n\n');
      buffer.write(formatted);
    }

    return buffer.toString().trim();
  }

  /// Extract bullet-point summary from formatted text.
  static Future<List<String>> extractBullets(String text) async {
    if (text.trim().isEmpty) return [];

    final prompt = StringBuffer()
      ..writeln(
        'Extract the key points from this meeting transcript as a concise bulleted list.',
      )
      ..writeln(
        'Each bullet should be one sentence. Return only the bullet items, each on its own line prefixed with "- ".',
      )
      ..writeln('\nText:\n${text.trim()}');

    final response = await _model.generateContent(
      [Content.text(prompt.toString())],
    );
    final result = response.text?.trim() ?? '';
    return result
        .split('\n')
        .map((l) => l.replaceFirst(RegExp(r'^[-•]\s*'), '').trim())
        .where((l) => l.isNotEmpty)
        .toList();
  }

  /// Extract action items from formatted text.
  static Future<List<String>> extractActionItems(String text) async {
    if (text.trim().isEmpty) return [];

    final prompt = StringBuffer()
      ..writeln(
        'Extract any action items, tasks, or follow-ups mentioned in this meeting transcript.',
      )
      ..writeln(
        'Each action item should be one line prefixed with "- ". If there are none, return "No action items found."',
      )
      ..writeln('\nText:\n${text.trim()}');

    final response = await _model.generateContent(
      [Content.text(prompt.toString())],
    );
    final result = response.text?.trim() ?? '';
    if (result.contains('No action items')) return [];
    return result
        .split('\n')
        .map((l) => l.replaceFirst(RegExp(r'^[-•]\s*'), '').trim())
        .where((l) => l.isNotEmpty)
        .toList();
  }

  static List<String> _chunkTranscript(
    String text, {
    required int maxChunkChars,
  }) {
    if (text.length <= maxChunkChars) return [text];

    final sentences = text.split(RegExp(r'(?<=[.!?])\s+'));
    final chunks = <String>[];
    final current = StringBuffer();

    for (final sentence in sentences) {
      if (current.length + sentence.length > maxChunkChars &&
          current.isNotEmpty) {
        chunks.add(current.toString().trim());
        current.clear();
      }
      if (current.isNotEmpty) current.write(' ');
      current.write(sentence);
    }

    if (current.isNotEmpty) {
      chunks.add(current.toString().trim());
    }

    return chunks.isEmpty ? [text] : chunks;
  }
}
