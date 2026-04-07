// catalog_form.dart — placeholder for admin app.
// TODO: Migrate full catalog form from kleenops app.

import 'package:flutter/material.dart';

class CatalogForm extends StatefulWidget {
  final String docId;
  const CatalogForm({super.key, required this.docId});

  @override
  State<CatalogForm> createState() => _CatalogFormState();
}

class _CatalogFormState extends State<CatalogForm> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Product')),
      body: const Center(
        child: Text('Catalog form — coming soon'),
      ),
    );
  }
}
