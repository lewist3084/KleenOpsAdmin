// lib/features/scheduling/screens/scheduling_home.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_widgets/containers/standard_canvas.dart';

import '../../../app/routes.dart';
import '../../../theme/palette.dart';

class SchedulingHome extends StatelessWidget {
  const SchedulingHome({super.key});

  @override
  Widget build(BuildContext context) {
    const palette = adminPalette;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scheduling'),
        backgroundColor: palette.primary1,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(AppRoutePaths.dashboard),
        ),
      ),
      body: StandardCanvas(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.view_timeline_outlined, size: 64, color: palette.primary3),
              const SizedBox(height: 16),
              Text(
                'Scheduling',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              const Text('Schedule teams and manage timelines.'),
            ],
          ),
        ),
      ),
    );
  }
}
