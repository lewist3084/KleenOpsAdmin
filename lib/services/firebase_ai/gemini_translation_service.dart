// gemini_translation_service.dart
//
// Batch translator for short dynamic strings (chart-of-accounts names, section
// headers). Given a list of names, returns each name translated into the app's
// supported locales, using standard accounting terminology. Used to populate a
// `nameLocalized` map on account / section docs so the ledger, P&L and Balance
// Sheet render in the user's language.

import 'dart:convert';

import 'package:firebase_ai/firebase_ai.dart';

/// The app's supported locales (minus `en`, which is the canonical `name`).
const List<String> kAccountLocales = [
  'es', 'ht', 'zh', 'zh_HK', 'it', 'pt', 'fr', 'ko', 'km',
  'ja', 'ru', 'de', 'sm', 'tl', 'vi', 'hi', 'to', 'ar',
];

class GeminiTranslationService {
  GeminiTranslationService({FirebaseAI? firebaseAI})
      : _ai = firebaseAI ?? FirebaseAI.vertexAI();

  static const String _model = 'gemini-2.5-flash';
  final FirebaseAI _ai;

  /// Translates each name into [locales] (defaults to [kAccountLocales]).
  /// Returns `{ name: { locale: translation, … , 'en': name } }`.
  Future<Map<String, Map<String, String>>> translateNames(
    List<String> names, {
    List<String>? locales,
  }) async {
    final targetLocales = locales ?? kAccountLocales;
    if (names.isEmpty) return {};

    final systemPrompt = [
      'You are a professional accounting translator. Translate each general-',
      'ledger account/section name into each requested locale, using the',
      'standard accounting term a native bookkeeper would use (concise, title',
      'case where appropriate). Locale codes: es=Spanish, ht=Haitian Creole,',
      'zh=Simplified Chinese, zh_HK=Traditional Chinese (HK), it=Italian,',
      'pt=Portuguese, fr=French, ko=Korean, km=Khmer, ja=Japanese, ru=Russian,',
      'de=German, sm=Samoan, tl=Tagalog, vi=Vietnamese, hi=Hindi, to=Tongan,',
      'ar=Arabic. Return JSON matching the schema — one entry per input name,',
      'each with a translation for every requested locale.',
    ].join(' ');

    final buf = StringBuffer()
      ..writeln('Locales: ${targetLocales.join(', ')}')
      ..writeln()
      ..writeln('Names:')
      ..writeln(names.map((n) => '- $n').join('\n'));

    final responseSchema = Schema.object(
      properties: {
        'items': Schema.array(
          items: Schema.object(
            properties: {
              'name': Schema.string(),
              'translations': Schema.array(
                items: Schema.object(
                  properties: {
                    'locale': Schema.string(),
                    'text': Schema.string(),
                  },
                ),
              ),
            },
          ),
        ),
      },
    );

    final model = _ai.generativeModel(
      model: _model,
      generationConfig: GenerationConfig(
        temperature: 0.0,
        responseMimeType: 'application/json',
        responseSchema: responseSchema,
      ),
      systemInstruction: Content.system(systemPrompt),
    );

    final response =
        await model.generateContent(<Content>[Content.text(buf.toString())]);
    final text = response.text;
    if (text == null || text.trim().isEmpty) return {};

    Map<String, dynamic> parsed;
    try {
      parsed = jsonDecode(_stripFences(text)) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }

    final out = <String, Map<String, String>>{};
    for (final item in (parsed['items'] as List? ?? const [])) {
      if (item is! Map) continue;
      final name = (item['name'] ?? '').toString();
      if (name.isEmpty) continue;
      final byLocale = <String, String>{'en': name};
      for (final t in (item['translations'] as List? ?? const [])) {
        if (t is! Map) continue;
        final locale = (t['locale'] ?? '').toString().trim();
        final value = (t['text'] ?? '').toString().trim();
        if (locale.isNotEmpty && value.isNotEmpty) byLocale[locale] = value;
      }
      out[name] = byLocale;
    }
    return out;
  }

  String _stripFences(String text) {
    var t = text.trim();
    if (t.startsWith('```')) {
      final nl = t.indexOf('\n');
      if (nl != -1) t = t.substring(nl + 1);
      if (t.endsWith('```')) t = t.substring(0, t.length - 3);
    }
    return t.trim();
  }
}

/// Resolves the best display name for an account/section doc given a locale.
/// Falls back to the canonical `name` when no translation is present.
String localizedAccountName(Map<String, dynamic> data, String localeTag) {
  final name = (data['name'] ?? '').toString();
  final loc = data['nameLocalized'];
  if (loc is Map) {
    final normalized = localeTag.replaceAll('-', '_'); // zh-HK -> zh_HK
    final lang = normalized.split('_').first;
    final hit = loc[normalized] ?? loc[lang];
    if (hit != null && hit.toString().trim().isNotEmpty) return hit.toString();
  }
  return name;
}
