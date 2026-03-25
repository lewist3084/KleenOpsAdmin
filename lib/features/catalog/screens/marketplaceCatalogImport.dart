// marketplaceCatalogImport.dart — placeholder for admin app.
// TODO: Migrate full PDF catalog import from kleenops app.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class MarketplaceCatalogImportScreen extends StatefulWidget {
  final DocumentReference<Map<String, dynamic>> companyRef;

  const MarketplaceCatalogImportScreen({
    super.key,
    required this.companyRef,
  });

  @override
  State<MarketplaceCatalogImportScreen> createState() =>
      _MarketplaceCatalogImportScreenState();
}

class _MarketplaceCatalogImportScreenState
    extends State<MarketplaceCatalogImportScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Import Catalog PDF')),
      body: const Center(
        child: Text('PDF catalog import — coming soon'),
      ),
    );
  }
}
