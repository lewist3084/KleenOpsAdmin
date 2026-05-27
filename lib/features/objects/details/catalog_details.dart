// lib/features/objects/details/catalog_details.dart
// SKIPPED (986 lines): heavy catalog details screen with deep dependencies on
// admin-absent widgets (image rows expand, AI canvas, marketplace UI).
// Stub keeps dependents compiling.

import 'package:flutter/material.dart';

class CatalogDetailsScreen extends StatelessWidget {
  final String docId;

  const CatalogDetailsScreen({super.key, required this.docId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Catalog Details')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Catalog details for $docId — pending full port.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
