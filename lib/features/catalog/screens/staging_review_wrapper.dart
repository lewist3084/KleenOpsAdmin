// lib/features/catalog/screens/staging_review_wrapper.dart
//
// Wraps the StagingReviewScreen with an admin-style AppBar and back navigation.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../theme/palette.dart';
import 'marketplaceStagingReview.dart';

class StagingReviewWrapper extends StatelessWidget {
  const StagingReviewWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    const palette = adminPalette;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Staging Review'),
        backgroundColor: palette.primary1,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(AppRoutePaths.catalog),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.build),
            tooltip: 'Web Scraping',
            onPressed: () => context.go(AppRoutePaths.catalogScrapeJobs),
          ),
        ],
      ),
      body: const StagingReviewScreen(),
    );
  }
}
