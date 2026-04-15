// catalog.dart
//
// Admin catalog list — reads the global `object` collection. Matches the
// regular CleanOps Objects view in shape:
//   • Grouped by resolved category name (not the raw DocumentReference id)
//   • Each tile shows the primary header image from object/{id}/file,
//     the product name, and the product code / UPC
//   • Tapping a tile opens the full catalog detail view
//
// Images come from the `file` subcollection under each object doc — the
// transfer function at stagingWorkflow.js writes them there with
// `objectMediaRole: 'header'` + `downloadUrl` + `order`. Reading
// `data['imageUrl']` (the old behaviour) returned the Solenis CDN URL
// which doesn't render on web because of CORS.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_widgets/lists/standardView.dart';
import 'package:shared_widgets/search/search_field_action.dart';
import 'package:shared_widgets/services/catalog_firebase_service.dart';
import 'package:shared_widgets/tiles/standard_tile_large.dart';

import 'package:kleenops_admin/features/catalog/details/catalog_details.dart';
import 'package:kleenops_admin/l10n/app_localizations.dart';

class CatalogContent extends StatefulWidget {
  const CatalogContent({super.key});

  @override
  State<CatalogContent> createState() => _CatalogContentState();
}

class _CatalogContentState extends State<CatalogContent> {
  String _search = '';
  final _searchController = TextEditingController();

  /// Cache: objectCategoryId → category name (e.g. "Consumables - Liquid").
  /// Loaded once on first build; refreshed only if a doc references an
  /// unknown id.
  final Map<String, String> _categoryNames = {};
  bool _categoriesLoaded = false;

  /// Cache: object doc id → primary header image URL. Populated on demand
  /// by the FutureBuilder inside each tile so the catalog shows images
  /// without issuing a query per rebuild.
  final Map<String, String> _imageUrlCache = {};

  @override
  void initState() {
    super.initState();
    _loadCategoryNames();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCategoryNames() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('objectCategory')
          .get();
      for (final doc in snap.docs) {
        _categoryNames[doc.id] =
            (doc.data()['name'] ?? 'Unknown').toString();
      }
    } catch (_) {}
    if (mounted) setState(() => _categoriesLoaded = true);
  }

  /// Resolves the primary header image URL for an object by querying the
  /// top-level `file` collection (matches the pattern the CleanOps app
  /// uses — see CatalogObjectFileImages.headerImageUrls). Result is
  /// cached so subsequent rebuilds don't re-query.
  ///
  /// Requires a composite Firestore index on
  /// (objectId ASC, objectMediaRole ASC, order ASC). Logs errors rather
  /// than swallowing silently — a missing/building index would otherwise
  /// show empty results with no indication something's wrong.
  Future<String> _resolveImageUrl(String objectId) async {
    if (_imageUrlCache.containsKey(objectId)) {
      return _imageUrlCache[objectId] ?? '';
    }
    try {
      final snap = await FirebaseFirestore.instance
          .collection('file')
          .where('objectId', isEqualTo: objectId)
          .where('objectMediaRole', isEqualTo: 'header')
          .orderBy('order')
          .limit(1)
          .get();
      if (snap.docs.isNotEmpty) {
        final url =
            (snap.docs.first.data()['downloadUrl'] ?? '').toString();
        _imageUrlCache[objectId] = url;
        return url;
      }
    } catch (e) {
      debugPrint('[Catalog] image query failed for $objectId: $e');
    }
    _imageUrlCache[objectId] = '';
    return '';
  }

  String _categoryNameFor(dynamic ref) {
    if (ref is DocumentReference) {
      return _categoryNames[ref.id] ?? 'Uncategorized';
    }
    if (ref is String && ref.isNotEmpty) {
      return _categoryNames[ref] ?? 'Uncategorized';
    }
    return 'Uncategorized';
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
          // The parent Scaffold's bottomNavigationBar (DetailsAppBar +
          // HomeNavBarAdapter) already reserves space at the bottom.
          // Adding our own bottom padding on top of that left a visible
          // white gap between the last list item and the chrome.
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: db
                  .collection('object')
                  .orderBy('name')
                  .limit(200)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                final rawDocs = snapshot.data?.docs ?? [];
                if (rawDocs.isEmpty) {
                  return Center(child: Text(loc.objectsNoObjectsFound));
                }

                // Show only top-level products in the catalog list — hide
                // packaging variants (the case/carton child objects the
                // scraper creates alongside the parent product). Their
                // details are surfaced inside the parent's detail screen
                // in the "Bulk Packaging" section instead.
                final docs = rawDocs.where((doc) {
                  final data = doc.data();
                  final objectType = (data['objectType'] ?? '').toString();
                  // Treat anything not explicitly 'packaging' as a base
                  // product — defensive against older docs without the
                  // objectType field set.
                  return objectType != 'packaging';
                }).toList();

                // Apply search filter across name / productCode / UPC.
                final filtered = _search.isEmpty
                    ? docs
                    : docs.where((doc) {
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
                      }).toList();

                if (filtered.isEmpty) {
                  return const Center(child: Text('No products match.'));
                }

                // Wait for category names so groups display correctly on
                // first render (otherwise everything briefly groups as
                // "Uncategorized" then re-groups — jarring).
                if (!_categoriesLoaded) {
                  return const Center(child: CircularProgressIndicator());
                }

                final items = filtered.map((doc) {
                  final data = doc.data();
                  return {
                    'docId': doc.id,
                    'name': (data['name'] ?? loc.commonUnnamed).toString(),
                    'objectCategoryId': data['objectCategoryId'],
                    'objectProductCode':
                        (data['objectProductCode'] ?? '').toString(),
                    'upc': (data['objectBarcode'] ?? data['upc'] ?? '')
                        .toString(),
                    'brand': (data['brand'] ?? '').toString(),
                  };
                }).toList();

                return StandardView<Map<String, dynamic>>(
                  items: items,
                  groupBy: (item) =>
                      _categoryNameFor(item['objectCategoryId']),
                  groupCollapsible: true,
                  initialGroupExpanded: true,
                  headerIcon: null,
                  disableGrouping: false,
                  onTap: (item) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CatalogDetailsScreen(
                          docId: item['docId'] as String,
                        ),
                      ),
                    );
                  },
                  itemBuilder: (item) {
                    final docId = item['docId'] as String;
                    final name = item['name'] as String;
                    final code = item['objectProductCode'] as String;
                    final upc = item['upc'] as String;
                    final brand = item['brand'] as String;

                    final secondLine = code.isNotEmpty
                        ? 'Code: $code'
                        : (upc.isNotEmpty ? 'UPC: $upc' : '');
                    final thirdLine = brand.isNotEmpty ? brand : null;

                    return FutureBuilder<String>(
                      future: _resolveImageUrl(docId),
                      builder: (context, snap) {
                        return StandardTileLargeDart(
                          imageUrl: snap.data ?? '',
                          firstLine: name,
                          firstLineIcon: Icons.category_outlined,
                          secondLine: secondLine,
                          secondLineIcon: secondLine.isNotEmpty
                              ? Icons.confirmation_number_outlined
                              : null,
                          thirdLine: thirdLine,
                          thirdLineIcon: thirdLine != null
                              ? Icons.branding_watermark_outlined
                              : null,
                        );
                      },
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
