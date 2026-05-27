import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kleenops_admin/features/tasks/providers/tasks_timeline_provider.dart';

List<dynamic> getBlackouts(dynamic v) {
  if (v == null) return const [];

  if (v is List) return v;

  if (v is Map && v['blackoutInterval'] != null) {
    final raw = v['blackoutInterval'];
    return raw is List ? raw : [raw];
  }

  // fallback: single Map
  if (v is Map<String, dynamic>) return [v];

  return const [];
}

int? _asInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

bool _asBool(dynamic value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    final normalized = value.trim().toLowerCase();
    if (normalized == 'true' || normalized == '1') return true;
    if (normalized == 'false' || normalized == '0') return false;
  }
  return false;
}

bool isInBlackout(Map<String, dynamic> task, DateTime now) {
  return getBlackouts(task['blackouts']).any((b) {
    final s = (b['startTime'] as Timestamp).toDate();
    final e = (b['endTime'] as Timestamp).toDate();
    // include startTime but exclude endTime
    return !now.isBefore(s) && now.isBefore(e);
  });
}

bool _isLastDayPriorityActive(Map<String, dynamic> task, DateTime now) {
  if (!_asBool(task['priorityOnLastDay'])) return false;
  if (_asBool(task['untilComplete']) == false) return false;

  DateTime? endTime = (task['endTimeExtended'] as Timestamp?)?.toDate();
  if (endTime == null) {
    final start = task['startTime'] as Timestamp?;
    final days = _asInt(task['daysUntilComplete']);
    if (start != null && days != null && days > 0) {
      endTime = start.toDate().add(Duration(days: days));
    }
  }
  if (endTime == null) return false;

  final lastDayStart = endTime.subtract(const Duration(hours: 24));
  return !now.isBefore(lastDayStart);
}

bool isPriorityActive(Map<String, dynamic> task, DateTime now) {
  final lastDayPriority = _isLastDayPriorityActive(task, now);
  if (task['priority'] != true) return lastDayPriority;
  final int? delay = _asInt(task['priorityDelay']);
  if (delay == null) return true;
  final start = (task['startTime'] as Timestamp).toDate();
  final delayedPriority = now.isAfter(start.add(Duration(minutes: delay)));
  return delayedPriority || lastDayPriority;
}

/// small 2-tuple helper
class Tuple2<A, B> {
  final A item1;
  final B item2;
  const Tuple2(this.item1, this.item2);
}

class TaskDataSnapshot {
  TaskDataSnapshot({
    required this.revision,
    required this.docs,
    required this.dataByDocId,
    required this.activeTrainingIdSet,
    required this.roleIdSet,
    required this.memberId,
    required this.eligible,
  });

  final int revision;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;
  final Map<String, Map<String, dynamic>> dataByDocId;

  /// Bare training IDs (last path segment) the user currently has active.
  /// Compared by id, not by path, so a task that stores `trainingId` as a
  /// DocumentReference, a full path string, or a bare id string all match.
  final Set<String> activeTrainingIdSet;
  final Set<String> roleIdSet;

  /// Bare member document id (memberRef.id), not the full member path.
  /// Same id-based comparison applies to `lockUser`.
  final String memberId;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> eligible;

  static TaskDataSnapshot build({
    required TaskTimelineSnapshot timeline,
    required Set<String> activeTrainingIdSet,
    required Set<String> roleIdSet,
    required String memberId,
  }) {
    final eligible = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
    for (final doc in timeline.docs) {
      final data = timeline.dataByDocId[doc.id];
      if (data == null) continue;
      final requiredTrainingIds = _trainingIds(
        data['trainingId'] ?? data['trainingIds'] ?? data['training'],
      );
      var lacksTraining = false;
      for (final required in requiredTrainingIds) {
        if (!activeTrainingIdSet.contains(required)) {
          lacksTraining = true;
          break;
        }
      }
      if (lacksTraining) continue;

      final rawRoles =
          data['roles'] ?? data['roleId'] ?? data['roleIds'] ?? data['role'];
      final requiredRoleIds = _asIterable(rawRoles)
          .map(_roleId)
          .whereType<String>()
          .toSet();
      if (requiredRoleIds.isNotEmpty) {
        final hasRole = requiredRoleIds.any(roleIdSet.contains);
        if (!hasRole) {
          continue;
        }
      }

      // Accept the common alternate field names too — historic writes have
      // used `lockUsers` and `lockedUsers` in a few corners.
      final lockUserIds = _lockUserIds(
        data['lockUser'] ?? data['lockUsers'] ?? data['lockedUsers'],
      );
      if (lockUserIds.isNotEmpty && !lockUserIds.contains(memberId)) {
        continue;
      }

      eligible.add(doc);
    }

    return TaskDataSnapshot(
      revision: timeline.revision,
      docs: timeline.docs,
      dataByDocId: timeline.dataByDocId,
      activeTrainingIdSet: activeTrainingIdSet,
      roleIdSet: roleIdSet,
      memberId: memberId,
      eligible: eligible,
    );
  }
}

Iterable<dynamic> _asIterable(dynamic value) {
  if (value == null) return const [];
  if (value is Iterable) return value;
  return [value];
}

/// Extract bare training document IDs from a heterogeneous task field.
/// Accepts DocumentReference, full path string ("company/.../training/X"),
/// or bare id string ("X"). Comparison is done by id so a task's
/// `trainingId` and the user's active-training set match regardless of
/// how either side was written.
Iterable<String> _trainingIds(dynamic value) {
  final ids = <String>[];
  for (final item in _asIterable(value)) {
    if (item is DocumentReference) {
      ids.add(item.id);
    } else if (item is String) {
      final trimmed = item.trim();
      if (trimmed.isEmpty) continue;
      ids.add(trimmed.contains('/') ? trimmed.split('/').last : trimmed);
    }
  }
  return ids;
}

String? _roleId(dynamic value) {
  if (value is DocumentReference) return value.id;
  if (value is String) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    return trimmed.contains('/') ? trimmed.split('/').last : trimmed;
  }
  return null;
}

/// Extract bare member document IDs from a `lockUser` value. Same
/// rationale as `_trainingIds` — historic writes mixed DocumentReference,
/// full path string, and bare id string.
List<String> _lockUserIds(dynamic value) {
  final ids = <String>{};
  void addId(dynamic item) {
    if (item is DocumentReference) {
      ids.add(item.id);
    } else if (item is String) {
      final trimmed = item.trim();
      if (trimmed.isEmpty) return;
      ids.add(trimmed.contains('/') ? trimmed.split('/').last : trimmed);
    }
  }

  if (value is Iterable) {
    for (final item in value) {
      addId(item);
    }
  } else {
    addId(value);
  }

  return ids.toList(growable: false);
}
