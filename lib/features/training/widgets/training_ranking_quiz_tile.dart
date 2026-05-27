// lib/features/training/widgets/training_ranking_quiz_tile.dart

import 'package:flutter/material.dart';
import 'package:shared_widgets/tiles/ranking_survey_tile.dart';

class TrainingRankingQuizTile extends StatelessWidget {
  const TrainingRankingQuizTile({
    super.key,
    required this.prompt,
    this.helpText,
    this.items = const [],
    this.itemLabels,
    this.isRequired = true,
    this.onTap,
  });

  final String prompt;
  final String? helpText;
  final List<String> items;
  final Map<String, String>? itemLabels;
  final bool isRequired;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return RankingSurveyTile(
      prompt: prompt,
      helpText: helpText,
      items: items,
      itemLabels: itemLabels,
      isRequired: isRequired,
      onTap: onTap,
    );
  }
}
