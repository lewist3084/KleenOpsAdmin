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
