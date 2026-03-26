import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Normalized contact entry with a single `main` flag.
class ContactEntry {
  const ContactEntry({required this.value, this.main = false});

  final String value;
  final bool main;

  ContactEntry copyWith({String? value, bool? main}) =>
      ContactEntry(value: value ?? this.value, main: main ?? this.main);
}

/// Bundle of phone and email entries extracted from a Firestore document.
class ContactInfo {
  const ContactInfo({required this.phones, required this.emails});

  final List<ContactEntry> phones;
  final List<ContactEntry> emails;

  ContactEntry? get primaryPhone => _primary(phones);
  ContactEntry? get primaryEmail => _primary(emails);

  static ContactEntry? _primary(List<ContactEntry> entries) {
    if (entries.isEmpty) return null;
    final idx = entries.indexWhere((e) => e.main);
    return idx >= 0 ? entries[idx] : entries.first;
  }
}

/// Parse and normalize phone/email lists from a document map.
ContactInfo parseContactInfo(Map<String, dynamic> data) {
  final phones = _parseContactEntries(
    data['phoneNumbers'],
    valueKey: 'number',
    fallbackValue: data['phoneNumber'] as String?,
  );
  final emails = _parseContactEntries(
    data['emails'],
    valueKey: 'email',
    fallbackValue: data['email'] as String?,
  );
  return ContactInfo(phones: phones, emails: emails);
}

/// Ensure phoneNumbers/emails arrays exist (and have a single main) based on the
/// provided data. Will also backfill legacy string fields if requested.
Future<void> migrateContactFieldsIfNeeded({
  required DocumentReference<Map<String, dynamic>> docRef,
  required Map<String, dynamic> data,
  bool includeLegacyStrings = true,
}) async {
  final desired = parseContactInfo(data);

  final desiredPhoneMaps =
      _entriesToMaps(desired.phones, valueKey: 'number', keepEmpty: false);
  final desiredEmailMaps =
      _entriesToMaps(desired.emails, valueKey: 'email', keepEmpty: false);

  final currentPhoneMaps = _entriesToMaps(
    _parseContactEntries(
      data['phoneNumbers'],
      valueKey: 'number',
      fallbackValue: null,
      enforceMain: false,
    ),
    valueKey: 'number',
    keepEmpty: true,
  );
  final currentEmailMaps = _entriesToMaps(
    _parseContactEntries(
      data['emails'],
      valueKey: 'email',
      fallbackValue: null,
      enforceMain: false,
    ),
    valueKey: 'email',
    keepEmpty: true,
  );

  final updates = <String, dynamic>{};
  if (desiredPhoneMaps.isNotEmpty &&
      !_mapsListEquals(currentPhoneMaps, desiredPhoneMaps)) {
    updates['phoneNumbers'] = desiredPhoneMaps;
  }
  if (desiredEmailMaps.isNotEmpty &&
      !_mapsListEquals(currentEmailMaps, desiredEmailMaps)) {
    updates['emails'] = desiredEmailMaps;
  }

  if (includeLegacyStrings) {
    final mainPhone = desired.primaryPhone?.value;
    final mainEmail = desired.primaryEmail?.value;
    if (mainPhone != null && mainPhone != data['phoneNumber']) {
      updates['phoneNumber'] = mainPhone;
    }
    if (mainEmail != null && mainEmail != data['email']) {
      updates['email'] = mainEmail;
    }
  }

  if (updates.isNotEmpty) {
    await docRef.update(updates);
  }
}

List<ContactEntry> _parseContactEntries(
  dynamic raw, {
  required String valueKey,
  String? fallbackValue,
  bool enforceMain = true,
}) {
  final entries = <ContactEntry>[];

  if (raw is Iterable) {
    for (final item in raw) {
      if (item is String) {
        final v = item.trim();
        if (v.isNotEmpty) {
          entries.add(ContactEntry(value: v, main: false));
        }
        continue;
      }
      if (item is Map) {
        final map = Map<String, dynamic>.from(item);
        final value =
            (map[valueKey] ?? map['value'] ?? map['number'] ?? map['email'])
                ?.toString()
                .trim();
        if (value == null || value.isEmpty) continue;
        final isMain = map['main'] == true || map['primary'] == true;
        entries.add(ContactEntry(value: value, main: isMain));
      }
    }
  }

  final fallback = fallbackValue?.trim();
  if (entries.isEmpty && fallback != null && fallback.isNotEmpty) {
    entries.add(ContactEntry(value: fallback, main: true));
  }

  if (enforceMain) {
    return _ensureSingleMain(entries);
  }
  return entries;
}

List<ContactEntry> _ensureSingleMain(List<ContactEntry> entries) {
  if (entries.isEmpty) return entries;
  final mainIdx = entries.indexWhere((e) => e.main);
  final primaryIndex = mainIdx >= 0 ? mainIdx : 0;

  return [
    for (var i = 0; i < entries.length; i++)
      entries[i].copyWith(main: i == primaryIndex)
  ];
}

List<Map<String, dynamic>> _entriesToMaps(
  List<ContactEntry> entries, {
  required String valueKey,
  required bool keepEmpty,
}) {
  if (entries.isEmpty && !keepEmpty) return const [];
  return entries
      .map((e) => {valueKey: e.value, 'main': e.main})
      .toList(growable: false);
}

bool _mapsListEquals(
  List<Map<String, dynamic>> a,
  List<Map<String, dynamic>> b,
) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    final mapA = a[i];
    final mapB = b[i];
    if (mapA.length != mapB.length) return false;
    for (final key in {...mapA.keys, ...mapB.keys}) {
      if (mapA[key] != mapB[key]) return false;
    }
  }
  return true;
}
