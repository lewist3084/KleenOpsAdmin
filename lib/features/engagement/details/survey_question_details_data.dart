// lib/features/requests/details/survey_question_details_data.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_widgets/tiles/rating_survey_tile.dart';
import 'package:shared_widgets/tiles/signup_survey_tile.dart';

const String _kDefaultNpsLowLabel = 'Not at all likely';
const String _kDefaultNpsHighLabel = 'Extremely likely';

class SurveyQuestionDetailsData {
  SurveyQuestionDetailsData({
    required this.id,
    required this.prompt,
    required this.helpText,
    required this.order,
    required this.isRequired,
    required this.allowMultiple,
    required this.allowOther,
    required this.shuffleOptions,
    required this.options,
    required this.likertStatements,
    required this.likertScale,
    required this.ratingMin,
    required this.ratingMax,
    required this.ratingVisual,
    required this.isLongAnswer,
    required this.includeTime,
    required this.commentEnabled,
    required this.npsLowLabel,
    required this.npsHighLabel,
    required this.signupOrganizations,
    required this.signupSlots,
  });

  final String id;
  final String prompt;
  final String? helpText;
  final int? order;
  final bool isRequired;
  final bool allowMultiple;
  final bool allowOther;
  final bool shuffleOptions;
  final List<String> options;
  final List<String> likertStatements;
  final List<String> likertScale;
  final int ratingMin;
  final int ratingMax;
  final SurveyRatingVisual ratingVisual;
  final bool isLongAnswer;
  final bool includeTime;
  final bool commentEnabled;
  final String? npsLowLabel;
  final String? npsHighLabel;
  final List<String> signupOrganizations;
  final List<SignupSurveySlot> signupSlots;

  String get displayPrompt => prompt.isNotEmpty ? prompt : id;

  List<String> get displayOptions => options.isNotEmpty
      ? options
      : const ['Option 1', 'Option 2'];

  List<String> get displayRankingItems => options.isNotEmpty
      ? options
      : const ['Item 1', 'Item 2', 'Item 3'];

  List<String> get displayLikertStatements => likertStatements.isNotEmpty
      ? likertStatements
      : const ['Statement 1', 'Statement 2'];

  List<String> get displayLikertScale => likertScale.isNotEmpty
      ? likertScale
      : const ['Option 1', 'Option 2', 'Option 3'];

  String get displayNpsLowLabel =>
      (npsLowLabel != null && npsLowLabel!.trim().isNotEmpty)
          ? npsLowLabel!.trim()
          : _kDefaultNpsLowLabel;

  String get displayNpsHighLabel =>
      (npsHighLabel != null && npsHighLabel!.trim().isNotEmpty)
          ? npsHighLabel!.trim()
          : _kDefaultNpsHighLabel;

  factory SurveyQuestionDetailsData.fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? <String, dynamic>{};
    return SurveyQuestionDetailsData.fromData(data, snapshot.id);
  }

  factory SurveyQuestionDetailsData.fromData(
    Map<String, dynamic> data,
    String id,
  ) {
    final prompt = _readString(data, const ['prompt', 'question']);
    final help = _readString(data, const ['helpText']);
    final helpText = help.isEmpty ? null : help;
    final options = _readStringList(data['options']);
    final likertStatements = _readStringList(data['likertStatements']);
    final likertScale = _readLikertScale(data, options);
    final ratingMin = _readInt(data['ratingMin']) ?? 1;
    final ratingMax = _readInt(data['ratingMax']) ?? 5;
    final ratingVisual =
        SurveyRatingVisual.fromId(data['ratingVisual'] as String?);
    final npsLowLabel = _readString(data, const ['npsLowLabel']);
    final npsHighLabel = _readString(data, const ['npsHighLabel']);
    final isRequired = data['required'] != false;
    final allowMultiple = data['allowMultiple'] == true;
    final allowOther = data['allowOther'] == true;
    final shuffleOptions = data['shuffleOptions'] == true;
    final isLongAnswer = data['longAnswer'] == true;
    final includeTime = data['includeTime'] == true;
    final commentEnabled = data['commentEnabled'] == true;
    final signupOrganizations = _readStringList(data['signupOrganizations']);
    final signupSlots = _readSignupSlots(data);
    final order = _readInt(data['order']);

    return SurveyQuestionDetailsData(
      id: id,
      prompt: prompt,
      helpText: helpText,
      order: order,
      isRequired: isRequired,
      allowMultiple: allowMultiple,
      allowOther: allowOther,
      shuffleOptions: shuffleOptions,
      options: options,
      likertStatements: likertStatements,
      likertScale: likertScale,
      ratingMin: ratingMin,
      ratingMax: ratingMax,
      ratingVisual: ratingVisual,
      isLongAnswer: isLongAnswer,
      includeTime: includeTime,
      commentEnabled: commentEnabled,
      npsLowLabel: npsLowLabel.isEmpty ? null : npsLowLabel,
      npsHighLabel: npsHighLabel.isEmpty ? null : npsHighLabel,
      signupOrganizations: signupOrganizations,
      signupSlots: signupSlots,
    );
  }
}

String _readString(
  Map<String, dynamic> data,
  List<String> keys, {
  String fallback = '',
}) {
  for (final key in keys) {
    final raw = data[key];
    if (raw is String && raw.trim().isNotEmpty) {
      return raw.trim();
    }
  }
  return fallback;
}

List<String> _readStringList(dynamic raw) {
  if (raw is Iterable) {
    return raw
        .whereType<String>()
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList();
  }
  return const <String>[];
}

List<String> _readLikertScale(
  Map<String, dynamic>? data,
  List<String>? fallback,
) {
  if (data == null) {
    return fallback ?? const <String>[];
  }
  final scale = _readStringList(data['likertScale']);
  if (scale.isNotEmpty) {
    return scale;
  }
  if (fallback != null && fallback.isNotEmpty) {
    return fallback;
  }
  return const <String>[];
}

List<SignupSurveySlot> _readSignupSlots(Map<String, dynamic>? data) {
  if (data == null) return const <SignupSurveySlot>[];
  final raw = data['signupSlots'];
  if (raw is! Iterable) return const <SignupSurveySlot>[];

  String? readString(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final value = map[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return null;
  }

  List<String> readParticipants(Map<String, dynamic> map) {
    final raw = map['signups'] ?? map['participants'] ?? map['roster'];
    if (raw is! Iterable) return const <String>[];
    final names = <String>[];
    for (final entry in raw) {
      if (entry is String && entry.trim().isNotEmpty) {
        names.add(entry.trim());
        continue;
      }
      if (entry is Map) {
        final display = readString(
          Map<String, dynamic>.from(
            entry.map((key, value) => MapEntry(key.toString(), value)),
          ),
          const ['displayName', 'name', 'fullName'],
        );
        if (display != null && display.isNotEmpty) {
          names.add(display);
        }
      }
    }
    return names;
  }

  final slots = <SignupSurveySlot>[];
  for (final entry in raw) {
    final map = _coerceMapEntry(entry);
    if (map == null) continue;
    final id = readString(map, const ['id', 'slotId', 'key']) ??
        'slot_${slots.length + 1}';
    final startAt = _coerceDateTime(
      map['startAt'] ?? map['start'] ?? map['dateTime'],
    );
    final label = readString(map, const ['label', 'title', 'name']);
    final capacity = _readInt(map['needed']) ??
        _readInt(map['capacity']) ??
        _readInt(map['count']) ??
        0;
    final participants = readParticipants(map);
    final filled = _readInt(map['filled']) ??
        _readInt(map['filledCount']) ??
        _readInt(map['signedUp']) ??
        0;
    final filledCount = participants.length > filled ? participants.length : filled;
    slots.add(
      SignupSurveySlot(
        id: id,
        startAt: startAt,
        label: label,
        capacity: capacity < 0 ? 0 : capacity,
        filled: filledCount < 0 ? 0 : filledCount,
        participants: participants,
      ),
    );
  }
  return slots;
}

Map<String, dynamic>? _coerceMapEntry(dynamic entry) {
  if (entry is Map<String, dynamic>) {
    return Map<String, dynamic>.from(entry);
  }
  if (entry is Map) {
    return Map<String, dynamic>.from(
      entry.map(
        (key, value) => MapEntry(key.toString(), value),
      ),
    );
  }
  return null;
}

int? _readInt(dynamic raw) {
  if (raw is int) return raw;
  if (raw is num) return raw.toInt();
  if (raw is String) {
    final parsed = int.tryParse(raw.trim());
    if (parsed != null) return parsed;
  }
  return null;
}

DateTime? _coerceDateTime(dynamic raw) {
  if (raw is DateTime) return raw;
  if (raw is Timestamp) return raw.toDate();
  if (raw is String) {
    return DateTime.tryParse(raw.trim());
  }
  return null;
}
