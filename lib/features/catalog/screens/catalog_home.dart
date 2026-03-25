// lib/features/catalog/screens/catalog_home.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_widgets/containers/standard_canvas.dart';

import '../../../app/routes.dart';
import '../../../theme/palette.dart';
import 'catalog.dart';

/// Admin catalog hub with tabs for browsing, scraping, and staging.
class CatalogHome extends StatefulWidget {
  const CatalogHome({super.key});

  @override
  State<CatalogHome> createState() => _CatalogHomeState();
}

class _CatalogHomeState extends State<CatalogHome>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 1, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const palette = adminPalette;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Catalog'),
        backgroundColor: palette.primary1,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(AppRoutePaths.dashboard),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.build),
            tooltip: 'Web Scraping',
            onPressed: () => context.go(AppRoutePaths.catalogScrapeJobs),
          ),
          IconButton(
            icon: const Icon(Icons.checklist),
            tooltip: 'Staging Review',
            onPressed: () => context.go(AppRoutePaths.catalogStagingReview),
          ),
        ],
      ),
      body: StandardCanvas(
        child: const CatalogContent(),
      ),
    );
  }
}
