// catalogDetails.dart — placeholder for admin app.
// TODO: Migrate full catalog detail view from kleenops app.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:kleenops_admin/services/catalog_firebase_service.dart';

class CatalogDetailsScreen extends StatelessWidget {
  final String docId;
  const CatalogDetailsScreen({super.key, required this.docId});

  @override
  Widget build(BuildContext context) {
    final db = CatalogFirebaseService.instance.firestore;

    return Scaffold(
      appBar: AppBar(title: const Text('Product Details')),
      body: FutureBuilder<DocumentSnapshot>(
        future: db.collection('object').doc(docId).get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('Product not found'));
          }
          final data = snapshot.data!.data() as Map<String, dynamic>;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(data['name'] ?? 'Unnamed',
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 16),
              if (data['description'] != null)
                Text(data['description'].toString()),
              const SizedBox(height: 12),
              if (data['objectProductCode'] != null)
                _row('Product Code', data['objectProductCode']),
              if (data['objectBarcode'] != null)
                _row('Barcode / UPC', data['objectBarcode']),
            ],
          );
        },
      ),
    );
  }

  Widget _row(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
              width: 140,
              child: Text(label,
                  style: const TextStyle(fontWeight: FontWeight.bold))),
          Expanded(child: Text(value?.toString() ?? '')),
        ],
      ),
    );
  }
}
