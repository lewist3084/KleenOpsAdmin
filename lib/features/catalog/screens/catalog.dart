// catalog.dart
//
// Catalog browsing for admin app — simplified version.
// TODO: Migrate full catalog details/editing from kleenops app.

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_widgets/search/search_field_action.dart';
import 'package:kleenops_admin/services/catalog_firebase_service.dart';
import 'package:kleenops_admin/l10n/app_localizations.dart';

class CatalogContent extends StatefulWidget {
  const CatalogContent({super.key});

  @override
  State<CatalogContent> createState() => _CatalogContentState();
}

class _CatalogContentState extends State<CatalogContent> {
  String _search = '';
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final db = CatalogFirebaseService.instance.firestore;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: SearchFieldAction(
            controller: _searchController,
            labelText: loc.objectsSearchProducts,
            onChanged: (v) => setState(() => _search = v.toLowerCase()),
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream:
                db.collection('object').orderBy('name').limit(100).snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(
                    child: Text(
                        loc.commonErrorWithDetails(snapshot.error.toString())));
              }
              final docs = (snapshot.data?.docs ?? []).where((d) {
                if (_search.isEmpty) return true;
                final data = d.data() as Map<String, dynamic>;
                final name = (data['name'] ?? '').toString().toLowerCase();
                final code =
                    (data['objectProductCode'] ?? '').toString().toLowerCase();
                final upc =
                    (data['objectBarcode'] ?? '').toString().toLowerCase();
                return name.contains(_search) ||
                    code.contains(_search) ||
                    upc.contains(_search);
              }).toList();

              if (docs.isEmpty) {
                return Center(child: Text(loc.objectsNoObjectsFound));
              }
              return ListView.builder(
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final data = docs[index].data() as Map<String, dynamic>;
                  final name = data['name'] ?? loc.commonUnnamed;
                  final code = data['objectProductCode'] ?? '';
                  final upc = data['objectBarcode'] ?? '';
                  return ListTile(
                    title: Text(name),
                    subtitle: Text(
                      [
                        if (code.toString().isNotEmpty) 'Code: $code',
                        if (upc.toString().isNotEmpty) 'UPC: $upc',
                      ].join(' | '),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
