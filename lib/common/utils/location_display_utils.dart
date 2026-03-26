import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kleenops_admin/features/processes/utils/process_localization_utils.dart';

class LocationDisplayUtils {
  LocationDisplayUtils._();

  static String? _trimmedString(dynamic value) {
    if (value is String) {
      final trimmed = value.trim();
      return trimmed.isNotEmpty ? trimmed : null;
    }
    return null;
  }

  static String _concat(String name, String functionName) {
    final trimmedName = name.trim();
    final trimmedFunction = functionName.trim();
    if (trimmedName.isEmpty) return trimmedFunction;
    if (trimmedFunction.isEmpty) return trimmedName;
    return '$trimmedName - $trimmedFunction';
  }

  static String _resolveLocalizedText(
    dynamic value,
    String localeCode,
  ) {
    return ProcessLocalizationUtils.resolveLocalizedText(
      value,
      localeCode: localeCode,
      fallbackLocaleCode: ProcessLocalizationUtils.defaultLocaleCode,
    ).trim();
  }

  static String _resolveNameText(
    dynamic value,
    String localeCode,
  ) {
    final localized = _resolveLocalizedText(value, localeCode);
    if (localized.isNotEmpty) return localized;
    if (value is num) {
      final asText = value.toString().trim();
      return asText;
    }
    return _trimmedString(value) ?? '';
  }

  static String resolveConcatenatedName({
    required String localeCode,
    String? locationName,
    dynamic functionNameField,
    dynamic concatenatedNameField,
    String? fallbackName,
  }) {
    final baseName = (locationName ?? '').trim();
    final functionName = _resolveLocalizedText(functionNameField, localeCode);
    if (baseName.isNotEmpty) {
      final combined = _concat(baseName, functionName);
      if (combined.isNotEmpty) return combined;
    }

    final concatenated =
        _resolveLocalizedText(concatenatedNameField, localeCode);
    if (concatenated.isNotEmpty) return concatenated;

    if (baseName.isNotEmpty) return baseName;

    final fallback = (fallbackName ?? '').trim();
    if (fallback.isNotEmpty) return fallback;
    return functionName;
  }

  static String resolveConcatenatedNameFromData(
    Map<String, dynamic> data,
    String localeCode,
  ) {
    final isInventoryLike = data.containsKey('locationId');
    final locationNameField =
        data['locationName'] ?? (!isInventoryLike ? data['name'] : null);
    final locationName = _resolveNameText(locationNameField, localeCode);
    final functionNameField = data['locationFunctionName'] ??
        (!isInventoryLike ? data['functionName'] : null);
    final concatenatedNameField = data['locationConcatenatedName'] ??
        (!isInventoryLike
            ? (data['concatenatedName'] ?? data['ConcatenatedName'])
            : null);
    final fallbackName =
        !isInventoryLike ? _resolveNameText(data['name'], localeCode) : null;

    return resolveConcatenatedName(
      localeCode: localeCode,
      locationName: locationName,
      functionNameField: functionNameField,
      concatenatedNameField: concatenatedNameField,
      fallbackName: fallbackName,
    );
  }

  static Future<String> resolveConcatenatedNameFromRef({
    required DocumentReference<Map<String, dynamic>> locationRef,
    required String localeCode,
    Map<String, Map<String, dynamic>>? functionCache,
  }) async {
    final snap = await locationRef.get();
    if (!snap.exists) return locationRef.id;
    final data = snap.data() ?? <String, dynamic>{};

    final functionNameField =
        data['functionName'] ?? data['locationFunctionName'];
    if (functionNameField != null) {
      final resolved = resolveConcatenatedNameFromData(data, localeCode);
      if (resolved.isNotEmpty) return resolved;
    }

    final functionRef = data['functionId'];
    if (functionRef is DocumentReference<Map<String, dynamic>>) {
      Map<String, dynamic>? functionData =
          functionCache != null ? functionCache[functionRef.path] : null;
      if (functionData == null) {
        final functionSnap = await functionRef.get();
        if (functionSnap.exists) {
          functionData = functionSnap.data() ?? <String, dynamic>{};
          if (functionCache != null) {
            functionCache[functionRef.path] = functionData;
          }
        }
      }
      final functionName =
          _resolveLocalizedText(functionData?['name'], localeCode);
      final baseName = _resolveNameText(
        data['name'] ?? data['locationName'],
        localeCode,
      );
      if (functionName.isNotEmpty || baseName.isNotEmpty) {
        return _concat(baseName, functionName);
      }
    }

    final fallback = resolveConcatenatedNameFromData(data, localeCode);
    if (fallback.isNotEmpty) return fallback;
    final nameOnly = _resolveNameText(data['name'], localeCode);
    if (nameOnly.isNotEmpty) return nameOnly;
    return locationRef.id;
  }

  static Map<String, dynamic>? buildConcatenatedNamePayload({
    required String locationName,
    required dynamic functionNameField,
  }) {
    final trimmedName = locationName.trim();
    if (trimmedName.isEmpty) return null;
    final normalized = ProcessLocalizationUtils.normalizeLocalizedField(
      functionNameField,
      fallbackLocaleCode: ProcessLocalizationUtils.defaultLocaleCode,
    );
    if (normalized == null || normalized.isEmpty) return null;

    final translations = <String, String>{};
    final sourceLanguage = _trimmedString(normalized['lang']) ??
        ProcessLocalizationUtils.defaultLocaleCode;
    String? sourceValue = _trimmedString(normalized['source']);

    for (final entry in normalized.entries) {
      final key = entry.key.toString();
      if (key == 'source' || key == 'lang') continue;
      final value = entry.value;
      if (value is String) {
        final trimmed = value.trim();
        if (trimmed.isNotEmpty) {
          final normalizedKey =
              ProcessLocalizationUtils.normalizeLocaleCode(key);
          if (normalizedKey.isNotEmpty) {
            translations[normalizedKey] = _concat(trimmedName, trimmed);
          }
        }
      }
    }

    String sourceText = '';
    if (sourceValue != null && sourceValue.isNotEmpty) {
      sourceText = _concat(trimmedName, sourceValue);
    } else if (translations.containsKey(sourceLanguage)) {
      sourceText = translations[sourceLanguage]!;
    } else if (translations.isNotEmpty) {
      sourceText = translations.values.first;
    }

    if (translations.isEmpty && sourceText.isEmpty) return null;

    final normalizedSourceLang =
        ProcessLocalizationUtils.normalizeLocaleCode(sourceLanguage);
    final resolvedSourceLang = normalizedSourceLang.isNotEmpty
        ? normalizedSourceLang
        : ProcessLocalizationUtils.defaultLocaleCode;

    return ProcessLocalizationUtils.buildLocalizedFieldPayload(
      source: sourceText.isNotEmpty ? sourceText : trimmedName,
      sourceLanguage: resolvedSourceLang,
      translations: translations,
      fallbackLocaleCode: ProcessLocalizationUtils.defaultLocaleCode,
    );
  }
}
