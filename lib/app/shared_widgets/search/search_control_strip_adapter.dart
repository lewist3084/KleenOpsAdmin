// Kleenops Admin adapter around the shared SearchControlStrip. Defaults
// [createTranscriber] to the Google streaming transcriber so every list
// screen's search box gets mic dictation for free — same contract the
// AITextField adapter uses.

import 'package:flutter/material.dart';
import 'package:shared_widgets/fields/ai_text.dart' as shared_ai;
import 'package:shared_widgets/search/search_control_strip.dart' as shared;

import 'package:kleenops_admin/services/ai_text_adapter.dart'
    show createGoogleStreamingTranscriber;

export 'package:shared_widgets/search/search_control_strip.dart'
    show SearchStripAction;

class SearchControlStrip extends StatelessWidget {
  const SearchControlStrip({
    super.key,
    required this.controller,
    required this.onChanged,
    this.hintText = 'Search',
    this.trailingActions = const <shared.SearchStripAction>[],
    this.autofocus = true,
    this.focusNode,
    this.textInputAction,
    this.onSubmitted,
    this.createTranscriber,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String hintText;
  final List<shared.SearchStripAction> trailingActions;
  final bool autofocus;
  final FocusNode? focusNode;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final shared_ai.LiveChunkedTranscriber Function()? createTranscriber;

  @override
  Widget build(BuildContext context) {
    return shared.SearchControlStrip(
      controller: controller,
      onChanged: onChanged,
      hintText: hintText,
      trailingActions: trailingActions,
      autofocus: autofocus,
      focusNode: focusNode,
      textInputAction: textInputAction,
      onSubmitted: onSubmitted,
      createTranscriber:
          createTranscriber ?? createGoogleStreamingTranscriber,
    );
  }
}
