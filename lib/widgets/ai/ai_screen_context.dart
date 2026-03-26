// lib/widgets/ai/ai_screen_context.dart
// Stub — admin app does not use AI canvas overlay.

import 'package:flutter/material.dart';
import 'package:kleenops_admin/services/ai/ai_context_service.dart';

/// No-op wrapper that simply renders its child.
class AiScreenContext extends StatelessWidget {
  const AiScreenContext({
    super.key,
    required this.context,
    required this.child,
  });

  final AiContextState context;
  final Widget child;

  @override
  Widget build(BuildContext buildCtx) => child;
}
