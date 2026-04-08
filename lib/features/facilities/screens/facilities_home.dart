// lib/features/facilities/screens/facilities_home.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_widgets/containers/standard_canvas.dart';

import '../../../app/routes.dart';
import '../../../theme/palette.dart';

class FacilitiesHome extends StatelessWidget {
  const FacilitiesHome({super.key});

  @override
  Widget build(BuildContext context) {
    const palette = adminPalette;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Facilities'),
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
              Icon(Icons.business_outlined, size: 64, color: palette.primary3),
              const SizedBox(height: 16),
              Text(
                'Facilities',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              const Text('Manage properties, buildings, and locations.'),
            ],
          ),
        ),
      ),
    );
  }
}
