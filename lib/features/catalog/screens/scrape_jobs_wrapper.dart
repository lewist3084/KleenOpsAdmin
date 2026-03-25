// lib/features/catalog/screens/scrape_jobs_wrapper.dart
//
// Wraps the ScrapeJobsScreen with an admin-style AppBar and back navigation.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../theme/palette.dart';
import 'marketplaceScrapeJobs.dart';

class ScrapeJobsWrapper extends StatelessWidget {
  const ScrapeJobsWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    const palette = adminPalette;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Web Scraping'),
        backgroundColor: palette.primary1,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(AppRoutePaths.catalog),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.checklist),
            tooltip: 'Staging Review',
            onPressed: () => context.go(AppRoutePaths.catalogStagingReview),
          ),
        ],
      ),
      body: const ScrapeJobsScreen(),
    );
  }
}
