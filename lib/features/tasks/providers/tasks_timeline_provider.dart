// lib/features/tasks/providers/tasks_timeline_provider.dart
//
// Riverpod stream providers for the tasks timeline, team settings, and
// training status.
//
// Admin port: uses TOP-LEVEL Firestore collections directly
// (`FirebaseFirestore.instance.collection('timeline')`, etc.). The kleenops
// app scopes everything under `company/{id}/...`; admin is the cross-company
// SaaS overlord, so its data is global.
//
// The `companyId` field on TaskTimelineParams is preserved for API parity
// with the kleenops UI code (so we don't have to rewrite every call site),
// but is ignored inside the queries below.

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kleenops_admin/features/tasks/data/task_timeline_entry.dart';

const _listEquality = ListEquality<String>();
const int _maxWhereIn = 10;

/// Ad-hoc (member-added) task category. These are personal — never surface
/// them in any group/team view.
const String adHocTaskCategoryId = 'Rpl9Mn34gJBdZ007jXpo';

/// Parameters for the timeline query. Equality-aware so the Riverpod family
/// provider rebuilds only when the query surface actually changes.
class TaskTimelineParams {
  const TaskTimelineParams({
    required this.companyId,
    required this.categoryIds,
    required this.teamPaths,
    required this.selectedTeamPath,
    required this.lowerBoundMillis,
    required this.upperBoundMillis,
    this.personalMemberPath,
  });

  final String companyId;
  final List<String> categoryIds;
  final List<String> teamPaths;
  final String? selectedTeamPath;
  final int lowerBoundMillis;
  final int upperBoundMillis;

  /// When [categoryIds] includes the ad-hoc task category, the repository
  /// queries that category separately, scoped to this member only. Required
  /// in that case; ad-hoc tasks are personal and never appear in group views.
  final String? personalMemberPath;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is TaskTimelineParams &&
            companyId == other.companyId &&
            lowerBoundMillis == other.lowerBoundMillis &&
            upperBoundMillis == other.upperBoundMillis &&
            selectedTeamPath == other.selectedTeamPath &&
            personalMemberPath == other.personalMemberPath &&
            _listEquality.equals(categoryIds, other.categoryIds) &&
            _listEquality.equals(teamPaths, other.teamPaths);
  }

  @override
  int get hashCode {
    return Object.hash(
      companyId,
      lowerBoundMillis,
      upperBoundMillis,
      selectedTeamPath,
      personalMemberPath,
      _listEquality.hash(categoryIds),
      _listEquality.hash(teamPaths),
    );
  }
}

class TaskTimelineSnapshot {
  TaskTimelineSnapshot({
    required this.revision,
    required this.docs,
    required this.dataByDocId,
    required this.entries,
    required this.entryById,
  });

  final int revision;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;
  final Map<String, Map<String, dynamic>> dataByDocId;
  final List<TaskTimelineEntry> entries;
  final Map<String, TaskTimelineEntry> entryById;
}

class TeamSettings {
  const TeamSettings({
    required this.pacingEnabled,
    required this.pacingIntervalMinutes,
  });

  final bool pacingEnabled;
  final int pacingIntervalMinutes;

  static const TeamSettings defaultSettings =
      TeamSettings(pacingEnabled: false, pacingIntervalMinutes: 90);
}

class TaskTrainingParams {
  const TaskTrainingParams({
    required this.companyPath,
    required this.memberPath,
  });

  final String companyPath;
  final String memberPath;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is TaskTrainingParams &&
            companyPath == other.companyPath &&
            memberPath == other.memberPath;
  }

  @override
  int get hashCode => Object.hash(companyPath, memberPath);
}

class TaskTrainingStatus {
  const TaskTrainingStatus({
    required this.activeTrainingIds,
    required this.lockout,
    required this.showWarnOverlay,
    required this.warnMessage,
  });

  /// Bare training document IDs (last path segment), not full paths.
  /// Stored as IDs so comparison with a task's `trainingId` field works
  /// regardless of whether that field was written as a DocumentReference,
  /// a full path string, or a bare ID string.
  final Set<String> activeTrainingIds;
  final bool lockout;
  final bool showWarnOverlay;
  final String? warnMessage;

  static const TaskTrainingStatus empty = TaskTrainingStatus(
    activeTrainingIds: <String>{},
    lockout: false,
    showWarnOverlay: false,
    warnMessage: null,
  );
}

// ───────────────────── Helpers ─────────────────────

DocumentReference<Map<String, dynamic>> _typedDoc(String path) {
  return FirebaseFirestore.instance
      .doc(path)
      .withConverter<Map<String, dynamic>>(
        fromFirestore: (snap, _) => snap.data() ?? <String, dynamic>{},
        toFirestore: (value, _) => value,
      );
}

/// Normalize a `teamId` field value into a Firestore path. In admin the
/// `team` collection is top-level, so bare-id strings get resolved against
/// `team/{id}`.
String? _normalizeTeamPath(dynamic teamId) {
  if (teamId is DocumentReference) return teamId.path;
  if (teamId is String) {
    final trimmed = teamId.trim();
    if (trimmed.isEmpty) return null;
    if (trimmed.contains('/')) return trimmed;
    return 'team/$trimmed';
  }
  return null;
}

// ───────────────────── Streams ─────────────────────

/// Watches the timeline collection (TOP-LEVEL `timeline/...` in admin) with
/// the given filters. Handles the documented DocumentReference-vs-String
/// `teamId` split by issuing two queries and merging results when necessary.
Stream<TaskTimelineSnapshot> watchTimeline(TaskTimelineParams params) {
  final firestore = FirebaseFirestore.instance;

  // Ad-hoc tasks are personal — split them out of the team-scoped query and
  // run a separate member-scoped query for them. If the caller forgot to
  // supply a member path, drop the category entirely (fail-closed: never
  // show ad-hoc in a team view).
  final teamCategoryIds = params.categoryIds
      .where((id) => id != adHocTaskCategoryId)
      .toList(growable: false);
  final includeAdHoc = params.categoryIds.contains(adHocTaskCategoryId) &&
      params.personalMemberPath != null;

  Query<Map<String, dynamic>> rangeBoundedAdHocQuery() {
    final memberRef = _typedDoc(params.personalMemberPath!);
    return firestore
        .collection('timeline')
        .where('timelineCategory', isEqualTo: adHocTaskCategoryId)
        .where('memberId', isEqualTo: memberRef)
        .where(
          'startTime',
          isLessThanOrEqualTo:
              Timestamp.fromMillisecondsSinceEpoch(params.upperBoundMillis),
        )
        .where(
          'endTimeExtended',
          isGreaterThanOrEqualTo:
              Timestamp.fromMillisecondsSinceEpoch(params.lowerBoundMillis),
        )
        .orderBy('startTime')
        .orderBy('endTimeExtended')
        .orderBy('name');
  }

  Query<Map<String, dynamic>>? teamBaseQuery;
  if (teamCategoryIds.isNotEmpty) {
    teamBaseQuery = firestore
        .collection('timeline')
        .where('timelineCategory', whereIn: teamCategoryIds)
        .where(
          'startTime',
          isLessThanOrEqualTo:
              Timestamp.fromMillisecondsSinceEpoch(params.upperBoundMillis),
        )
        .where(
          'endTimeExtended',
          isGreaterThanOrEqualTo:
              Timestamp.fromMillisecondsSinceEpoch(params.lowerBoundMillis),
        )
        .orderBy('startTime')
        .orderBy('endTimeExtended')
        .orderBy('name');
  }

  // Firestore cannot match both DocumentReference and String values in a
  // single `whereIn`. Query both shapes when needed and merge.
  final bool tooManyTeamsForWhereIn = params.selectedTeamPath == null &&
      params.teamPaths.length > _maxWhereIn;

  final queries = <Query<Map<String, dynamic>>>[];
  if (teamBaseQuery != null) {
    if (params.selectedTeamPath != null) {
      final selectedPath = params.selectedTeamPath!;
      queries.add(teamBaseQuery.where('teamId', isEqualTo: _typedDoc(selectedPath)));
      queries.add(teamBaseQuery.where('teamId', isEqualTo: selectedPath));
    } else if (!tooManyTeamsForWhereIn && params.teamPaths.isNotEmpty) {
      final teamRefs = params.teamPaths.map(_typedDoc).toList(growable: false);
      final teamPaths = params.teamPaths.toList(growable: false)..sort();
      queries.add(teamBaseQuery.where('teamId', whereIn: teamRefs));
      queries.add(teamBaseQuery.where('teamId', whereIn: teamPaths));
    } else {
      queries.add(teamBaseQuery);
    }
  }
  if (includeAdHoc) {
    queries.add(rangeBoundedAdHocQuery());
  }
  if (queries.isEmpty) {
    return Stream<TaskTimelineSnapshot>.value(TaskTimelineSnapshot(
      revision: 0,
      docs: const [],
      dataByDocId: const {},
      entries: const [],
      entryById: const {},
    ));
  }

  int compareDocs(
    QueryDocumentSnapshot<Map<String, dynamic>> a,
    QueryDocumentSnapshot<Map<String, dynamic>> b,
  ) {
    final aData = a.data();
    final bData = b.data();
    final aStart =
        (aData['startTime'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
    final bStart =
        (bData['startTime'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
    final startCmp = aStart.compareTo(bStart);
    if (startCmp != 0) return startCmp;

    final aEnd =
        (aData['endTimeExtended'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
    final bEnd =
        (bData['endTimeExtended'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
    final endCmp = aEnd.compareTo(bEnd);
    if (endCmp != 0) return endCmp;

    final aName = (aData['name'] ?? '').toString();
    final bName = (bData['name'] ?? '').toString();
    final nameCmp = aName.compareTo(bName);
    if (nameCmp != 0) return nameCmp;

    return a.id.compareTo(b.id);
  }

  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>> docsStream;
  if (queries.length == 1) {
    docsStream = queries.single.snapshots().map((snapshot) => snapshot.docs);
  } else {
    final controller =
        StreamController<List<QueryDocumentSnapshot<Map<String, dynamic>>>>();
    final latestDocsByIndex =
        <int, List<QueryDocumentSnapshot<Map<String, dynamic>>>>{};
    final subs = <StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>[];

    void emitCombined() {
      final combinedById =
          <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
      for (final docs in latestDocsByIndex.values) {
        for (final doc in docs) {
          combinedById[doc.id] = doc;
        }
      }
      final combined = combinedById.values.toList(growable: false)
        ..sort(compareDocs);
      controller.add(combined);
    }

    for (var i = 0; i < queries.length; i += 1) {
      final index = i;
      final sub = queries[index].snapshots().listen(
        (snapshot) {
          latestDocsByIndex[index] = snapshot.docs;
          emitCombined();
        },
        onError: controller.addError,
      );
      subs.add(sub);
    }

    controller.onCancel = () async {
      for (final sub in subs) {
        await sub.cancel();
      }
    };
    docsStream = controller.stream;
  }

  var revision = 0;
  return docsStream.map((rawDocs) {
    revision += 1;
    final teamPathSet = params.teamPaths.toSet();
    final selectedTeamPath = params.selectedTeamPath;

    bool matchesTeam(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
      final data = doc.data();
      if (data['timelineCategory'] == adHocTaskCategoryId) return true;
      final teamPath = _normalizeTeamPath(data['teamId']);
      if (teamPath == null) return false;
      if (selectedTeamPath != null) {
        return teamPath == selectedTeamPath;
      }
      if (teamPathSet.isEmpty) return true;
      return teamPathSet.contains(teamPath);
    }

    final needsClientTeamFilter =
        selectedTeamPath != null || tooManyTeamsForWhereIn;
    final docs = needsClientTeamFilter
        ? rawDocs.where(matchesTeam).toList(growable: false)
        : rawDocs;
    final dataByDocId = <String, Map<String, dynamic>>{
      for (final doc in docs) doc.id: doc.data(),
    };
    final entries =
        docs.map(TaskTimelineEntry.fromDoc).toList(growable: false);
    final entryById = {
      for (final entry in entries) entry.id: entry,
    };

    return TaskTimelineSnapshot(
      revision: revision,
      docs: docs,
      dataByDocId: dataByDocId,
      entries: entries,
      entryById: entryById,
    );
  });
}

Stream<TeamSettings> watchTeamSettings(String? teamPath) {
  if (teamPath == null) {
    return Stream<TeamSettings>.value(TeamSettings.defaultSettings);
  }
  return _typedDoc(teamPath).snapshots().map((snapshot) {
    final data = snapshot.data() ?? const <String, dynamic>{};
    return TeamSettings(
      pacingEnabled: data['pacing'] == true,
      pacingIntervalMinutes: (data['pacingInterval'] as num?)?.toInt() ?? 90,
    );
  });
}

Stream<TaskTrainingStatus> watchTrainingStatus(TaskTrainingParams params) {
  final firestore = FirebaseFirestore.instance;
  final memberRef = _typedDoc(params.memberPath);
  // Admin uses top-level `assignedTraining` (not nested under company).
  final query = firestore
      .collection('assignedTraining')
      .where('memberId', isEqualTo: memberRef);

  return query.snapshots().asyncMap((snapshot) async {
    final assignedDocs = snapshot.docs;
    if (assignedDocs.isEmpty) return TaskTrainingStatus.empty;

    // Top-level `training` collection in admin.
    final trainingCol =
        firestore.collection('training').withConverter<Map<String, dynamic>>(
              fromFirestore: (s, _) => s.data() ?? <String, dynamic>{},
              toFirestore: (m, _) => m,
            );
    final assignedTrainingRefs =
        <String, DocumentReference<Map<String, dynamic>>>{};
    for (final d in assignedDocs) {
      final raw = d.data()['trainingId'];
      DocumentReference<Map<String, dynamic>>? ref;
      if (raw is DocumentReference<Map<String, dynamic>>) {
        ref = raw;
      } else if (raw is DocumentReference) {
        ref = _typedDoc(raw.path);
      } else if (raw is String) {
        final trimmed = raw.trim();
        if (trimmed.isEmpty) continue;
        ref = trimmed.contains('/')
            ? _typedDoc(trimmed)
            : trainingCol.doc(trimmed);
      }
      if (ref != null) {
        assignedTrainingRefs[ref.path] = ref;
      }
    }

    if (assignedTrainingRefs.isEmpty) return TaskTrainingStatus.empty;

    final trainingDocs =
        await Future.wait(assignedTrainingRefs.values.map((ref) => ref.get()));
    final trainingByPath = {
      for (final doc in trainingDocs) doc.reference.path: doc,
    };

    DocumentReference<Map<String, dynamic>>? refForAssigned(dynamic raw) {
      if (raw is DocumentReference<Map<String, dynamic>>) return raw;
      if (raw is DocumentReference) return _typedDoc(raw.path);
      if (raw is String) {
        final trimmed = raw.trim();
        if (trimmed.isEmpty) return null;
        return trimmed.contains('/')
            ? _typedDoc(trimmed)
            : trainingCol.doc(trimmed);
      }
      return null;
    }

    final now = DateTime.now();
    final activeTrainingIds = <String>{};
    var lockout = false;
    var showWarnOverlay = false;
    String? warnMessage;
    Duration? minTimeLeft;

    for (final assigned in assignedDocs) {
      final data = assigned.data();
      final trainingRef = refForAssigned(data['trainingId']);
      if (trainingRef == null) continue;

      final trainingSnapshot = trainingByPath[trainingRef.path];
      final trainingData =
          trainingSnapshot?.data() ?? const <String, dynamic>{};

      final taskLockout = trainingData['taskLockout'] == true;
      final graceDays = (trainingData['gracePeriod'] as num?)?.toInt() ?? 0;
      final renewalRequired = trainingData['renewalRequired'] == true;
      final renewalWarnDays =
          (trainingData['renewalWarning'] as num?)?.toInt() ?? 0;

      final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
      final goodUntil = (data['goodUntil'] as Timestamp?)?.toDate();
      final isComplete = data['complete'] == true;

      final isExpired = goodUntil != null && goodUntil.isBefore(now);
      final hasActiveCompletion = isComplete && !isExpired;
      if (hasActiveCompletion) {
        activeTrainingIds.add(trainingRef.id);
      }

      if (goodUntil == null && taskLockout && !isComplete) {
        if (createdAt != null && graceDays > 0) {
          final deadline = createdAt.add(Duration(days: graceDays));
          if (now.isAfter(deadline)) {
            lockout = true;
            break;
          }
        } else if (!isComplete) {
          lockout = true;
          break;
        }
      }

      if (goodUntil != null) {
        if (taskLockout && now.isAfter(goodUntil)) {
          lockout = true;
          break;
        }

        if (renewalRequired) {
          final warnStart =
              goodUntil.subtract(Duration(days: renewalWarnDays));
          if (now.isAfter(warnStart) && now.isBefore(goodUntil)) {
            final left = goodUntil.difference(now);
            if (minTimeLeft == null || left < minTimeLeft) {
              minTimeLeft = left;
              final days = left.inDays + (left.inHours % 24 > 0 ? 1 : 0);
              warnMessage =
                  'You have $days day(s) until your training expires. Please retake the training.';
            }
            showWarnOverlay = true;
          }
        }
      }
    }

    final frozenIds = Set<String>.unmodifiable(activeTrainingIds);

    if (lockout) {
      return TaskTrainingStatus(
        activeTrainingIds: frozenIds,
        lockout: true,
        showWarnOverlay: false,
        warnMessage: null,
      );
    }

    return TaskTrainingStatus(
      activeTrainingIds: frozenIds,
      lockout: false,
      showWarnOverlay: showWarnOverlay,
      warnMessage: warnMessage,
    );
  });
}

// ───────────────────── Riverpod providers ─────────────────────

final tasksTimelineProvider =
    StreamProvider.family<TaskTimelineSnapshot, TaskTimelineParams>(
  (ref, params) => watchTimeline(params),
);

final teamSettingsProvider =
    StreamProvider.family<TeamSettings, String?>(
  (ref, teamPath) => watchTeamSettings(teamPath),
);

final tasksTrainingStatusProvider =
    StreamProvider.family<TaskTrainingStatus, TaskTrainingParams>(
  (ref, params) => watchTrainingStatus(params),
);
