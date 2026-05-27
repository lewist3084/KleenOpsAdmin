// lib/features/training/screens/training_employees_charts.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class TrainingEmployeesChartsContent extends ConsumerWidget {
  final String? teamId;
  const TrainingEmployeesChartsContent({super.key, this.teamId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const Center(child: Text('Charts coming soon.'));
  }
}
