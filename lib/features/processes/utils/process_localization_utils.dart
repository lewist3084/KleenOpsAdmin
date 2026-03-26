class ProcessLocalizationUtils {
  ProcessLocalizationUtils._();

  static const String defaultLocaleCode = 'en';

  static String normalizeLocaleCode(String code) {
    return code.trim().toLowerCase().replaceAll('_', '-');
  }

  static String resolveLocalizedText(
    dynamic value, {
    required String localeCode,
    String fallbackLocaleCode = defaultLocaleCode,
  }) {
    if (value == null) return '';
    if (value is String) return value.trim();

    final normalized = normalizeLocalizedField(
      value,
      fallbackLocaleCode: fallbackLocaleCode,
    );
    if (normalized == null || normalized.isEmpty) return '';

    String? _attempt(String code) {
      final normalizedCode = normalizeLocaleCode(code);
      if (normalizedCode.isEmpty) return null;
      final raw = normalized[normalizedCode];
      if (raw is String) {
        final trimmed = raw.trim();
        if (trimmed.isNotEmpty) return trimmed;
      }
      return null;
    }

    final target = normalizeLocaleCode(localeCode);
    final fallback = normalizeLocaleCode(fallbackLocaleCode);
    final detectedRaw = _asTrimmedString(normalized['lang']);
    final detected =
        detectedRaw != null ? normalizeLocaleCode(detectedRaw) : null;

    for (final code in <String>[
      target,
      if (detected != null) detected,
      fallback,
    ]) {
      final candidate = _attempt(code);
      if (candidate != null) return candidate;
    }

    final source = _asTrimmedString(normalized['source']);
    if (source != null) return source;

    for (final entry in normalized.entries) {
      final val = entry.value;
      if (val is String) {
        final trimmed = val.trim();
        if (trimmed.isNotEmpty) return trimmed;
      }
    }

    return '';
  }

  static Map<String, dynamic>? normalizeLocalizedField(
    dynamic value, {
    String fallbackLocaleCode = defaultLocaleCode,
  }) {
    if (value == null) return null;

    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) return null;
      final fallback = normalizeLocaleCode(fallbackLocaleCode);
      return <String, dynamic>{
        'source': trimmed,
        'lang': fallback,
        fallback: trimmed,
      };
    }

    if (value is Map) {
      final normalized = <String, dynamic>{};
      final sourceMetaKeys = <String>{
        'source',
        'sourcetext',
        'source_text',
      };
      final langMetaKeys = <String>{
        'lang',
        'language',
        'sourcelang',
        'source_language',
      };

      void captureTranslation(String key, dynamic raw) {
        final text = _asTrimmedString(raw);
        if (text == null) return;
        final localeKey = normalizeLocaleCode(key);
        if (localeKey.isEmpty) return;
        normalized[localeKey] = text;
      }

      for (final entry in value.entries) {
        final key = entry.key.toString();
        final loweredKey = key.toLowerCase();
        final raw = entry.value;
        if (sourceMetaKeys.contains(loweredKey)) {
          final source = _asTrimmedString(raw);
          if (source != null) normalized['source'] = source;
          continue;
        }

        if (langMetaKeys.contains(loweredKey)) {
          final lang = _asTrimmedString(raw);
          if (lang != null) {
            final normalizedLang = normalizeLocaleCode(lang);
            if (normalizedLang.isNotEmpty) {
              normalized['lang'] = normalizedLang;
            }
          }
          continue;
        }

        if (loweredKey == 'values' || loweredKey == 'translations') {
          if (raw is Map) {
            for (final nested in raw.entries) {
              captureTranslation(nested.key.toString(), nested.value);
            }
          }
          continue;
        }

        captureTranslation(key, raw);
      }

      if (!normalized.containsKey('lang')) {
        final fallback = normalizeLocaleCode(fallbackLocaleCode);
        if (fallback.isNotEmpty) {
          normalized['lang'] = fallback;
        }
      }

      return normalized.isEmpty ? null : normalized;
    }

    return null;
  }

  static Map<String, dynamic> buildLocalizedFieldPayload({
    required String source,
    required String sourceLanguage,
    required Map<String, String> translations,
    String fallbackLocaleCode = defaultLocaleCode,
  }) {
    final payload = <String, dynamic>{};

    final trimmedSource = source.trim();
    final langCode = normalizeLocaleCode(sourceLanguage);

    if (trimmedSource.isNotEmpty) {
      payload['source'] = trimmedSource;
    }
    if (langCode.isNotEmpty) {
      payload['lang'] = langCode;
    }

    void put(String code, String text) {
      final normalizedCode = normalizeLocaleCode(code);
      if (normalizedCode.isEmpty) return;
      final trimmed = text.trim();
      if (trimmed.isEmpty) return;
      payload[normalizedCode] = trimmed;
    }

    translations.forEach((key, value) {
      if (key.isEmpty) return;
      put(key, value);
    });

    if (trimmedSource.isNotEmpty) {
      final primaryKey = langCode.isNotEmpty
          ? langCode
          : normalizeLocaleCode(fallbackLocaleCode);
      if (!payload.containsKey(primaryKey)) {
        put(primaryKey, trimmedSource);
      }
    }

    final normalizedFallback = normalizeLocaleCode(fallbackLocaleCode);
    if (normalizedFallback.isNotEmpty &&
        !payload.containsKey(normalizedFallback)) {
      final fallbackTranslation = translations[fallbackLocaleCode] ??
          translations[normalizedFallback];
      if (fallbackTranslation != null && fallbackTranslation.trim().isNotEmpty) {
        put(normalizedFallback, fallbackTranslation);
      } else if (trimmedSource.isNotEmpty && langCode != normalizedFallback) {
        put(normalizedFallback, trimmedSource);
      }
    }

    return payload;
  }

  static bool hasLocaleValueChanged({
    required String candidate,
    Map<String, dynamic>? existingField,
    required String localeCode,
    String fallbackLocaleCode = defaultLocaleCode,
  }) {
    final normalizedCandidate = candidate.trim();
    final existingValue = resolveLocalizedText(
      existingField,
      localeCode: localeCode,
      fallbackLocaleCode: fallbackLocaleCode,
    ).trim();
    return normalizedCandidate != existingValue;
  }

  static String? _asTrimmedString(dynamic value) {
    if (value is String) {
      final trimmed = value.trim();
      return trimmed.isEmpty ? null : trimmed;
    }
    return null;
  }
}
