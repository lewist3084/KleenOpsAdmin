// catalog.dart
//
// Catalog browsing for admin app — uses StandardViewGroup + StandardTileLarge.

import 'package:flutter/material.dart';
import 'package:shared_widgets/search/search_field_action.dart';
import 'package:shared_widgets/tiles/standard_tile_large.dart';
import 'package:shared_widgets/lists/standardViewGroup.dart';
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
    final bool hideChrome = false;
    final bottomInset =
        (hideChrome ? 16.0 : kBottomNavigationBarHeight + 16.0) +
            MediaQuery.of(context).padding.bottom;

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
          child: Padding(
            padding: EdgeInsets.only(bottom: bottomInset),
            child: StandardViewGroup(
              queryStream: db
                  .collection('object')
                  .orderBy('objectCategoryId')
                  .orderBy('name')
                  .limit(100)
                  .snapshots(),
              groupBy: (doc) => doc.data()['objectCategoryId'] ?? '',
              emptyMessage: loc.objectsNoObjectsFound,
              itemFilter: _search.isEmpty
                  ? null
                  : (doc) {
                      final data = doc.data();
                      final name =
                          (data['name'] ?? '').toString().toLowerCase();
                      final code = (data['objectProductCode'] ?? '')
                          .toString()
                          .toLowerCase();
                      final upc = (data['objectBarcode'] ?? '')
                          .toString()
                          .toLowerCase();
                      return name.contains(_search) ||
                          code.contains(_search) ||
                          upc.contains(_search);
                    },
              itemBuilder: (doc) {
                final data = doc.data();
                final name = data['name'] ?? loc.commonUnnamed;
                final code = data['objectProductCode'] ?? '';
                final imageUrl = (data['imageUrl'] ?? '').toString();
                return StandardTileLargeDart(
                  imageUrl: imageUrl,
                  firstLine: name,
                  secondLine: code.toString().isNotEmpty ? 'Code: $code' : '',
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
