// lib/features/training/widgets/training_choice_quiz_tile.dart

import 'package:flutter/material.dart';
import 'package:shared_widgets/tiles/choice_survey_tile.dart';

class TrainingChoiceQuizTile extends StatelessWidget {
  const TrainingChoiceQuizTile({
    super.key,
    required this.prompt,
    this.helpText,
    this.options = const [],
    this.optionLabels,
    this.allowMultiple = false,
    this.allowOther = false,
    this.shuffleOptions = false,
    this.isRequired = true,
    this.onTap,
  });

  final String prompt;
  final String? helpText;
  final List<String> options;
  final Map<String, String>? optionLabels;
  final bool allowMultiple;
  final bool allowOther;
  final bool shuffleOptions;
  final bool isRequired;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceSurveyTile(
      prompt: prompt,
      helpText: helpText,
      options: options,
      optionLabels: optionLabels,
      allowMultiple: allowMultiple,
      allowOther: allowOther,
      shuffleOptions: shuffleOptions,
      isRequired: isRequired,
      onTap: onTap,
    );
  }
}
