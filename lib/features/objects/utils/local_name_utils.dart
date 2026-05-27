/// Resolves a `localName` field that may be a plain [String] or a
/// localization [Map] (e.g. `{en: "Sink Fixtures", lang: "en", source: "Sink Fixtures"}`).
String resolveLocalName(Object? value) {
  if (value is String) return value;
  if (value is Map<String, dynamic>) {
    final lang = (value['lang'] as String?) ?? 'en';
    final byLang = value[lang];
    if (byLang is String && byLang.trim().isNotEmpty) return byLang.trim();
    final source = value['source'];
    if (source is String && source.trim().isNotEmpty) return source.trim();
    for (final v in value.values) {
      if (v is String && v.trim().isNotEmpty) return v.trim();
    }
  }
  return '';
}
