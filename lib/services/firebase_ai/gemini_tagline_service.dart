// gemini_tagline_service.dart
//
// Generates a short (≈6-word) marketing tagline for a business, inferred from
// its name and business type. Used by the Business Setup Wizard to auto-fill
// the company tagline so onboarding stays uncluttered — there is no longer a
// dedicated "Create a Tagline" step. The owner can refine it later on the
// Company → Profile screen.

import 'package:firebase_ai/firebase_ai.dart';

class GeminiTaglineService {
  GeminiTaglineService({FirebaseAI? firebaseAI})
      : _ai = firebaseAI ?? FirebaseAI.vertexAI();

  static const String _model = 'gemini-2.5-flash';
  final FirebaseAI _ai;

  /// Returns a single concise tagline (no surrounding quotes / trailing
  /// period), or '' on failure. Temperature is high so repeat calls vary.
  Future<String> generateTagline({
    required String businessName,
    String? businessType,
  }) async {
    final name = businessName.trim();
    if (name.isEmpty) return '';

    final systemPrompt = [
      'You write punchy marketing taglines for small businesses.',
      'Given a business name and a short description of what it does, write',
      'exactly ONE tagline. Rules: at most 6 words; no quotation marks; no',
      'trailing period; confident and memorable; do NOT repeat the business',
      'name. Return only the tagline text — nothing else.',
    ].join(' ');

    final prompt = StringBuffer()
      ..writeln('Business name: $name')
      ..writeln('What the business does: ${_describeType(businessType)}');

    final model = _ai.generativeModel(
      model: _model,
      generationConfig: GenerationConfig(
        temperature: 1.0,
        maxOutputTokens: 32,
      ),
      systemInstruction: Content.system(systemPrompt),
    );

    try {
      final response = await model
          .generateContent(<Content>[Content.text(prompt.toString())]);
      return _clean(response.text);
    } catch (_) {
      return '';
    }
  }

  String _describeType(String? businessType) {
    switch (businessType) {
      case 'internalUse':
        return 'An organization that maintains and cleans its own facilities.';
      case 'facilities':
        return 'A company selling cleaning and facilities-maintenance services '
            'to other businesses.';
      default:
        return 'A professional cleaning and facilities-maintenance business.';
    }
  }

  String _clean(String? raw) {
    if (raw == null) return '';
    var t = raw.trim();

    // Keep only the first line.
    final nl = t.indexOf('\n');
    if (nl != -1) t = t.substring(0, nl).trim();

    // Strip wrapping quote characters.
    const quotes = ['"', '“', '”', "'", '‘', '’'];
    while (t.isNotEmpty && quotes.contains(t[0])) {
      t = t.substring(1);
    }
    while (t.isNotEmpty && quotes.contains(t[t.length - 1])) {
      t = t.substring(0, t.length - 1);
    }
    t = t.trim();

    // Drop a trailing period.
    if (t.endsWith('.')) t = t.substring(0, t.length - 1).trim();

    // Hard cap at 6 words.
    final words = t.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.length > 6) t = words.take(6).join(' ');

    return t;
  }
}
