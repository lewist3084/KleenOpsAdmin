// lib/features/quality/screens/quality_home.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_widgets/containers/standard_canvas.dart';

import '../../../app/routes.dart';
import '../../../theme/palette.dart';

class QualityHome extends StatelessWidget {
  const QualityHome({super.key});

  @override
  Widget build(BuildContext context) {
    const palette = adminPalette;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quality'),
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
              Icon(Icons.auto_awesome_outlined, size: 64, color: palette.primary3),
              const SizedBox(height: 16),
              Text(
                'Quality',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              const Text('Quality assurance and inspections.'),
            ],
          ),
        ),
      ),
    );
  }
}
