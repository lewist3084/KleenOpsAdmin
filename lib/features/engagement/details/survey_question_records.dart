// lib/features/requests/details/survey_question_records.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_widgets/dialogs/dialog_action.dart';
import 'package:shared_widgets/lists/standardViewGroup.dart';
import 'package:kleenops_admin/common/utils/snackbar_service.dart';

const String _kRequestResponseType = 'request_response';

const Map<String, String> _kindLabels = {
  'choice': 'Choice',
  'text': 'Text',
  'video': 'Video Response',
  'rating': 'Rating',
  'date': 'Date',
  'ranking': 'Ranking',
  'likert': 'Likert',
  'nps': 'Net Promoter Score',
  'signup': 'Volunteer Signup',
  'section': 'Section Break',
};

class SurveyQuestionRecordsTab extends StatelessWidget {
  const SurveyQuestionRecordsTab({
    super.key,
    required this.userRef,
    required this.requestId,
    required this.questionId,
  });

  final DocumentReference<Map<String, dynamic>>? userRef;
  final String requestId;
  final String questionId;

  @override
  Widget build(BuildContext context) {
    final ref = userRef;
    if (ref == null) {
      return _buildStatusMessage(
        context,
        message: 'Unable to load responses for this question.',
      );
    }

    final timelineQuery = ref
        .collection('timeline')
        .where('requestId', isEqualTo: requestId)
        .where('questionId', isEqualTo: questionId);

    return StandardViewGroup(
      queryStream: timelineQuery.snapshots(),
      groupBy: (_) => null,
      disableGrouping: true,
      emptyMessage: 'No responses recorded yet.',
      padding: EdgeInsets.zero,
      showDividersInFlat: true,
      itemFilter: _isRequestResponseDoc,
      itemSort: _compareResponseDocs,
      itemBuilder: (doc) => _buildResponseRecordTile(context, doc),
      itemKey: (doc) => ValueKey(doc.id),
      onSwipeRight: (doc) => _confirmDeleteResponse(context, doc),
      leftSwipeBackground: Container(
        color: Colors.red[700],
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 16),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.delete_outline, color: Colors.white),
            SizedBox(width: 8),
            Text(
              'Delete',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

Widget _buildStatusMessage(
  BuildContext context, {
  required String message,
  Color? color,
}) {
  final theme = Theme.of(context);
  return Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: color ?? theme.textTheme.bodyMedium?.color,
        ),
      ),
    ),
  );
}

bool _isRequestResponseDoc(
  QueryDocumentSnapshot<Map<String, dynamic>> doc,
) {
  final data = doc.data();
  final type = data['type'];
  if (type is String && type.isNotEmpty) {
    return type == _kRequestResponseType;
  }
  final category = data['timelineCategory'];
  if (category is String && category.isNotEmpty) {
    return category == _kRequestResponseType;
  }
  return false;
}

int _compareResponseDocs(
  QueryDocumentSnapshot<Map<String, dynamic>> a,
  QueryDocumentSnapshot<Map<String, dynamic>> b,
) {
  final aTimestamp = _responseTimestampFor(a.data());
  final bTimestamp = _responseTimestampFor(b.data());
  if (aTimestamp == null && bTimestamp == null) return 0;
  if (aTimestamp == null) return 1;
  if (bTimestamp == null) return -1;
  return bTimestamp.compareTo(aTimestamp);
}

Widget _buildResponseRecordTile(
  BuildContext context,
  QueryDocumentSnapshot<Map<String, dynamic>> doc,
) {
  final data = doc.data();
  final kindLabel = _responseKindLabel(data);
  final timestamp = _responseTimestampFor(data);
  final timestampLabel = timestamp == null ? '' : _formatDateTime(timestamp);
  final metaLine = _buildResponseMetaLine(
    timestampLabel,
    kindLabel,
  );

  final theme = Theme.of(context);
  final isSignup = _isSignupRecord(data);
  if (isSignup) {
    final response = _coerceMapEntry(data['response']) ?? <String, dynamic>{};
    final name = _readString(
      response,
      const ['name', 'fullName', 'displayName'],
      fallback: _readString(data, const ['submitterName']),
    );
    final organization = _readString(
      response,
      const ['organization', 'org', 'organizationName', 'orgName'],
      fallback: _readString(data, const ['organizationName']),
    );
    final slotLabel = _readString(
      response,
      const ['slotLabel', 'slotName', 'slotTitle'],
    );
    final slotStartAt = _coerceDateTime(
      response['slotStartAt'] ?? response['slotStart'] ?? response['startAt'],
    );
    final slotText = slotLabel.isNotEmpty
        ? slotLabel
        : slotStartAt == null
            ? ''
            : _formatDateTime(slotStartAt);
    final phone = _readString(
      data,
      const ['reminderPhone', 'phone', 'mobile'],
    );
    final subtitleChildren = <Widget>[];
    if (organization.isNotEmpty) {
      subtitleChildren.add(
        Text('Organization: $organization', style: theme.textTheme.bodySmall),
      );
    }
    if (slotText.isNotEmpty) {
      if (subtitleChildren.isNotEmpty) {
        subtitleChildren.add(const SizedBox(height: 4));
      }
      subtitleChildren.add(
        Text('Time slot: $slotText', style: theme.textTheme.bodySmall),
      );
    }
    if (phone.isNotEmpty) {
      if (subtitleChildren.isNotEmpty) {
        subtitleChildren.add(const SizedBox(height: 4));
      }
      subtitleChildren.add(
        Text('Phone: $phone', style: theme.textTheme.bodySmall),
      );
    }
    if (metaLine.isNotEmpty) {
      if (subtitleChildren.isNotEmpty) {
        subtitleChildren.add(const SizedBox(height: 4));
      }
      subtitleChildren.add(
        Text(
          metaLine,
          style: theme.textTheme.bodySmall?.copyWith(
            color: Colors.grey[600],
          ),
        ),
      );
    }

    return ListTile(
      title: Text(name.isEmpty ? 'Volunteer signup' : name),
      subtitle: subtitleChildren.isEmpty
          ? null
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: subtitleChildren,
            ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 4,
      ),
    );
  }

  final responseText = _formatResponseValue(data);
  final comment = _readString(data, const ['responseComment', 'comment']);
  final responseLabel =
      responseText.isEmpty ? 'No response value recorded.' : responseText;

  final subtitleChildren = <Widget>[];
  if (comment.isNotEmpty) {
    subtitleChildren.add(
      Text(
        'Comment: $comment',
        style: theme.textTheme.bodySmall,
      ),
    );
  }
  if (metaLine.isNotEmpty) {
    if (subtitleChildren.isNotEmpty) {
      subtitleChildren.add(const SizedBox(height: 4));
    }
    subtitleChildren.add(
      Text(
        metaLine,
        style: theme.textTheme.bodySmall?.copyWith(
          color: Colors.grey[600],
        ),
      ),
    );
  }

  return ListTile(
    title: Text(responseLabel),
    subtitle: subtitleChildren.isEmpty
        ? null
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: subtitleChildren,
          ),
    contentPadding: const EdgeInsets.symmetric(
      horizontal: 16,
      vertical: 4,
    ),
  );
}

String _responseKindLabel(Map<String, dynamic> data) {
  final kindId = _readString(data, const ['responseKind', 'kind']);
  if (kindId.isEmpty) return '';
  return _kindLabels[kindId] ?? kindId;
}

DateTime? _responseTimestampFor(Map<String, dynamic> data) {
  return _coerceDateTime(
    data['submittedAt'] ?? data['timestamp'] ?? data['createdAt'],
  );
}

String _buildResponseMetaLine(String timestampLabel, String kindLabel) {
  final parts = <String>[];
  if (timestampLabel.isNotEmpty) {
    parts.add(timestampLabel);
  }
  if (kindLabel.isNotEmpty) {
    parts.add(kindLabel);
  }
  return parts.join(' | ');
}

String _formatResponseValue(Map<String, dynamic> data) {
  final responseText = _readString(
    data,
    const ['responseText'],
  );
  if (responseText.isNotEmpty) return responseText;

  final options = _coerceResponseList(data['responseOptions']);
  if (options.isNotEmpty) return options.join(', ');

  final ranked = _coerceResponseList(data['responseRanked']);
  if (ranked.isNotEmpty) return ranked.join(', ');

  final number = data['responseNumber'] ?? data['responseScore'];
  if (number is num) return number.toString();

  final responseDate = _coerceDateTime(data['responseDate']);
  if (responseDate != null) return _formatDateTime(responseDate);

  final responseDateText = _readString(
    data,
    const ['responseDateText'],
  );
  if (responseDateText.isNotEmpty) return responseDateText;

  final videoUrl = _readString(
    data,
    const ['responseVideoUrl'],
  );
  if (videoUrl.isNotEmpty) return 'Video: $videoUrl';

  final raw = data['response'];
  if (raw != null) {
    return _formatResponseRaw(raw);
  }

  return '';
}

List<String> _coerceResponseList(dynamic raw) {
  if (raw is Iterable) {
    return raw
        .map(
          (value) => value == null ? '' : value.toString().trim(),
        )
        .where(
          (value) => value.isNotEmpty && value.toLowerCase() != 'null',
        )
        .toList();
  }
  return const <String>[];
}

String _formatResponseRaw(dynamic raw) {
  if (raw is Map) {
    final parts = <String>[];
    raw.forEach((key, value) {
      if (value == null) return;
      final stringKey = key.toString();
      final formatted = _formatResponseValuePart(value);
      if (formatted.isEmpty) return;
      parts.add('$stringKey: $formatted');
    });
    if (parts.isNotEmpty) {
      return parts.join(', ');
    }
  }
  if (raw is Iterable) {
    final items = _coerceResponseList(raw);
    if (items.isNotEmpty) return items.join(', ');
  }
  return raw.toString();
}

String _formatResponseValuePart(dynamic value) {
  if (value is Timestamp) {
    return _formatDateTime(value.toDate());
  }
  if (value is DateTime) {
    return _formatDateTime(value);
  }
  return value.toString();
}

String _formatDateTime(DateTime value) {
  final local = value.toLocal();
  final year = local.year.toString().padLeft(4, '0');
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$year-$month-$day $hour:$minute';
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

Map<String, dynamic>? _coerceMapEntry(dynamic raw) {
  if (raw is Map<String, dynamic>) {
    return Map<String, dynamic>.from(raw);
  }
  if (raw is Map) {
    return Map<String, dynamic>.from(
      raw.map(
        (key, value) => MapEntry(key.toString(), value),
      ),
    );
  }
  return null;
}

bool _isSignupRecord(Map<String, dynamic> data) {
  final kind = _readString(data, const ['responseKind', 'kind']);
  if (kind == 'signup') return true;
  final response = _coerceMapEntry(data['response']);
  if (response == null) return false;
  if (_readString(response, const ['slotId', 'slot']).isNotEmpty) {
    return true;
  }
  if (_readString(
    response,
    const ['slotLabel', 'slotName', 'slotTitle'],
  ).isNotEmpty) {
    return true;
  }
  return response['slotStartAt'] != null ||
      response['slotStart'] != null ||
      response['startAt'] != null;
}

Future<void> _confirmDeleteResponse(
  BuildContext context,
  QueryDocumentSnapshot<Map<String, dynamic>> doc,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return DialogAction(
        title: 'Delete response?',
        content: const Text(
          'This will permanently remove the response. You can undo for a short time.',
        ),
        cancelText: 'Cancel',
        onCancel: () => Navigator.of(dialogContext).pop(false),
        actionText: 'Delete',
        onAction: () => Navigator.of(dialogContext).pop(true),
      );
    },
  );

  if (confirmed != true) return;

  final data = Map<String, dynamic>.from(doc.data());
  _SignupSlotUpdate? signupUpdate;
  try {
    signupUpdate = await _buildSignupSlotUpdate(doc);
    if (signupUpdate != null) {
      final batch = doc.reference.firestore.batch();
      batch.update(
        signupUpdate.questionRef,
        {'signupSlots': signupUpdate.updatedSlots},
      );
      batch.delete(doc.reference);
      await batch.commit();
    } else {
      await doc.reference.delete();
    }
  } catch (_) {
    if (!context.mounted) return;
    SnackbarService.instance.showSnackBar(
      const SnackBar(
        duration: Duration(seconds: 5),
        content: Text('Unable to delete the response.'),
      ),
    );
    return;
  }

  if (!context.mounted) return;
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  SnackbarService.instance.showSnackBar(
    SnackBar(
      content: const Text('Response deleted.'),
      duration: const Duration(seconds: 5),
      action: SnackBarAction(
        label: 'Undo',
        onPressed: () async {
          try {
            if (signupUpdate != null) {
              final batch = doc.reference.firestore.batch();
              batch.set(doc.reference, data);
              batch.update(
                signupUpdate.questionRef,
                {'signupSlots': signupUpdate.previousSlots},
              );
              await batch.commit();
            } else {
              await doc.reference.set(data);
            }
          } catch (_) {
            if (!context.mounted) return;
            SnackbarService.instance.showSnackBar(
              const SnackBar(
                duration: Duration(seconds: 5),
                content: Text('Unable to restore the response.'),
              ),
            );
          }
        },
      ),
    ),
  );
}

class _SignupSlotUpdate {
  const _SignupSlotUpdate({
    required this.questionRef,
    required this.previousSlots,
    required this.updatedSlots,
  });

  final DocumentReference<Map<String, dynamic>> questionRef;
  final List<dynamic> previousSlots;
  final List<dynamic> updatedSlots;
}

class _SlotRosterUpdate {
  const _SlotRosterUpdate({
    required this.slot,
    required this.changed,
  });

  final Map<String, dynamic> slot;
  final bool changed;
}

class _ListRemoval {
  const _ListRemoval({
    required this.items,
    required this.changed,
    required this.beforeLength,
  });

  final List<dynamic> items;
  final bool changed;
  final int beforeLength;
}

Future<_SignupSlotUpdate?> _buildSignupSlotUpdate(
  QueryDocumentSnapshot<Map<String, dynamic>> doc,
) async {
  final data = doc.data();
  if (!_isSignupRecord(data)) return null;

  final response = _coerceMapEntry(data['response']) ?? <String, dynamic>{};
  final slotId = _readString(
    response,
    const ['slotId', 'slot'],
    fallback: _readString(data, const ['slotId', 'slot']),
  );
  final slotLabel = _readString(
    response,
    const ['slotLabel', 'slotName', 'slotTitle'],
    fallback: _readString(data, const ['slotLabel', 'slotName', 'slotTitle']),
  );
  final name = _readString(
    response,
    const ['name', 'fullName', 'displayName'],
    fallback: _readString(data, const ['submitterName']),
  );
  final organization = _readString(
    response,
    const ['organization', 'org', 'organizationName', 'orgName'],
    fallback: _readString(data, const ['organizationName', 'organization']),
  );
  final matchKeys = _buildSignupMatchKeys(name, organization);
  if (matchKeys.isEmpty) return null;

  final questionRef = _questionRefFrom(data);
  if (questionRef == null) return null;

  final snapshot = await questionRef.get();
  if (!snapshot.exists) return null;
  final questionData = snapshot.data() ?? <String, dynamic>{};
  final rawSlots = questionData['signupSlots'];
  if (rawSlots is! Iterable) return null;

  final previousSlots = _cloneSlotList(rawSlots);
  final updatedSlots = <dynamic>[];
  var changed = false;

  for (final entry in rawSlots) {
    final slotMap = _coerceMapEntry(entry);
    if (slotMap == null) {
      updatedSlots.add(entry);
      continue;
    }
    final slotIdValue = _readString(
      slotMap,
      const ['id', 'slotId', 'key'],
    );
    final slotLabelValue = _readString(
      slotMap,
      const ['label', 'title', 'name'],
    );
    final matchesSlot = slotId.isNotEmpty
        ? slotIdValue == slotId
        : slotLabel.isNotEmpty && slotLabelValue == slotLabel;
    if (!matchesSlot) {
      updatedSlots.add(entry);
      continue;
    }

    final updated = _removeSignupFromSlot(slotMap, matchKeys);
    if (updated.changed) {
      changed = true;
      updatedSlots.add(updated.slot);
    } else {
      updatedSlots.add(entry);
    }
  }

  if (!changed) return null;
  return _SignupSlotUpdate(
    questionRef: questionRef,
    previousSlots: previousSlots,
    updatedSlots: updatedSlots,
  );
}

_SlotRosterUpdate _removeSignupFromSlot(
  Map<String, dynamic> slot,
  Set<String> matchKeys,
) {
  final updated = Map<String, dynamic>.from(slot);
  var changed = false;

  const listKeys = ['signups', 'participants', 'roster'];
  final primaryKey = _firstExistingListKey(updated, listKeys);
  int? primaryBefore;
  int? primaryAfter;
  if (primaryKey != null) {
    final removal = _removeSignupFromList(updated[primaryKey], matchKeys);
    if (removal.changed) {
      updated[primaryKey] = removal.items;
      changed = true;
      primaryBefore = removal.beforeLength;
      primaryAfter = removal.items.length;
    }
  }

  for (final key in listKeys) {
    if (key == primaryKey) continue;
    if (updated[key] is! Iterable) continue;
    final removal = _removeSignupFromList(updated[key], matchKeys);
    if (removal.changed) {
      updated[key] = removal.items;
      changed = true;
    }
  }

  if (changed &&
      primaryKey != null &&
      primaryBefore != null &&
      primaryAfter != null) {
    final filledKey =
        _firstExistingKey(updated, const ['filled', 'filledCount', 'signedUp']);
    if (filledKey != null) {
      final filledValue = _readInt(updated[filledKey]);
      if (filledValue != null && filledValue == primaryBefore) {
        updated[filledKey] = primaryAfter;
      }
    }
  }

  return _SlotRosterUpdate(slot: updated, changed: changed);
}

_ListRemoval _removeSignupFromList(dynamic raw, Set<String> matchKeys) {
  if (raw is! Iterable) {
    return const _ListRemoval(
      items: <dynamic>[],
      changed: false,
      beforeLength: 0,
    );
  }
  final items = <dynamic>[];
  var removed = false;
  for (final entry in raw) {
    if (!removed && _matchesSignupEntry(entry, matchKeys)) {
      removed = true;
      continue;
    }
    items.add(entry);
  }
  return _ListRemoval(
    items: items,
    changed: removed,
    beforeLength: raw.length,
  );
}

bool _matchesSignupEntry(dynamic entry, Set<String> matchKeys) {
  if (matchKeys.isEmpty) return false;
  if (entry is String) {
    return matchKeys.contains(_normalizeSignupLabel(entry));
  }
  final map = _coerceMapEntry(entry);
  if (map == null) return false;
  final name = _readString(map, const ['displayName', 'name', 'fullName']);
  final organization = _readString(
    map,
    const ['organization', 'org', 'organizationName', 'orgName'],
  );
  final rosterName = _formatSignupRosterEntry(name, organization);
  final normalizedName = _normalizeSignupLabel(name);
  if (normalizedName.isNotEmpty && matchKeys.contains(normalizedName)) {
    return true;
  }
  final normalizedRoster = _normalizeSignupLabel(rosterName);
  if (normalizedRoster.isNotEmpty && matchKeys.contains(normalizedRoster)) {
    return true;
  }
  return false;
}

Set<String> _buildSignupMatchKeys(String name, String organization) {
  final keys = <String>{};
  final trimmedName = name.trim();
  if (trimmedName.isNotEmpty) {
    keys.add(_normalizeSignupLabel(trimmedName));
  }
  final trimmedOrg = organization.trim();
  if (trimmedName.isNotEmpty && trimmedOrg.isNotEmpty) {
    keys.add(_normalizeSignupLabel('$trimmedName - $trimmedOrg'));
  }
  return keys;
}

String _normalizeSignupLabel(String value) {
  return value.trim().toLowerCase();
}

String _formatSignupRosterEntry(String? displayName, String? organization) {
  final name = displayName?.trim() ?? '';
  if (name.isEmpty) return '';
  final org = organization?.trim() ?? '';
  if (org.isEmpty) return name;
  return '$name - $org';
}

String? _firstExistingListKey(
  Map<String, dynamic> data,
  List<String> keys,
) {
  for (final key in keys) {
    if (data[key] is Iterable) return key;
  }
  return null;
}

String? _firstExistingKey(
  Map<String, dynamic> data,
  List<String> keys,
) {
  for (final key in keys) {
    if (data.containsKey(key)) return key;
  }
  return null;
}

List<dynamic> _cloneSlotList(Iterable raw) {
  final copied = <dynamic>[];
  for (final entry in raw) {
    if (entry is Map) {
      copied.add(
        entry.map((key, value) => MapEntry(key.toString(), value)),
      );
    } else {
      copied.add(entry);
    }
  }
  return copied;
}

DocumentReference<Map<String, dynamic>>? _questionRefFrom(
  Map<String, dynamic> data,
) {
  final rawQuestionRef = data['questionRef'];
  if (rawQuestionRef is DocumentReference<Map<String, dynamic>>) {
    return rawQuestionRef;
  }
  if (rawQuestionRef is DocumentReference) {
    return rawQuestionRef.firestore
        .doc(rawQuestionRef.path)
        .withConverter<Map<String, dynamic>>(
          fromFirestore: (s, _) => s.data() ?? <String, dynamic>{},
          toFirestore: (m, _) => m,
        );
  }

  final questionId = _readString(data, const ['questionId']);
  if (questionId.isEmpty) return null;

  DocumentReference? requestRef;
  final rawRequestRef = data['requestRef'];
  if (rawRequestRef is DocumentReference) {
    requestRef = rawRequestRef;
  } else {
    final rawUserRef = data['userRef'];
    final requestId = _readString(data, const ['requestId']);
    if (rawUserRef is DocumentReference && requestId.isNotEmpty) {
      requestRef = rawUserRef.collection('request').doc(requestId);
    }
  }

  if (requestRef == null) return null;
  return requestRef.firestore
      .doc('${requestRef.path}/requestItem/$questionId')
      .withConverter<Map<String, dynamic>>(
        fromFirestore: (s, _) => s.data() ?? <String, dynamic>{},
        toFirestore: (m, _) => m,
      );
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
