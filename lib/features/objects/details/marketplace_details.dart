// lib/features/objects/details/marketplace_details.dart
// SKIPPED (285 lines): marketplace details screen depends on admin-absent
// portal/communication widgets. Stub for compile compatibility.

import 'package:flutter/material.dart';

class MarketplaceDetailsScreen extends StatelessWidget {
  final String docId;

  const MarketplaceDetailsScreen({super.key, required this.docId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Marketplace Item')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Marketplace details for $docId — pending full port.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
