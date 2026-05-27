// lib/features/occupancy/services/agent_task_wizard_service.dart
//
// Conversational wizard backed by Gemini that turns free-text intent into
// a concrete [AgentTaskDefinition]. Stateless on its own — the screen
// owns the chat history and replays it on every call. Each turn the
// model decides whether it needs more info (a follow-up question) or it
// has enough to emit a structured proposal.
//
// Loose during setup, tight in execution: the saved task definition is
// rigid (cron + scope + source map) so the runner can re-execute
// deterministically without consulting the LLM again.

import 'dart:convert';

import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kleenops_admin/features/occupancy/models/agent_task_definition.dart';

/// One turn in the wizard conversation.
class WizardTurn {
  const WizardTurn({required this.role, required this.text});
  final String role; // 'user' | 'assistant'
  final String text;

  bool get isUser => role == 'user';
  bool get isAssistant => role == 'assistant';
}

/// What the model returned this turn — either a question for the user
/// or a complete proposal ready to save.
class WizardResponse {
  const WizardResponse({
    this.followUp,
    this.proposal,
    this.summary,
    this.reasoning,
  });

  /// Non-null when the model wants more info before proposing.
  final String? followUp;

  /// Non-null when the model has enough to produce a complete task.
  /// `taskId` and `companyId` are filled by the caller (the wizard
  /// screen) since the service has no allocator.
  final AgentTaskDefinition? proposal;

  /// One-line description of what the proposal will do.
  final String? summary;

  /// Why the model made these choices — shown as a "Reasoning" line on
  /// the preview card.
  final String? reasoning;

  bool get hasProposal => proposal != null;
  bool get hasFollowUp => followUp != null && followUp!.trim().isNotEmpty;
}

class AgentTaskWizardException implements Exception {
  const AgentTaskWizardException(this.message);
  final String message;
  @override
  String toString() => 'AgentTaskWizardException: $message';
}

class AgentTaskWizardService {
  AgentTaskWizardService._();
  static final AgentTaskWizardService instance = AgentTaskWizardService._();

  static const String _systemPrompt = '''
You are helping the operator turn an idea into an "agent task" — a
recurring (or on-demand) piece of work the system runs automatically.

Think of yourself as a capable assistant scoping a job. Have a natural,
intelligent conversation — the way you normally would — until you
understand the work well enough to set it up. Do NOT follow a rigid
script or interrogate from a checklist. Ask whatever a thoughtful person
would genuinely need to ask, in whatever order the conversation makes
natural, one question at a time. If the user already told you something,
don't ask it. If something is obvious or low-stakes, make a reasonable
assumption instead of asking. If the user asks YOU a question, answer it
helpfully — don't ignore it to push your own next question.

Each turn: either ASK ONE concise question, or — once you genuinely
understand the task — PROPOSE the complete definition.

WHAT YOU'RE BUILDING. The task definition is split into three execution
stages so the user can audit each one. By the end you must fill out all of
this (the runner uses ONLY these fields — no LLM runs at execution time):
- name + description: ALWAYS write these yourself from the conversation.
  Never ask for them.

- RETRIEVAL stage — how to fetch the data:
  - data_sources: an ARRAY of one or more sources. Each entry has
    mode ("internal" or "external"), and for external: url, optional
    username (only if the site requires a login — use judgment, ask if
    unclear, never assume), optional download_url (if the file has a
    direct REST endpoint like /rest_v2/...xlsx), optional
    post_login_url_pattern if known. Most tasks have one source; only
    add multiple when the user describes pulling from distinct places.
  - retrieval_prompt: OPTIONAL 1-3 sentence guidance on WHAT to pull —
    e.g. "Only rows where Status = Confirmed; ignore historical rows
    older than 14 days". Leave null if there's nothing to qualify.

- PROCESSING stage — what the AI does with the collected data:
  - processing_prompt: REQUIRED. 1-4 sentence instruction — e.g. "Match
    each row to a building occupant and produce a reservation per
    classroom-day". Infer if it's clear; ask if it isn't.

- OUTPUT stage — how the result is delivered:
  - deliverable: exactly one of "text" (a message in the AI canvas),
    "email", "text_message", "file", "image", "database_changes"
    (records/edits queued for swipe-approval — e.g. occupancy
    reservations).
  - output_prompt: OPTIONAL 1-3 sentence shaping instruction — e.g.
    "Group by building; one row per reservation". Leave null if the
    deliverable shape is obvious.

- schedule: "weekly" (with day_of_week 1=Mon..7=Sun, hour 0-23, minute,
  timezone IANA — default "America/Denver") or "manual" (on-demand).
- scope: for occupancy work, propertyId/buildingId/floorId.
- bridge_type: "occupancy_proposal" (the only fully built one today) or
  the closest match — note any gap in your reasoning.
- output_summary: 1-3 short bullets describing what the workflow
  produces, written in the user's voice.

BACK-COMPAT NOTE: the legacy top-level `prompt` and `data_source` fields
still exist in the schema. Do NOT use them for new proposals — use
`processing_prompt` and `data_sources` instead.

HARD RULES — these are not flexible:
1. Output strict JSON matching the schema — no prose outside the JSON,
   no markdown fences. Use type:"follow_up" with follow_up_question
   while still gathering; type:"proposal" with proposal{...} plus a
   short summary and reasoning once you're done.
2. NEVER ask for or accept a password. The user sets it securely (Secret
   Manager) after the task is created. A username is fine; a password
   never is.
3. The user does NOT know Firestore IDs — only facility NAMES. A
   "COMPANY FACILITY HIERARCHY" (names + IDs) is provided as context.
   Resolve any property/building/floor name to its ID yourself. Never
   ask for an ID; ask by name only when a name is missing or ambiguous.
   If a report spans multiple floors, use the building's first floor and
   say so in your reasoning.
4. Infer name and description — never spend a turn asking for them.

EDIT MODE: when a "CURRENT TASK CONFIGURATION" message appears, the user
is adjusting an existing task. Treat that JSON as the starting point,
change only what they ask, carry everything else through unchanged, and
always propose the COMPLETE definition.

Style: friendly, concise, genuinely conversational — one question per
turn, no restating what they already said. Don't propose until you
actually understand the task, but don't drag it out either.
''';

  Schema get _schema => Schema.object(
        properties: <String, Schema>{
          'type': Schema.string(),
          'follow_up_question': Schema.string(nullable: true),
          'summary': Schema.string(nullable: true),
          'reasoning': Schema.string(nullable: true),
          'proposal': Schema.object(
            nullable: true,
            properties: <String, Schema>{
              'name': Schema.string(),
              'description': Schema.string(nullable: true),
              // Three-stage prompt set. `prompt` is the legacy single field,
              // kept here only so older completions don't crash the parser —
              // new proposals must use the stage-specific keys.
              'retrieval_prompt': Schema.string(nullable: true),
              'processing_prompt': Schema.string(nullable: true),
              'output_prompt': Schema.string(nullable: true),
              'prompt': Schema.string(nullable: true),
              'deliverable': Schema.string(nullable: true),
              'bridge_type': Schema.string(),
              'schedule': Schema.object(
                properties: <String, Schema>{
                  'mode': Schema.string(),
                  'day_of_week': Schema.integer(nullable: true),
                  'hour': Schema.integer(nullable: true),
                  'minute': Schema.integer(nullable: true),
                  'timezone': Schema.string(nullable: true),
                },
                optionalProperties: const <String>[
                  'day_of_week',
                  'hour',
                  'minute',
                  'timezone',
                ],
              ),
              'scope': Schema.object(
                properties: <String, Schema>{
                  'propertyId': Schema.string(nullable: true),
                  'buildingId': Schema.string(nullable: true),
                  'floorId': Schema.string(nullable: true),
                  'teamId': Schema.string(nullable: true),
                },
                optionalProperties: const <String>[
                  'propertyId',
                  'buildingId',
                  'floorId',
                  'teamId',
                ],
              ),
              'source': Schema.object(
                properties: <String, Schema>{
                  'url': Schema.string(nullable: true),
                  'type': Schema.string(nullable: true),
                  'credentials': Schema.string(nullable: true),
                },
                optionalProperties: const <String>[
                  'url',
                  'type',
                  'credentials',
                ],
              ),
              // New: list of data sources. Each entry mirrors the shape of
              // the legacy `data_source` object. Most tasks emit a single
              // entry; multi-source is reserved for tasks that genuinely
              // pull from distinct places.
              'data_sources': Schema.array(
                nullable: true,
                items: Schema.object(
                  properties: <String, Schema>{
                    'mode': Schema.string(),
                    'url': Schema.string(nullable: true),
                    'username': Schema.string(nullable: true),
                    'download_url': Schema.string(nullable: true),
                    'post_login_url_pattern': Schema.string(nullable: true),
                  },
                  optionalProperties: const <String>[
                    'url',
                    'username',
                    'download_url',
                    'post_login_url_pattern',
                  ],
                ),
              ),
              // Legacy single descriptor — kept so a model that ignores the
              // new key still produces a usable proposal.
              'data_source': Schema.object(
                nullable: true,
                properties: <String, Schema>{
                  'mode': Schema.string(),
                  'url': Schema.string(nullable: true),
                  'username': Schema.string(nullable: true),
                  'download_url': Schema.string(nullable: true),
                  'post_login_url_pattern': Schema.string(nullable: true),
                },
                optionalProperties: const <String>[
                  'url',
                  'username',
                  'download_url',
                  'post_login_url_pattern',
                ],
              ),
              'output_summary': Schema.array(
                items: Schema.string(),
                nullable: true,
              ),
            },
            optionalProperties: const <String>[
              'description',
              'retrieval_prompt',
              'processing_prompt',
              'output_prompt',
              'prompt',
              'deliverable',
              'data_source',
              'data_sources',
              'output_summary',
            ],
          ),
        },
        optionalProperties: const <String>[
          'follow_up_question',
          'summary',
          'reasoning',
          'proposal',
        ],
      );

  /// Run one turn of the wizard. [history] should include the latest
  /// user turn; the service appends the assistant's reply itself only
  /// in the response object — the screen decides what to retain.
  ///
  /// [companyId] is forwarded so the model knows which scope context
  /// it's drafting for; today only used to stamp on the proposal, but
  /// future versions may inject available facility data here.
  ///
  /// [existingTask] switches the wizard into edit mode: its current
  /// configuration is injected as context so the model adjusts only what
  /// the user asks and preserves every other field.
  ///
  /// [facilityContext] is the company's property/building/floor tree
  /// (names + IDs). Injected so the model can resolve the facility NAMES
  /// the user gives into the IDs `scope` needs — never asking for an ID.
  Future<WizardResponse> next({
    required List<WizardTurn> history,
    required String companyId,
    AgentTaskDefinition? existingTask,
    String? facilityContext,
  }) async {
    if (history.isEmpty) {
      throw const AgentTaskWizardException(
        'Wizard requires at least one user turn to respond to.',
      );
    }

    final model = FirebaseAI.vertexAI().generativeModel(
      model: 'gemini-2.5-flash',
      generationConfig: GenerationConfig(
        temperature: 0.4,
        // A full proposal (description + prompt + reasoning + summary +
        // scope + source + output_summary) easily exceeds 1k tokens; too
        // low a cap truncates the JSON mid-string and jsonDecode fails.
        maxOutputTokens: 8192,
        responseMimeType: 'application/json',
        responseSchema: _schema,
      ),
      systemInstruction: Content.system(_systemPrompt),
    );

    final contents = <Content>[];
    // Lead with reference context the model needs but the user should
    // never see in the chat: the facility name↔ID hierarchy, and (in
    // edit mode) the current task config. Combined into one turn so the
    // contents stay cleanly user/model alternating.
    final contextParts = <String>[];
    if (facilityContext != null && facilityContext.trim().isNotEmpty) {
      contextParts.add(facilityContext.trim());
    }
    if (existingTask != null) {
      contextParts.add(
        'CURRENT TASK CONFIGURATION (the user is editing this task):\n'
        '${jsonEncode(_editContextJson(existingTask))}',
      );
    }
    if (contextParts.isNotEmpty) {
      contents.add(Content.text(contextParts.join('\n\n')));
    }
    for (final turn in history) {
      if (turn.isUser) {
        contents.add(Content.text(turn.text));
      } else {
        contents.add(Content.model(<Part>[TextPart(turn.text)]));
      }
    }

    final GenerateContentResponse response;
    try {
      response = await model.generateContent(contents);
    } catch (e) {
      throw AgentTaskWizardException('Gemini call failed: $e');
    }

    // A maxTokens finish means the JSON is truncated — surface that
    // plainly instead of letting jsonDecode throw a cryptic "unterminated
    // string" error.
    final finishReason = response.candidates.isNotEmpty
        ? response.candidates.first.finishReason
        : null;
    if (finishReason == FinishReason.maxTokens) {
      throw const AgentTaskWizardException(
        'That reply was too long and got cut off before I could finish. '
        'Send your last message again — shorter answers help.',
      );
    }

    final text = response.text?.trim();
    if (text == null || text.isEmpty) {
      throw const AgentTaskWizardException(
        'Gemini returned an empty response.',
      );
    }

    Map<String, dynamic> parsed;
    try {
      parsed = jsonDecode(text) as Map<String, dynamic>;
    } catch (e) {
      throw AgentTaskWizardException('Could not decode Gemini JSON: $e');
    }

    final type = (parsed['type'] as String?)?.toLowerCase() ?? 'follow_up';
    final summary = parsed['summary'] as String?;
    final reasoning = parsed['reasoning'] as String?;

    if (type == 'proposal' && parsed['proposal'] is Map) {
      final proposal = _parseProposal(
        (parsed['proposal'] as Map).cast<String, dynamic>(),
        companyId: companyId,
        existingTask: existingTask,
      );
      return WizardResponse(
        proposal: proposal,
        summary: summary,
        reasoning: reasoning,
      );
    }

    final followUp = (parsed['follow_up_question'] as String?)?.trim();
    if (followUp == null || followUp.isEmpty) {
      throw const AgentTaskWizardException(
        'Gemini did not return a follow-up question or a proposal.',
      );
    }
    return WizardResponse(followUp: followUp, reasoning: reasoning);
  }

  /// Compact snapshot of an existing task in the wizard's own snake_case
  /// shape, injected as conversation context when editing so the model
  /// knows the current values and only changes what's asked.
  Map<String, dynamic> _editContextJson(AgentTaskDefinition task) {
    return <String, dynamic>{
      'name': task.name,
      if (task.description != null && task.description!.isNotEmpty)
        'description': task.description,
      if (task.retrievalPrompt != null && task.retrievalPrompt!.isNotEmpty)
        'retrieval_prompt': task.retrievalPrompt,
      if (task.processingPrompt != null && task.processingPrompt!.isNotEmpty)
        'processing_prompt': task.processingPrompt,
      if (task.outputPrompt != null && task.outputPrompt!.isNotEmpty)
        'output_prompt': task.outputPrompt,
      'deliverable': task.deliverable.wireValue,
      'bridge_type': task.bridgeType,
      'schedule': <String, dynamic>{
        'mode': task.isWeekly ? 'weekly' : 'manual',
        'day_of_week': task.schedule.dayOfWeek,
        'hour': task.schedule.hour,
        'minute': task.schedule.minute,
        'timezone': task.schedule.timezone,
      },
      'scope': Map<String, dynamic>.from(task.scope)..remove('companyId'),
      'data_sources': task.dataSources
          .map((d) => <String, dynamic>{
                'mode': d.isExternal ? 'external' : 'internal',
                if (d.url != null) 'url': d.url,
                if (d.username != null) 'username': d.username,
              })
          .toList(growable: false),
      if (task.outputSummary.isNotEmpty)
        'output_summary': task.outputSummary,
    };
  }

  AgentTaskDefinition _parseProposal(
    Map<String, dynamic> data, {
    required String companyId,
    AgentTaskDefinition? existingTask,
  }) {
    final scheduleMap = (data['schedule'] is Map)
        ? (data['schedule'] as Map).cast<String, dynamic>()
        : const <String, dynamic>{};
    final modeString = (scheduleMap['mode'] as String?)?.toLowerCase() ??
        (existingTask != null
            ? (existingTask.isWeekly ? 'weekly' : 'manual')
            : 'weekly');
    final mode = modeString == 'manual'
        ? AgentTaskScheduleMode.manual
        : AgentTaskScheduleMode.weekly;

    final scope = (data['scope'] is Map)
        ? Map<String, dynamic>.from(data['scope'] as Map)
        : (existingTask != null
            ? Map<String, dynamic>.from(existingTask.scope)
            : <String, dynamic>{});
    scope.removeWhere((k, v) => v == null);
    scope['companyId'] = companyId;

    // Start the runner-shaped `source` map from the existing task so
    // edit-mode round-trips preserve fields the wizard never surfaces
    // (secretRef, export triggers, custom selectors). Anything the model
    // returns in its own `source` block overlays it.
    final source = <String, dynamic>{
      if (existingTask != null) ...existingTask.source,
      if (data['source'] is Map)
        ...Map<String, dynamic>.from(data['source'] as Map),
    };
    source.removeWhere((k, v) => v == null);

    // Prefer `data_sources` (array); fall back to the legacy `data_source`
    // (singular) so older model completions still produce a list.
    final List<Map<String, dynamic>> rawDataSources;
    if (data['data_sources'] is List) {
      rawDataSources = (data['data_sources'] as List)
          .whereType<Map>()
          .map((e) => e.cast<String, dynamic>())
          .toList(growable: false);
    } else if (data['data_source'] is Map) {
      rawDataSources = <Map<String, dynamic>>[
        (data['data_source'] as Map).cast<String, dynamic>(),
      ];
    } else {
      rawDataSources = const <Map<String, dynamic>>[];
    }

    final dataSources = <AgentTaskDataSource>[];
    for (var i = 0; i < rawDataSources.length; i++) {
      final m = rawDataSources[i];
      final modeIsExternal =
          (m['mode'] as String?)?.toLowerCase() == 'external';
      final url = (m['url'] as String?)?.trim();
      final username = (m['username'] as String?)?.trim();
      // Carry through the existing Secret Manager pointer by index so an
      // edit doesn't wipe a previously-saved password on the same slot.
      final existingAtIndex = (existingTask != null &&
              i < existingTask.dataSources.length)
          ? existingTask.dataSources[i]
          : null;
      dataSources.add(AgentTaskDataSource(
        mode: modeIsExternal
            ? AgentTaskDataSourceMode.external
            : AgentTaskDataSourceMode.internal,
        url: (url == null || url.isEmpty) ? null : url,
        username:
            (username == null || username.isEmpty) ? null : username,
        secretRef: existingAtIndex?.secretRef,
      ));
    }
    // If the model returned no sources but we're editing, keep what was
    // already on the task so an edit conversation that only adjusts
    // unrelated fields doesn't drop the sources.
    if (dataSources.isEmpty && existingTask != null) {
      dataSources.addAll(existingTask.dataSources);
    }

    // Pre-populate the runner-shaped `source` map from the FIRST data
    // source so wizard-created tasks are runnable end-to-end. The runner
    // is still single-source today; multi-source dispatch is open work.
    final firstSource = dataSources.isNotEmpty ? dataSources.first : null;
    final firstRaw = rawDataSources.isNotEmpty
        ? rawDataSources.first
        : const <String, dynamic>{};
    final firstDownloadUrl =
        (firstRaw['download_url'] as String?)?.trim();
    final firstPostLoginPattern =
        (firstRaw['post_login_url_pattern'] as String?)?.trim();
    if (firstSource != null && firstSource.isExternal) {
      source['type'] = 'web_login_export';
      if (firstSource.url != null && firstSource.url!.isNotEmpty) {
        source['reportUrl'] = firstSource.url;
        source['url'] = firstSource.url;
      }
      if (firstSource.username != null && firstSource.username!.isNotEmpty) {
        source['username'] = firstSource.username;
      }
      final existingCreds =
          (source['credentials'] as Map?)?.cast<String, dynamic>() ??
              const <String, dynamic>{};
      final credentials = <String, dynamic>{
        ...existingCreds,
        'provider': existingCreds['provider'] ?? 'church_sso',
      };
      if (firstPostLoginPattern != null && firstPostLoginPattern.isNotEmpty) {
        credentials['postLoginUrlPattern'] = firstPostLoginPattern;
      }
      source['credentials'] = credentials;
      if (firstDownloadUrl != null && firstDownloadUrl.isNotEmpty) {
        final existingExport =
            (source['export'] as Map?)?.cast<String, dynamic>();
        source['export'] = <String, dynamic>{
          if (existingExport != null) ...existingExport,
          'trigger': <String, dynamic>{
            'kind': 'rest_get',
            'url': firstDownloadUrl,
            'timeoutMs': 300000,
          },
        };
      }
    }

    final parsedSummary = (data['output_summary'] is List)
        ? (data['output_summary'] as List)
            .whereType<String>()
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList(growable: false)
        : const <String>[];
    final outputSummary = parsedSummary.isNotEmpty
        ? parsedSummary
        : (existingTask?.outputSummary ?? const <String>[]);

    final parsedName = (data['name'] as String?)?.trim();
    final parsedDescription = (data['description'] as String?)?.trim();
    final parsedRetrievalPrompt =
        (data['retrieval_prompt'] as String?)?.trim();
    final parsedProcessingPrompt =
        (data['processing_prompt'] as String?)?.trim();
    final parsedOutputPrompt = (data['output_prompt'] as String?)?.trim();
    // Legacy single `prompt` field — if the model still uses it, fold it
    // into the processing prompt (the closest semantic match).
    final parsedLegacyPrompt = (data['prompt'] as String?)?.trim();
    final parsedDeliverable = (data['deliverable'] as String?)?.trim();
    final deliverable =
        (parsedDeliverable == null || parsedDeliverable.isEmpty)
            ? (existingTask?.deliverable ??
                AgentTaskDeliverable.databaseChanges)
            : agentTaskDeliverableFromWire(parsedDeliverable);

    return AgentTaskDefinition(
      // For a brand-new task the caller (the screen) replaces this with a
      // freshly-allocated id; for an edit it stays the existing one.
      taskId: existingTask?.taskId ?? '',
      companyId: companyId,
      name: (parsedName == null || parsedName.isEmpty)
          ? (existingTask?.name ?? 'New agent task')
          : parsedName,
      description: (parsedDescription == null || parsedDescription.isEmpty)
          ? existingTask?.description
          : parsedDescription,
      retrievalPrompt:
          (parsedRetrievalPrompt == null || parsedRetrievalPrompt.isEmpty)
              ? existingTask?.retrievalPrompt
              : parsedRetrievalPrompt,
      processingPrompt: (parsedProcessingPrompt == null ||
              parsedProcessingPrompt.isEmpty)
          ? ((parsedLegacyPrompt == null || parsedLegacyPrompt.isEmpty)
              ? existingTask?.processingPrompt
              : parsedLegacyPrompt)
          : parsedProcessingPrompt,
      outputPrompt:
          (parsedOutputPrompt == null || parsedOutputPrompt.isEmpty)
              ? existingTask?.outputPrompt
              : parsedOutputPrompt,
      deliverable: deliverable,
      bridgeType: (data['bridge_type'] as String?) ??
          existingTask?.bridgeType ??
          'occupancy_proposal',
      enabled: existingTask?.enabled ?? true,
      ownerUid: existingTask?.ownerUid,
      schedule: AgentTaskSchedule(
        mode: mode,
        dayOfWeek: (scheduleMap['day_of_week'] as num?)?.toInt() ??
            existingTask?.schedule.dayOfWeek ??
            1,
        hour: (scheduleMap['hour'] as num?)?.toInt() ??
            existingTask?.schedule.hour ??
            7,
        minute: (scheduleMap['minute'] as num?)?.toInt() ??
            existingTask?.schedule.minute ??
            0,
        timezone:
            (scheduleMap['timezone'] as String?)?.trim().isEmpty == true
                ? (existingTask?.schedule.timezone ?? 'America/Denver')
                : (scheduleMap['timezone'] as String?) ??
                    existingTask?.schedule.timezone ??
                    'America/Denver',
      ),
      scope: scope,
      source: source,
      dataSources: dataSources,
      outputSummary: outputSummary,
    );
  }
}

final agentTaskWizardServiceProvider = Provider<AgentTaskWizardService>(
  (ref) => AgentTaskWizardService.instance,
);
