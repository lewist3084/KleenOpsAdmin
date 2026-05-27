// lib/features/occupancy/models/agent_task_definition.dart
//
// Editable agent-task definition stored at
// `company/{companyId}/agentTasks/{taskId}`. The Cloud Run runner reads
// these to know what to fetch, on what schedule, and where to drop the
// resulting `agentTaskRun` doc.
//
// `scope` and `source` are intentionally opaque maps: they let us extend
// per-bridgeType requirements (occupancy needs propertyId/buildingId/
// floorId; future bridges may need different fields) without changing the
// Flutter model every time.

import 'package:cloud_firestore/cloud_firestore.dart';

/// Schedule mode for an [AgentTaskDefinition]:
/// - `weekly` (also called "routine" in the form UI) recurs on the
///   configured frequency (weekly/monthly/annually) at the configured
///   days/weeks/months/time. The legacy single `dayOfWeek` is still
///   populated from `days[0]` so the existing runner keeps working
///   while it migrates to the multi-select fields.
/// - `oneTime` fires once at `oneTimeAt`.
/// - `manual` only runs when the user taps "Run now".
enum AgentTaskScheduleMode { weekly, oneTime, manual }

AgentTaskScheduleMode _modeFromString(String? value) {
  switch (value) {
    case 'weekly':
    case 'routine':
      return AgentTaskScheduleMode.weekly;
    case 'one_time':
    case 'oneTime':
      return AgentTaskScheduleMode.oneTime;
    case 'manual':
    default:
      return AgentTaskScheduleMode.manual;
  }
}

String _modeToString(AgentTaskScheduleMode mode) {
  switch (mode) {
    case AgentTaskScheduleMode.weekly:
      return 'weekly';
    case AgentTaskScheduleMode.oneTime:
      return 'one_time';
    case AgentTaskScheduleMode.manual:
      return 'manual';
  }
}

/// What an agent task hands back when it finishes — the shape of the
/// deliverable, and the broad output dimension for the whole feature.
/// Each value routes to an app system that already exists (the AI
/// canvas, email, texting, My Drive, the swipe-approve proposal panel).
///
/// Today only [databaseChanges] (via the `occupancy_proposal` bridge) is
/// wired end-to-end; the rest are declared so the wizard, model and
/// details screen already speak the full language while the execution
/// side is built out one deliverable at a time.
enum AgentTaskDeliverable {
  /// A plain-text answer posted as a message in the AI canvas.
  text,

  /// A drafted email handed to the email system.
  email,

  /// A drafted text/SMS message handed to the texting system.
  textMessage,

  /// A generated file/document saved to the owner's My Drive.
  file,

  /// A generated image saved to the owner's My Drive.
  image,

  /// New documents or edits queued as swipe-to-approve proposals in the
  /// AI canvas. The occupancy reservation bridge is the first instance.
  databaseChanges,
}

AgentTaskDeliverable _deliverableFromString(String? value) {
  switch (value) {
    case 'text':
      return AgentTaskDeliverable.text;
    case 'email':
      return AgentTaskDeliverable.email;
    case 'text_message':
      return AgentTaskDeliverable.textMessage;
    case 'file':
      return AgentTaskDeliverable.file;
    case 'image':
      return AgentTaskDeliverable.image;
    case 'database_changes':
      return AgentTaskDeliverable.databaseChanges;
    default:
      // Missing/unknown: every task that predates this field is an
      // occupancy proposal, so default to the queued-changes deliverable.
      return AgentTaskDeliverable.databaseChanges;
  }
}

String _deliverableToString(AgentTaskDeliverable d) {
  switch (d) {
    case AgentTaskDeliverable.text:
      return 'text';
    case AgentTaskDeliverable.email:
      return 'email';
    case AgentTaskDeliverable.textMessage:
      return 'text_message';
    case AgentTaskDeliverable.file:
      return 'file';
    case AgentTaskDeliverable.image:
      return 'image';
    case AgentTaskDeliverable.databaseChanges:
      return 'database_changes';
  }
}

/// Public parse for a deliverable wire string. Used by callers outside
/// this library (e.g. the wizard service) that can't see the
/// file-private [_deliverableFromString].
AgentTaskDeliverable agentTaskDeliverableFromWire(String? value) =>
    _deliverableFromString(value);

/// Display + wire-format helpers for [AgentTaskDeliverable], shared by
/// the wizard, the details screen and the (future) handler registry.
extension AgentTaskDeliverableInfo on AgentTaskDeliverable {
  /// Human label for the details screen and wizard proposal card.
  String get label {
    switch (this) {
      case AgentTaskDeliverable.text:
        return 'Text response';
      case AgentTaskDeliverable.email:
        return 'Email';
      case AgentTaskDeliverable.textMessage:
        return 'Text message';
      case AgentTaskDeliverable.file:
        return 'File / document';
      case AgentTaskDeliverable.image:
        return 'Image';
      case AgentTaskDeliverable.databaseChanges:
        return 'Queued database changes';
    }
  }

  /// Where the deliverable lands once produced — shown as a sub-label.
  String get destination {
    switch (this) {
      case AgentTaskDeliverable.text:
        return 'Posted as a message in the AI canvas.';
      case AgentTaskDeliverable.email:
        return 'Drafted into the email system.';
      case AgentTaskDeliverable.textMessage:
        return 'Drafted into the texting system.';
      case AgentTaskDeliverable.file:
        return 'Saved to your My Drive.';
      case AgentTaskDeliverable.image:
        return 'Saved to your My Drive.';
      case AgentTaskDeliverable.databaseChanges:
        return 'Surfaced as swipe-to-approve proposals in the AI canvas.';
    }
  }

  /// Stable string persisted on the Firestore doc / used in the wizard
  /// JSON schema.
  String get wireValue => _deliverableToString(this);
}

/// Where the runner pulls data from. `internal` = the workflow consumes
/// data already inside the app (a Firestore collection, a generated
/// report, etc.). `external` = the runner logs into a website and GETs
/// a file. The credential is never stored on the doc — `secretRef` is a
/// Secret Manager resource name; the Cloud Run runner reads it via its
/// service account at run time.
enum AgentTaskDataSourceMode { internal, external }

AgentTaskDataSourceMode _dataSourceModeFromString(String? value) {
  switch (value) {
    case 'external':
      return AgentTaskDataSourceMode.external;
    case 'internal':
    default:
      return AgentTaskDataSourceMode.internal;
  }
}

String _dataSourceModeToString(AgentTaskDataSourceMode mode) {
  switch (mode) {
    case AgentTaskDataSourceMode.internal:
      return 'internal';
    case AgentTaskDataSourceMode.external:
      return 'external';
  }
}

class AgentTaskDataSource {
  const AgentTaskDataSource({
    this.mode = AgentTaskDataSourceMode.internal,
    this.url,
    this.username,
    this.secretRef,
  });

  final AgentTaskDataSourceMode mode;
  final String? url;
  final String? username;
  final String? secretRef;

  bool get isExternal => mode == AgentTaskDataSourceMode.external;

  Map<String, dynamic> toMap() => <String, dynamic>{
        'mode': _dataSourceModeToString(mode),
        if (url != null && url!.isNotEmpty) 'url': url,
        if (username != null && username!.isNotEmpty) 'username': username,
        if (secretRef != null && secretRef!.isNotEmpty) 'secretRef': secretRef,
      };

  static AgentTaskDataSource fromMap(Map<String, dynamic>? data) {
    if (data == null) return const AgentTaskDataSource();
    return AgentTaskDataSource(
      mode: _dataSourceModeFromString(data['mode'] as String?),
      url: data['url'] as String?,
      username: data['username'] as String?,
      secretRef: data['secretRef'] as String?,
    );
  }

  AgentTaskDataSource copyWith({
    AgentTaskDataSourceMode? mode,
    String? url,
    String? username,
    String? secretRef,
  }) {
    return AgentTaskDataSource(
      mode: mode ?? this.mode,
      url: url ?? this.url,
      username: username ?? this.username,
      secretRef: secretRef ?? this.secretRef,
    );
  }
}

/// When to fire a recurring task. Mirrors the scheduling-routines
/// schedule shape so the edit form can reuse the same multi-select
/// pickers (frequency + days + weeks + months + time).
///
/// Legacy single fields are preserved for back-compat with the existing
/// Cloud Run runner:
///   - `dayOfWeek` (ISO 1=Mon..7=Sun) is mirrored from `days[0]`.
///   - `hour`/`minute` always reflect the picked time.
class AgentTaskSchedule {
  const AgentTaskSchedule({
    required this.mode,
    this.dayOfWeek = 1,
    this.hour = 7,
    this.minute = 0,
    this.timezone = 'America/Denver',
    this.frequency,
    this.days = const <String>[],
    this.weeks = const <String>[],
    this.months = const <String>[],
    this.oneTimeAt,
  });

  final AgentTaskScheduleMode mode;
  final int dayOfWeek;
  final int hour;
  final int minute;
  final String timezone;

  /// One of `Weekly`, `Monthly`, `Annually` when [mode] is
  /// [AgentTaskScheduleMode.weekly]. Null for `oneTime`/`manual`.
  final String? frequency;

  /// Days-of-week labels (`Mon`..`Sun`) when [frequency] requires them
  /// (every frequency value uses days in the scheduling-routines pattern).
  final List<String> days;

  /// Ordinal week-of-month labels (`1st`, `2nd`, ...) when [frequency] is
  /// `Monthly` or `Annually`.
  final List<String> weeks;

  /// Month labels (`Jan`..`Dec`) when [frequency] is `Annually`.
  final List<String> months;

  /// When to fire a one-time task. Null unless [mode] is
  /// [AgentTaskScheduleMode.oneTime].
  final DateTime? oneTimeAt;

  Map<String, dynamic> toMap() => <String, dynamic>{
        'mode': _modeToString(mode),
        'dayOfWeek': dayOfWeek,
        'hour': hour,
        'minute': minute,
        'timezone': timezone,
        if (frequency != null) 'frequency': frequency,
        if (days.isNotEmpty) 'days': days,
        if (weeks.isNotEmpty) 'weeks': weeks,
        if (months.isNotEmpty) 'months': months,
        if (oneTimeAt != null)
          'oneTimeAt': Timestamp.fromDate(oneTimeAt!),
      };

  static AgentTaskSchedule fromMap(Map<String, dynamic>? data) {
    if (data == null) {
      return const AgentTaskSchedule(mode: AgentTaskScheduleMode.manual);
    }
    final rawOneTime = data['oneTimeAt'];
    DateTime? oneTime;
    if (rawOneTime is Timestamp) {
      oneTime = rawOneTime.toDate();
    } else if (rawOneTime is DateTime) {
      oneTime = rawOneTime;
    }
    return AgentTaskSchedule(
      mode: _modeFromString(data['mode'] as String?),
      dayOfWeek: (data['dayOfWeek'] as num?)?.toInt() ?? 1,
      hour: (data['hour'] as num?)?.toInt() ?? 7,
      minute: (data['minute'] as num?)?.toInt() ?? 0,
      timezone: (data['timezone'] as String?)?.trim().isEmpty == true
          ? 'America/Denver'
          : (data['timezone'] as String?) ?? 'America/Denver',
      frequency: data['frequency'] as String?,
      days: (data['days'] is List)
          ? (data['days'] as List).whereType<String>().toList(growable: false)
          : const <String>[],
      weeks: (data['weeks'] is List)
          ? (data['weeks'] as List).whereType<String>().toList(growable: false)
          : const <String>[],
      months: (data['months'] is List)
          ? (data['months'] as List).whereType<String>().toList(growable: false)
          : const <String>[],
      oneTimeAt: oneTime,
    );
  }
}

class AgentTaskDefinition {
  const AgentTaskDefinition({
    required this.taskId,
    required this.companyId,
    required this.name,
    required this.bridgeType,
    required this.enabled,
    required this.schedule,
    this.description,
    this.retrievalPrompt,
    this.processingPrompt,
    this.outputPrompt,
    this.deliverable = AgentTaskDeliverable.databaseChanges,
    this.ownerUid,
    this.scope = const <String, dynamic>{},
    this.source = const <String, dynamic>{},
    this.dataSources = const <AgentTaskDataSource>[],
    this.outputSummary = const <String>[],
    this.lastRunAt,
    this.lastRunId,
    this.nextRunAt,
  });

  /// Doc id under `company/{companyId}/agentTasks/{taskId}`.
  final String taskId;

  /// Denormalized for cross-collection queries. Always matches the
  /// company in the document path.
  final String companyId;

  /// Human-readable label shown in the list / form / canvas narrative.
  final String name;

  /// Which surfacer/bridge handles the resulting run. Today only
  /// `occupancy_proposal` exists; future bridges plug in here.
  final String bridgeType;

  final bool enabled;
  final AgentTaskSchedule schedule;

  final String? description;

  /// Free-text instruction for the **retrieval** stage — guidance on
  /// *how* / *what* to pull from the data sources (e.g. "Pull only rows
  /// where Status = Confirmed; ignore historical rows older than 14 days").
  /// May be null for purely mechanical fetches.
  final String? retrievalPrompt;

  /// Free-text instruction for the **processing** stage — what the AI
  /// should DO with the data once collected (e.g. "Match each row to a
  /// building occupant and produce a reservation per classroom-day").
  /// Replaces the legacy single `prompt` field; reads of older docs
  /// migrate `prompt` into this slot.
  final String? processingPrompt;

  /// Free-text instruction for the **output** stage — how to package the
  /// final deliverable (e.g. "Group by building; write one row per
  /// reservation"). Pairs with [deliverable].
  final String? outputPrompt;

  /// The shape of what this task returns when it finishes. The broad
  /// output dimension — see [AgentTaskDeliverable]. Defaults to
  /// [AgentTaskDeliverable.databaseChanges] for backward compatibility
  /// with occupancy tasks created before the field existed.
  final AgentTaskDeliverable deliverable;

  /// User responsible for the task. The Cloud Run runner stamps the
  /// resulting [AgentTaskRun.ownerUid] from this value so the run only
  /// surfaces in that user's canvas.
  final String? ownerUid;

  /// Domain-specific scope (occupancy: propertyId/buildingId/floorId).
  /// Stored opaquely so future bridges can shape their own.
  final Map<String, dynamic> scope;

  /// How the runner fetches the source file (URL, credential ref, etc.).
  /// Schema is bridge-specific.
  final Map<String, dynamic> source;

  /// One or more generalized data-source descriptors (internal vs.
  /// external + URL + username + Secret Manager ref). Replaces the
  /// bridge-specific [source] map for everything except legacy reads.
  /// New code should populate this. The Cloud Run runner today only
  /// consumes the first entry (mirrored into the legacy `source` map on
  /// write for backward compat); multi-source execution is a separate
  /// runner change.
  final List<AgentTaskDataSource> dataSources;

  /// Convenience accessor for the first data source — preserves the
  /// pre-array call sites that read a single descriptor.
  AgentTaskDataSource? get primaryDataSource =>
      dataSources.isEmpty ? null : dataSources.first;

  /// Bullet-point summary of what this workflow produces, written by the
  /// wizard LLM and shown read-only on the details form. Examples:
  /// "Surfaces proposed reservations in the AI canvas",
  /// "Generates weekly_occupancy.csv in company/{cid}/files/finance/".
  final List<String> outputSummary;

  /// Bookkeeping written by the runner.
  final DateTime? lastRunAt;
  final String? lastRunId;
  final DateTime? nextRunAt;

  bool get isWeekly => schedule.mode == AgentTaskScheduleMode.weekly;
  bool get isManualOnly => schedule.mode == AgentTaskScheduleMode.manual;

  AgentTaskDefinition copyWith({
    String? name,
    String? description,
    String? retrievalPrompt,
    String? processingPrompt,
    String? outputPrompt,
    AgentTaskDeliverable? deliverable,
    String? bridgeType,
    bool? enabled,
    AgentTaskSchedule? schedule,
    String? ownerUid,
    Map<String, dynamic>? scope,
    Map<String, dynamic>? source,
    List<AgentTaskDataSource>? dataSources,
    List<String>? outputSummary,
  }) {
    return AgentTaskDefinition(
      taskId: taskId,
      companyId: companyId,
      name: name ?? this.name,
      description: description ?? this.description,
      retrievalPrompt: retrievalPrompt ?? this.retrievalPrompt,
      processingPrompt: processingPrompt ?? this.processingPrompt,
      outputPrompt: outputPrompt ?? this.outputPrompt,
      deliverable: deliverable ?? this.deliverable,
      bridgeType: bridgeType ?? this.bridgeType,
      enabled: enabled ?? this.enabled,
      schedule: schedule ?? this.schedule,
      ownerUid: ownerUid ?? this.ownerUid,
      scope: scope ?? this.scope,
      source: source ?? this.source,
      dataSources: dataSources ?? this.dataSources,
      outputSummary: outputSummary ?? this.outputSummary,
      lastRunAt: lastRunAt,
      lastRunId: lastRunId,
      nextRunAt: nextRunAt,
    );
  }

  Map<String, dynamic> toMap() {
    final ds = primaryDataSource;
    return <String, dynamic>{
      'taskId': taskId,
      'companyId': companyId,
      'name': name,
      if (description != null && description!.isNotEmpty)
        'description': description,
      if (retrievalPrompt != null && retrievalPrompt!.isNotEmpty)
        'retrievalPrompt': retrievalPrompt,
      if (processingPrompt != null && processingPrompt!.isNotEmpty)
        'processingPrompt': processingPrompt,
      if (outputPrompt != null && outputPrompt!.isNotEmpty)
        'outputPrompt': outputPrompt,
      // Legacy single `prompt` field — kept in sync with processingPrompt
      // so the Cloud Run runner (which still reads `prompt`) keeps working
      // until it migrates to the three-prompt shape.
      if (processingPrompt != null && processingPrompt!.isNotEmpty)
        'prompt': processingPrompt,
      'deliverable': _deliverableToString(deliverable),
      'bridgeType': bridgeType,
      'enabled': enabled,
      'schedule': schedule.toMap(),
      if (ownerUid != null) 'ownerUid': ownerUid,
      'scope': scope,
      'source': source,
      'dataSources': dataSources.map((d) => d.toMap()).toList(growable: false),
      // Legacy singular `dataSource` mirrors the first entry so any old
      // reader (including the runner) still finds the descriptor it
      // expects. Removed when the runner consumes `dataSources` directly.
      if (ds != null) 'dataSource': ds.toMap(),
      if (outputSummary.isNotEmpty) 'outputSummary': outputSummary,
      // Legacy nested shape for the Cloud Run runner's
      // resolveOutputBridge(task.bridge) dispatch.
      'bridge': <String, dynamic>{
        'type': bridgeType,
        'scope': scope,
      },
    };
  }

  factory AgentTaskDefinition.fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snap,
  ) {
    final d = snap.data() ?? const <String, dynamic>{};
    // Prefer the new `dataSources` array; fall back to the legacy singular
    // `dataSource` map so docs created before the array landed still read
    // cleanly. An empty result means "no data source configured yet".
    final List<AgentTaskDataSource> dataSources;
    final rawDataSources = d['dataSources'];
    if (rawDataSources is List && rawDataSources.isNotEmpty) {
      dataSources = rawDataSources
          .whereType<Map>()
          .map((e) => AgentTaskDataSource.fromMap(e.cast<String, dynamic>()))
          .toList(growable: false);
    } else if (d['dataSource'] is Map) {
      dataSources = <AgentTaskDataSource>[
        AgentTaskDataSource.fromMap(
          (d['dataSource'] as Map).cast<String, dynamic>(),
        ),
      ];
    } else {
      dataSources = const <AgentTaskDataSource>[];
    }
    // `processingPrompt` is authoritative; legacy `prompt` field migrates
    // into it when the new field is absent.
    final legacyPrompt = (d['prompt'] as String?)?.trim();
    final processingPrompt = (d['processingPrompt'] as String?)?.trim();
    return AgentTaskDefinition(
      taskId: (d['taskId'] as String?) ?? snap.id,
      companyId: (d['companyId'] as String?) ?? '',
      name: (d['name'] as String?)?.trim().isEmpty == true
          ? 'Untitled task'
          : (d['name'] as String?) ?? 'Untitled task',
      description: d['description'] as String?,
      retrievalPrompt: d['retrievalPrompt'] as String?,
      processingPrompt:
          (processingPrompt != null && processingPrompt.isNotEmpty)
              ? processingPrompt
              : (legacyPrompt != null && legacyPrompt.isNotEmpty
                  ? legacyPrompt
                  : null),
      outputPrompt: d['outputPrompt'] as String?,
      deliverable: _deliverableFromString(d['deliverable'] as String?),
      bridgeType: (d['bridgeType'] as String?) ?? 'occupancy_proposal',
      enabled: (d['enabled'] as bool?) ?? false,
      schedule: AgentTaskSchedule.fromMap(
        (d['schedule'] as Map?)?.cast<String, dynamic>(),
      ),
      ownerUid: d['ownerUid'] as String?,
      scope: d['scope'] is Map
          ? (d['scope'] as Map).cast<String, dynamic>()
          : const <String, dynamic>{},
      source: d['source'] is Map
          ? (d['source'] as Map).cast<String, dynamic>()
          : const <String, dynamic>{},
      dataSources: dataSources,
      outputSummary: d['outputSummary'] is List
          ? (d['outputSummary'] as List)
              .whereType<String>()
              .toList(growable: false)
          : const <String>[],
      lastRunAt: _toDate(d['lastRunAt']),
      lastRunId: d['lastRunId'] as String?,
      nextRunAt: _toDate(d['nextRunAt']),
    );
  }
}

DateTime? _toDate(Object? value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return null;
}
