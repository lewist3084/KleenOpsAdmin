// lib/features/occupancy/models/agent_task_run.dart
//
// Model for a single agent-task run record at top-level
// `agentTaskRuns/{runId}`. Written by the Cloud Run service in
// `cloud_run/agent_task_runner/`; read by the Flutter app to surface
// the result in the AI canvas.

import 'package:cloud_firestore/cloud_firestore.dart';

enum AgentTaskRunStatus {
  running,
  readyForReview,
  failed,
  unknown,
}

AgentTaskRunStatus _statusFromString(String? value) {
  switch (value) {
    case 'running':
      return AgentTaskRunStatus.running;
    case 'ready_for_review':
      return AgentTaskRunStatus.readyForReview;
    case 'failed':
      return AgentTaskRunStatus.failed;
    default:
      return AgentTaskRunStatus.unknown;
  }
}

/// Status of one step in an agent-task run's progress log.
enum AgentTaskStepStatus { pending, running, done, failed, skipped, unknown }

AgentTaskStepStatus _stepStatusFromString(String? value) {
  switch (value) {
    case 'pending':
      return AgentTaskStepStatus.pending;
    case 'running':
      return AgentTaskStepStatus.running;
    case 'done':
      return AgentTaskStepStatus.done;
    case 'failed':
      return AgentTaskStepStatus.failed;
    case 'skipped':
      return AgentTaskStepStatus.skipped;
    default:
      return AgentTaskStepStatus.unknown;
  }
}

/// One stage of an agent-task run — "Signing in", "Downloading the file",
/// "Reading the spreadsheet", etc. The runner (and, for the final two
/// client-side stages, the AI canvas) write these onto the run doc's `steps`
/// map as they progress; the timeline tile renders them as an expandable
/// checklist so the user can watch the agent work and see where it stops.
class AgentTaskRunStep {
  const AgentTaskRunStep({
    required this.key,
    required this.order,
    required this.label,
    required this.status,
    this.detail,
    this.error,
    this.startedAt,
    this.endedAt,
  });

  /// Stable key (`connect`, `sign_in`, `download`, …).
  final String key;

  /// Sort position within the run's roadmap.
  final int order;

  /// Human-readable stage name shown in the timeline.
  final String label;

  final AgentTaskStepStatus status;

  /// Optional one-line detail ("Classroom_Assignments.xlsx · 184 KB").
  final String? detail;

  /// Failure message — only set when [status] is `failed`.
  final String? error;

  final DateTime? startedAt;
  final DateTime? endedAt;

  bool get isPending => status == AgentTaskStepStatus.pending;
  bool get isRunning => status == AgentTaskStepStatus.running;
  bool get isDone => status == AgentTaskStepStatus.done;
  bool get isFailed => status == AgentTaskStepStatus.failed;

  static AgentTaskRunStep? fromMapEntry(String key, Object? value) {
    if (value is! Map) return null;
    final m = value.cast<String, dynamic>();
    final label = (m['label'] as String?)?.trim();
    final detail = (m['detail'] as String?)?.trim();
    final error = (m['error'] as String?)?.trim();
    return AgentTaskRunStep(
      key: key,
      order: (m['order'] as num?)?.toInt() ?? 0,
      label: (label == null || label.isEmpty) ? key : label,
      status: _stepStatusFromString(m['status'] as String?),
      detail: (detail == null || detail.isEmpty) ? null : detail,
      error: (error == null || error.isEmpty) ? null : error,
      startedAt: _toDate(m['startedAt']),
      endedAt: _toDate(m['endedAt']),
    );
  }
}

/// Parse the run doc's `steps` map into an order-sorted list.
List<AgentTaskRunStep> _stepsFromMap(Object? raw) {
  if (raw is! Map) return const <AgentTaskRunStep>[];
  final steps = <AgentTaskRunStep>[];
  raw.forEach((k, v) {
    final step = AgentTaskRunStep.fromMapEntry(k.toString(), v);
    if (step != null) steps.add(step);
  });
  steps.sort((a, b) => a.order.compareTo(b.order));
  return steps;
}

class AgentTaskRunFile {
  const AgentTaskRunFile({
    required this.bucket,
    required this.path,
    required this.gsUri,
    required this.mimeType,
    required this.filename,
    required this.bytes,
    this.sourceIndex = 0,
  });

  final String bucket;
  final String path;
  final String gsUri;
  final String mimeType;
  final String filename;
  final int bytes;

  /// Which entry in the task definition's `dataSources` array produced
  /// this file. The runner writes this so the details screen can show the
  /// right "Last pulled" indicator on each source tile. Defaults to 0 so
  /// pre-array runs still attribute to source 1.
  final int sourceIndex;

  static AgentTaskRunFile? fromMap(Map<String, dynamic>? data) {
    if (data == null) return null;
    return AgentTaskRunFile(
      bucket: (data['bucket'] as String?) ?? '',
      path: (data['path'] as String?) ?? '',
      gsUri: (data['gsUri'] as String?) ?? '',
      mimeType: (data['mimeType'] as String?) ?? 'application/octet-stream',
      filename: (data['filename'] as String?) ?? 'export.bin',
      bytes: (data['bytes'] as num?)?.toInt() ?? 0,
      sourceIndex: (data['sourceIndex'] as num?)?.toInt() ?? 0,
    );
  }
}

class AgentTaskRunOutput {
  const AgentTaskRunOutput({
    required this.bridgeType,
    required this.scope,
    required this.files,
    required this.narrative,
  });

  final String bridgeType;
  final Map<String, dynamic>? scope;

  /// All files this run pulled, one entry per data source the runner
  /// reached. Each carries [AgentTaskRunFile.sourceIndex] so the UI can
  /// show "Last pulled" per source tile. Empty if the run failed before
  /// downloading anything. Reads back-compat with the older singular
  /// `file` field (treated as a single entry at sourceIndex 0).
  final List<AgentTaskRunFile> files;

  final String? narrative;

  /// Convenience for the pre-multi-file call sites that only knew about
  /// "the" downloaded file. Returns the first entry, or null if empty.
  AgentTaskRunFile? get file => files.isEmpty ? null : files.first;

  /// Lookup by source index — used by per-source tiles to render the file
  /// the runner actually produced for that source.
  AgentTaskRunFile? fileForSource(int index) {
    for (final f in files) {
      if (f.sourceIndex == index) return f;
    }
    return null;
  }

  static AgentTaskRunOutput? fromMap(Map<String, dynamic>? data) {
    if (data == null) return null;
    // Prefer the new `files` array; fall back to the legacy singular
    // `file` field so older run docs still surface as a one-element list.
    final List<AgentTaskRunFile> files;
    final rawFiles = data['files'];
    if (rawFiles is List && rawFiles.isNotEmpty) {
      files = rawFiles
          .whereType<Map>()
          .map((m) => AgentTaskRunFile.fromMap(m.cast<String, dynamic>()))
          .whereType<AgentTaskRunFile>()
          .toList(growable: false);
    } else {
      final single = AgentTaskRunFile.fromMap(
        (data['file'] as Map?)?.cast<String, dynamic>(),
      );
      files = single == null
          ? const <AgentTaskRunFile>[]
          : <AgentTaskRunFile>[single];
    }
    return AgentTaskRunOutput(
      bridgeType: (data['bridgeType'] as String?) ?? '',
      scope: (data['scope'] as Map?)?.cast<String, dynamic>(),
      files: files,
      narrative: (data['narrative'] as String?)?.trim().isEmpty == true
          ? null
          : (data['narrative'] as String?),
    );
  }
}

class AgentTaskRun {
  const AgentTaskRun({
    required this.runId,
    required this.companyId,
    required this.taskId,
    required this.taskName,
    required this.ownerUid,
    required this.status,
    required this.sourceType,
    required this.bridgeType,
    required this.startedAt,
    required this.completedAt,
    required this.acknowledgedAt,
    required this.acknowledgedBy,
    required this.output,
    required this.error,
    this.steps = const <AgentTaskRunStep>[],
    this.currentStepKey,
  });

  final String runId;
  final String companyId;
  final String taskId;
  final String? taskName;
  final String? ownerUid;
  final AgentTaskRunStatus status;
  final String? sourceType;
  final String? bridgeType;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final DateTime? acknowledgedAt;
  final String? acknowledgedBy;
  final AgentTaskRunOutput? output;
  final Map<String, dynamic>? error;

  /// Ordered progress log — empty for older runs written before step
  /// tracking existed.
  final List<AgentTaskRunStep> steps;

  /// Key of the step currently in progress, if any.
  final String? currentStepKey;

  bool get isReadyForReview => status == AgentTaskRunStatus.readyForReview;
  bool get isRunning => status == AgentTaskRunStatus.running;
  bool get isFailed => status == AgentTaskRunStatus.failed;
  bool get isPendingForUser =>
      isReadyForReview && acknowledgedAt == null && output?.file != null;

  /// The step the agent is actively working on (or the failed one), used to
  /// describe progress in the timeline tile.
  AgentTaskRunStep? get currentStep {
    for (final step in steps) {
      if (step.isRunning) return step;
    }
    if (currentStepKey != null) {
      for (final step in steps) {
        if (step.key == currentStepKey) return step;
      }
    }
    return null;
  }

  /// The first failed step, if the run stopped on one.
  AgentTaskRunStep? get failedStep {
    for (final step in steps) {
      if (step.isFailed) return step;
    }
    return null;
  }

  /// True if the run failed outright, or a step (including a client-side
  /// parsing step on an otherwise "ready" run) failed.
  bool get hasFailure => isFailed || failedStep != null;

  /// Short human-readable description of where the run is right now.
  String get progressLabel {
    final failed = failedStep;
    if (failed != null) return 'Stopped at "${failed.label}"';
    if (isRunning) {
      return currentStep?.label ?? 'Working…';
    }
    return 'Done';
  }

  factory AgentTaskRun.fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snap,
  ) {
    final d = snap.data() ?? const <String, dynamic>{};
    return AgentTaskRun(
      runId: (d['runId'] as String?) ?? snap.id,
      companyId: (d['companyId'] as String?) ?? '',
      taskId: (d['taskId'] as String?) ?? '',
      taskName: d['taskName'] as String?,
      ownerUid: d['ownerUid'] as String?,
      status: _statusFromString(d['status'] as String?),
      sourceType: d['sourceType'] as String?,
      bridgeType: d['bridgeType'] as String?,
      startedAt: _toDate(d['startedAt']),
      completedAt: _toDate(d['completedAt']),
      acknowledgedAt: _toDate(d['acknowledgedAt']),
      acknowledgedBy: d['acknowledgedBy'] as String?,
      output: AgentTaskRunOutput.fromMap(
        (d['output'] as Map?)?.cast<String, dynamic>(),
      ),
      error: (d['error'] as Map?)?.cast<String, dynamic>(),
      steps: _stepsFromMap(d['steps']),
      currentStepKey: d['currentStepKey'] as String?,
    );
  }
}

DateTime? _toDate(Object? value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return null;
}
