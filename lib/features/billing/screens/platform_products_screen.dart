// lib/features/billing/screens/platform_products_screen.dart
//
// Billing entry point to the platform-product catalog. The catalog itself is
// the shared [PlatformCatalogBody] (the same one rendered by the Sales →
// Products tab), so there is a single catalog implementation editing
// `platformProduct`.

import 'package:flutter/material.dart';
import 'package:shared_widgets/containers/standard_canvas.dart';

import '../../../theme/palette.dart';
import '../../sales/widgets/platform_catalog_body.dart';

class PlatformProductsScreen extends StatelessWidget {
  const PlatformProductsScreen({super.key});

  static const _palette = adminPalette;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Platform Products'),
        backgroundColor: _palette.primary1,
        foregroundColor: Colors.white,
      ),
      body: const StandardCanvas(child: PlatformCatalogBody()),
    );
  }
}
