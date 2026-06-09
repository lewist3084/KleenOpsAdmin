// lib/services/ai/ai_context_service.dart
// Stub for AI context service — admin app does not use AI canvas.

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AiContextState {
  const AiContextState({
    this.key = '',
    this.sectionKey = '',
    this.screenType = '',
    this.label,
    this.entityId,
    this.entityPath,
    this.metadata = const <String, String>{},
    this.fileContext = const <String, String>{},
    this.forms = const <AiFormDescriptor>[],
    this.actions = const <AiActionDescriptor>[],
    this.guidance,
    this.title,
    this.subtitle,
    this.onImageAccepted,
    this.onVideoAccepted,
    this.onFileAccepted,
  });

  const AiContextState.empty()
      : key = '',
        sectionKey = '',
        screenType = '',
        label = null,
        entityId = null,
        entityPath = null,
        metadata = const <String, String>{},
        fileContext = const <String, String>{},
        forms = const <AiFormDescriptor>[],
        actions = const <AiActionDescriptor>[],
        guidance = null,
        title = null,
        subtitle = null,
        onImageAccepted = null,
        onVideoAccepted = null,
        onFileAccepted = null;

  final String key;
  final String sectionKey;
  final String screenType;
  final String? label;
  final String? entityId;
  final String? entityPath;
  final Map<String, String> metadata;
  final Map<String, String> fileContext;
  final List<AiFormDescriptor> forms;
  final List<AiActionDescriptor> actions;
  final String? guidance;
  final String? title;
  final String? subtitle;
  final VoidCallback? onImageAccepted;
  final VoidCallback? onVideoAccepted;
  final VoidCallback? onFileAccepted;
}

class AiFormDescriptor {
  const AiFormDescriptor({required this.name, this.fields = const <String>[]});
  final String name;
  final List<String> fields;
}

class AiActionDescriptor {
  const AiActionDescriptor({
    required this.id,
    required this.label,
    this.requiredFields = const <String>[],
  });
  final String id;
  final String label;
  final List<String> requiredFields;
}

/// No-op presets for the admin app.
class AiContextPresets {
  static AiContextState detailScreen({
    required String key,
    required String sectionKey,
    String? label,
    String? entityId,
    String? entityPath,
  }) =>
      AiContextState(
        key: key,
        sectionKey: sectionKey,
        screenType: 'detail',
        label: label,
        entityId: entityId,
        entityPath: entityPath,
      );

  static AiContextState objectElementDetails({
    required String objectId,
    required String elementId,
    String? label,
  }) =>
      AiContextState(
        key: 'objectElementDetails',
        sectionKey: 'objects',
        screenType: 'detail',
        label: label,
        entityId: elementId,
      );

  static AiContextState objectProcessDetails({
    required String objectId,
    required String processId,
    String? label,
  }) =>
      AiContextState(
        key: 'objectProcessDetails',
        sectionKey: 'objects',
        screenType: 'detail',
        label: label,
        entityId: processId,
      );

  // ---- Engagement (admin stubs) ----
  static AiContextState engagementSurveyDetails({
    String? surveyId,
    String? label,
    String? entityPath,
  }) =>
      AiContextState(
        key: 'engagementSurveyDetails',
        sectionKey: 'engagement',
        screenType: 'detail',
        label: label,
        entityId: surveyId,
        entityPath: entityPath,
      );

  static AiContextState engagementReports() => const AiContextState(
        key: 'engagementReports',
        sectionKey: 'engagement',
        screenType: 'list',
      );

  static AiContextState engagementStats() => const AiContextState(
        key: 'engagementStats',
        sectionKey: 'engagement',
        screenType: 'stats',
      );

  static AiContextState engagementSurveys() => const AiContextState(
        key: 'engagementSurveys',
        sectionKey: 'engagement',
        screenType: 'list',
      );

  // ---- Quality (admin stubs) ----
  static AiContextState qualityInspections() => const AiContextState(
        key: 'qualityInspections',
        sectionKey: 'quality',
        screenType: 'list',
      );

  static AiContextState qualityInspectionDetails({
    String? inspectionId,
    String? label,
    String? entityPath,
  }) =>
      AiContextState(
        key: 'qualityInspectionDetails',
        sectionKey: 'quality',
        screenType: 'detail',
        label: label,
        entityId: inspectionId,
        entityPath: entityPath,
      );

  static AiContextState qualityStats() => const AiContextState(
        key: 'qualityStats',
        sectionKey: 'quality',
        screenType: 'stats',
      );

  static AiContextState qualityTeams() => const AiContextState(
        key: 'qualityTeams',
        sectionKey: 'quality',
        screenType: 'list',
      );

  static const List<AiFormDescriptor> qualityForms = <AiFormDescriptor>[];
  static const List<AiActionDescriptor> qualityActions =
      <AiActionDescriptor>[];
  static const String qualityGuidance = '';

  // ---- Safety (admin stubs) ----
  static AiContextState safetyAnalysis() => const AiContextState(
        key: 'safetyAnalysis',
        sectionKey: 'safety',
        screenType: 'list',
      );

  static AiContextState safetyAnalysisDetails({
    String? analysisId,
    String? label,
    String? entityPath,
  }) =>
      AiContextState(
        key: 'safetyAnalysisDetails',
        sectionKey: 'safety',
        screenType: 'detail',
        label: label,
        entityId: analysisId,
        entityPath: entityPath,
      );

  static AiContextState safetyAnalysisProcessDetails({
    String? processId,
    String? label,
    String? entityPath,
  }) =>
      AiContextState(
        key: 'safetyAnalysisProcessDetails',
        sectionKey: 'safety',
        screenType: 'detail',
        label: label,
        entityId: processId,
        entityPath: entityPath,
      );

  static AiContextState safetyFailureModeDetails({
    String? failureModeId,
    String? label,
    String? entityPath,
  }) =>
      AiContextState(
        key: 'safetyFailureModeDetails',
        sectionKey: 'safety',
        screenType: 'detail',
        label: label,
        entityId: failureModeId,
        entityPath: entityPath,
      );

  static AiContextState safetyPotentialCauseDetails({
    String? causeId,
    String? potentialCauseId,
    String? label,
    String? entityPath,
  }) =>
      AiContextState(
        key: 'safetyPotentialCauseDetails',
        sectionKey: 'safety',
        screenType: 'detail',
        label: label,
        entityId: causeId ?? potentialCauseId,
        entityPath: entityPath,
      );

  static AiContextState safetyResponse() => const AiContextState(
        key: 'safetyResponse',
        sectionKey: 'safety',
        screenType: 'list',
      );

  static AiContextState safetyStats() => const AiContextState(
        key: 'safetyStats',
        sectionKey: 'safety',
        screenType: 'stats',
      );

  // ---- Training (admin stubs) ----
  static AiContextState trainingList() => const AiContextState(
        key: 'trainingList',
        sectionKey: 'training',
        screenType: 'list',
      );

  static AiContextState trainingEmployees() => const AiContextState(
        key: 'trainingEmployees',
        sectionKey: 'training',
        screenType: 'list',
      );

  static AiContextState trainingTeams() => const AiContextState(
        key: 'trainingTeams',
        sectionKey: 'training',
        screenType: 'list',
      );

  static AiContextState trainingDetails({
    String? trainingId,
    String? label,
  }) =>
      AiContextState(
        key: 'trainingDetails',
        sectionKey: 'training',
        screenType: 'detail',
        label: label,
        entityId: trainingId,
      );

  static const List<AiFormDescriptor> trainingForms = <AiFormDescriptor>[];
  static const List<AiActionDescriptor> trainingActions =
      <AiActionDescriptor>[];
  static const String trainingGuidance = '';
  static const String trainingImagePromptContext = '';
  static const String trainingVideoPromptContext = '';

  // ---- Email (admin stubs) ----
  static AiContextState emailInbox() => const AiContextState(
        key: 'emailInbox',
        sectionKey: 'email',
        screenType: 'list',
      );

  static AiContextState emailCompose() => const AiContextState(
        key: 'emailCompose',
        sectionKey: 'email',
        screenType: 'compose',
      );

  static AiContextState emailDetail({
    required String emailId,
    String? label,
    String? entityPath,
  }) =>
      AiContextState(
        key: 'emailDetail',
        sectionKey: 'email',
        screenType: 'detail',
        label: label,
        entityId: emailId,
        entityPath: entityPath,
      );

  static AiContextState emailSettings() => const AiContextState(
        key: 'emailSettings',
        sectionKey: 'email',
        screenType: 'settings',
      );
}

/// No-op controller stub.
class AiCanvasController {
  void toggle() {}
}

class AiContextController extends Notifier<AiContextState> {
  @override
  AiContextState build() => const AiContextState.empty();
  void push(String token, AiContextState ctx) {}
  void pop(String token) {}
}

/// Provider stubs.
final aiCanvasControllerProvider = Provider<AiCanvasController>((ref) {
  return AiCanvasController();
});

final aiContextProvider =
    NotifierProvider<AiContextController, AiContextState>(
        AiContextController.new);
