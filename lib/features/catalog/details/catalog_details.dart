// catalog_details.dart
//
// Product detail screen for the admin catalog (marketplace → Catalog).
// Reads from the global `object` collection (+ its `file` subcollection
// for images) and renders in the same overall layout as the staging
// review details — image carousel header + sectioned ContainerAction
// widgets for Brand, Identifiers, Item Packaging, Categories, Attributes,
// Packaging variants, Resources, Images, Source.
//
// Unlike the staging review version, everything here is displayed as
// authoritative fact — no suggested/confirmed UX, no reviewer actions.
// The transfer from stagedProduct into the object collection has already
// committed the LLM's picks.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/details_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/home_navbar_adapter.dart';
import 'package:shared_widgets/containers/container_action.dart';
import 'package:shared_widgets/containers/container_header.dart';
import 'package:shared_widgets/labels/header_info_icon_value.dart';
import 'package:shared_widgets/labels/text_info_checkbox.dart';
import 'package:shared_widgets/services/catalog_firebase_service.dart';
import 'package:shared_widgets/tabs/standard_tab.dart';
import 'package:shared_widgets/tiles/standard_tile_large.dart';
import 'package:shared_widgets/utils/process_localization_utils.dart';
import 'package:shared_widgets/viewers/file_carousel_viewer.dart';
import 'package:url_launcher/url_launcher.dart';

class CatalogDetailsScreen extends StatefulWidget {
  final String docId;
  const CatalogDetailsScreen({super.key, required this.docId});

  @override
  State<CatalogDetailsScreen> createState() => _CatalogDetailsScreenState();
}

class _CatalogDetailsScreenState extends State<CatalogDetailsScreen>
    with TickerProviderStateMixin {
  Map<String, dynamic>? _data;
  List<Map<String, dynamic>> _images = [];
  /// Bulk packaging variants linked to this product. Each entry is the
  /// raw objectData of a child `object` doc whose `parentProductId`
  /// references this product. Populated by _loadPackagingVariants.
  List<Map<String, dynamic>> _packagingVariants = [];
  // Raw `name` field from the resolved objectCategory doc — kept raw
  // so we can resolve to the current locale at render time.
  dynamic _categoryNameRaw;
  String _scalarName = '';
  String _scalarUnitName = '';
  String _weightUnitName = '';
  String _packagingWeightUnitName = '';
  String _packagingDimensionsUnitName = '';
  String _brandName = '';
  String _brandOwnerName = '';
  bool _loading = true;

  // Top-level tabs: Details / Elements. Mirrors the regular CleanOps
  // objects_objects_details.dart layout but trimmed for the catalog
  // context (no Charts/Records — those need per-company instance data).
  late final TabController _topTabController;
  // Inner Elements tabs: Parts / Materials / Processes (no Inventory —
  // inventory only makes sense for a per-company instance).
  late final TabController _elementsTabController;

  @override
  void initState() {
    super.initState();
    _topTabController = TabController(length: 2, vsync: this);
    _topTabController.addListener(() {
      if (mounted) setState(() {});
    });
    _elementsTabController = TabController(length: 3, vsync: this);
    _elementsTabController.addListener(() {
      if (mounted) setState(() {});
    });
    _load();
  }

  @override
  void dispose() {
    _topTabController.dispose();
    _elementsTabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final docRef = CatalogFirebaseService.instance.firestore
          .collection('object')
          .doc(widget.docId);
      final snap = await docRef.get();
      if (!snap.exists) {
        if (mounted) setState(() => _loading = false);
        return;
      }
      _data = snap.data() ?? <String, dynamic>{};
      await _resolveReferences();
      await _loadImages(docRef);
      await _loadPackagingVariants(docRef);
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _resolveReferences() async {
    final d = _data!;

    // Brand / brand owner
    _brandName = (d['brand'] ?? '').toString();
    final brandOwnerRef = d['brandOwnerId'];
    if (brandOwnerRef is DocumentReference) {
      try {
        final s = await brandOwnerRef.get();
        if (s.exists) {
          _brandOwnerName = ((s.data() as Map?)?['name'] ?? '').toString();
        }
      } catch (_) {}
    }
    // Walk the brand ref to pick up the brand owner if the object doc
    // doesn't carry it directly (and also refresh _brandName).
    final brandRef = d['brandId'];
    if (brandRef is DocumentReference) {
      try {
        final s = await brandRef.get();
        if (s.exists) {
          final brandData = (s.data() as Map?) ?? const {};
          if (_brandName.isEmpty) {
            _brandName = (brandData['name'] ?? '').toString();
          }
          if (_brandOwnerName.isEmpty) {
            final ownerRef = brandData['brandOwnerId'];
            if (ownerRef is DocumentReference) {
              final ownerSnap = await ownerRef.get();
              if (ownerSnap.exists) {
                _brandOwnerName =
                    ((ownerSnap.data() as Map?)?['name'] ?? '').toString();
              }
            }
          }
        }
      } catch (_) {}
    }

    // Category / scalar / scalarUnit / weight unit
    final catRef = d['objectCategoryId'];
    if (catRef is DocumentReference) {
      try {
        final s = await catRef.get();
        if (s.exists) {
          _categoryNameRaw = (s.data() as Map?)?['name'];
        }
      } catch (_) {}
    }
    final scalarRef = d['scalarId'];
    if (scalarRef is DocumentReference) {
      try {
        final s = await scalarRef.get();
        if (s.exists) {
          _scalarName = ((s.data() as Map?)?['name'] ?? '').toString();
        }
      } catch (_) {}
    }
    final scalarUnitRef = d['scalarUnitId'];
    if (scalarUnitRef is DocumentReference) {
      try {
        final s = await scalarUnitRef.get();
        if (s.exists) {
          final data = (s.data() as Map?) ?? const {};
          _scalarUnitName = (data['abbreviatedName'] ??
                  data['abbreviationName'] ??
                  data['name'] ??
                  '')
              .toString();
        }
      } catch (_) {}
    }
    final weightUnitRef = d['productWeightUnitId'];
    if (weightUnitRef is DocumentReference) {
      try {
        final s = await weightUnitRef.get();
        if (s.exists) {
          final data = (s.data() as Map?) ?? const {};
          _weightUnitName = (data['abbreviatedName'] ??
                  data['abbreviationName'] ??
                  data['name'] ??
                  '')
              .toString();
        }
      } catch (_) {}
    }

    // Packaging weight unit — populated on the bulk packaging variant
    // (objectType: 'packaging') alongside the packaged case weight.
    // Distinct from productWeightUnitId, which describes the per-unit
    // product use weight.
    final packagingWeightUnitRef = d['packagingWeightUnitId'];
    if (packagingWeightUnitRef is DocumentReference) {
      try {
        final s = await packagingWeightUnitRef.get();
        if (s.exists) {
          final data = (s.data() as Map?) ?? const {};
          _packagingWeightUnitName = (data['abbreviatedName'] ??
                  data['abbreviationName'] ??
                  data['abbreviation'] ??
                  data['name'] ??
                  '')
              .toString();
        }
      } catch (_) {}
    }

    // Packaging dimensions unit — points at a doc under
    // scalar/Length/scalarUnit/* (e.g. Inch, Centimeter). Kept as a ref
    // so future math can dereference the unit instead of parsing strings.
    final packagingDimRef = d['packagingDimensionsUnitId'];
    if (packagingDimRef is DocumentReference) {
      try {
        final s = await packagingDimRef.get();
        if (s.exists) {
          final data = (s.data() as Map?) ?? const {};
          _packagingDimensionsUnitName = (data['abbreviatedName'] ??
                  data['abbreviationName'] ??
                  data['abbreviation'] ??
                  data['name'] ??
                  '')
              .toString();
        }
      } catch (_) {}
    }
  }

  Future<void> _loadImages(DocumentReference<Map<String, dynamic>> ref) async {
    try {
      // Read from the TOP-LEVEL `file` collection — matches the pattern
      // CatalogObjectFileImages.headerImageUrls uses in the CleanOps app.
      // Files are linked back to objects via the `objectId` field.
      //
      // This multi-field query requires a composite Firestore index on
      // (objectId ASC, objectMediaRole ASC, order ASC). If the index is
      // missing or still building, the query fails with
      // FAILED_PRECONDITION. Log the error explicitly — silent empty
      // results previously hid a missing-index bug for days.
      final snap = await CatalogFirebaseService.instance.firestore
          .collection('file')
          .where('objectId', isEqualTo: ref.id)
          .where('objectMediaRole', isEqualTo: 'header')
          .orderBy('order')
          .get();
      _images = snap.docs.map((d) {
        final data = d.data();
        return <String, dynamic>{
          'downloadUrl': (data['downloadUrl'] ?? '').toString(),
          'name': (data['name'] ?? data['sourceFileName'] ?? '').toString(),
          'isMaster': data['isMaster'] == true,
          'order': data['order'] ?? 0,
        };
      }).toList();
    } catch (e, st) {
      debugPrint('[CatalogDetails] image query failed: $e\n$st');
    }
  }

  /// Loads packaging-variant child objects that reference this product
  /// via their `parentProductId` field. Each child is a full object doc
  /// in the `object` collection (objectType: 'packaging') — the scraper
  /// creates one per multi-pack SKU alongside the parent.
  ///
  /// Shown in the "Bulk Packaging" ContainerActionWidget on the detail
  /// page so a reviewer can see at a glance how the base item is sold
  /// (case of 6, case of 12, etc.) without creating duplicate top-level
  /// entries in the catalog list.
  Future<void> _loadPackagingVariants(
      DocumentReference<Map<String, dynamic>> ref) async {
    try {
      final snap = await CatalogFirebaseService.instance.firestore
          .collection('object')
          .where('parentProductId', isEqualTo: ref)
          .get();
      final variants = snap.docs.map((d) {
        final data = d.data();
        return <String, dynamic>{
          'docId': d.id,
          'name': (data['name'] ?? '').toString(),
          'packagingType': (data['packagingType'] ?? 'case').toString(),
          'packQuantity': data['packQuantity'],
          'upc': (data['objectBarcode'] ?? data['upc'] ?? '').toString(),
          'productCode': (data['objectProductCode'] ?? data['productNumber'] ?? '')
              .toString(),
        };
      }).toList();
      // Stable order by pack quantity then name so the list is
      // predictable across refreshes.
      variants.sort((a, b) {
        final aq = a['packQuantity'];
        final bq = b['packQuantity'];
        if (aq is num && bq is num && aq != bq) return aq.compareTo(bq);
        return (a['name'] as String).compareTo(b['name'] as String);
      });
      _packagingVariants = variants;
    } catch (e, st) {
      debugPrint('[CatalogDetails] packaging variants query failed: $e\n$st');
    }
  }

  String? _s(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_data == null) {
      return const Scaffold(body: Center(child: Text('Product not found')));
    }
    final d = _data!;
    final localeCode = Localizations.localeOf(context).toString();

    final resolvedName = ProcessLocalizationUtils.resolveLocalizedText(
      d['name'],
      localeCode: localeCode,
    ).trim();
    final name = resolvedName.isEmpty ? 'Unnamed' : resolvedName;
    final description = ProcessLocalizationUtils.resolveLocalizedText(
      d['description'],
      localeCode: localeCode,
    );
    final categoryName = ProcessLocalizationUtils.resolveLocalizedText(
      _categoryNameRaw,
      localeCode: localeCode,
    );
    // English-source value of the category name, used only for the
    // scalar-container feature-flag match below. The user-facing
    // display uses `categoryName` above.
    final categoryNameEn = ProcessLocalizationUtils.resolveLocalizedText(
      _categoryNameRaw,
      localeCode: 'en',
    );
    final productCode =
        _s(d['objectProductCode']) ?? _s(d['productNumber']) ?? '';
    final upc = _s(d['objectBarcode']) ?? _s(d['upc']) ?? '';
    final unitQty = d['scalarUnitQuantity'];
    final productWeight = d['productWeight'];
    final containerType = _s(d['containerType']) ?? '';
    final packagingWeight = d['packagingWeight'];
    final packagingType = _s(d['packagingType']) ?? '';
    final packagingLength = d['packagingLength'];
    final packagingWidth = d['packagingWidth'];
    final packagingHeight = d['packagingHeight'];
    final productLine = _s(d['productLine']) ?? '';
    final color = _s(d['color']) ?? '';
    final fragrance = _s(d['fragrance']) ?? _s(d['scent']) ?? '';
    final canonicalUrl = _s(d['canonicalUrl']) ?? '';
    final documents = (d['documents'] is List)
        ? List<Map<String, dynamic>>.from(
            (d['documents'] as List)
                .map((e) => e is Map
                    ? Map<String, dynamic>.from(e)
                    : <String, dynamic>{}))
        : const <Map<String, dynamic>>[];

    final mediaItems = <FileCarouselItem>[];
    for (final img in _images) {
      final url = (img['downloadUrl'] ?? '').toString();
      if (url.isNotEmpty) {
        mediaItems.add(FileCarouselItem.image(imageUrl: url));
      }
    }

    // Packaging variant objects carry a parentProductId reference pointing
    // back at the base product; they also use objectType 'packaging'. Hide
    // the sections that only make sense for the base SKU when the viewer
    // navigates into one of these variants from the Bulk Packaging list.
    final bool isBulkVariant =
        d['parentProductId'] != null || d['objectType'] == 'packaging';
    // The Scalar (floor/wall/ceiling covering) toggle set is only
    // meaningful for catalog products categorized as Furnishings or Grounds.
    // Everything else (consumables, equipment, systems) never acts as a
    // covering, so the container is suppressed entirely.
    final bool allowScalarContainer =
        categoryNameEn == 'Furnishings' || categoryNameEn == 'Grounds';

    // Build the per-tab body up front so we can swap based on the
    // current top-level tab without nesting a giant switch inside the
    // ListView builder.
    final Widget tabBody;
    switch (_topTabController.index) {
      case 1:
        tabBody = _buildElementsTab();
        break;
      case 0:
      default:
        tabBody = _buildDetailsTab(
          name: name,
          productCode: productCode,
          upc: upc,
          unitQty: unitQty,
          productWeight: productWeight,
          containerType: containerType,
          packagingWeight: packagingWeight,
          packagingType: packagingType,
          packagingLength: packagingLength,
          packagingWidth: packagingWidth,
          packagingHeight: packagingHeight,
          productLine: productLine,
          color: color,
          fragrance: fragrance,
          documents: documents,
          canonicalUrl: canonicalUrl,
          isBulkVariant: isBulkVariant,
          allowScalarContainer: allowScalarContainer,
          categoryName: categoryName,
        );
    }

    return Scaffold(
      appBar: null,
      body: SafeArea(
        top: true,
        bottom: false,
        child: ListView(
          children: [
            ContainerHeader(
              mediaItems: mediaItems.isNotEmpty ? mediaItems : null,
              showImage: mediaItems.isNotEmpty,
              titleHeader: 'Product',
              title: name,
              descriptionHeader: 'Description',
              description: description,
              textIcon: Icons.category_outlined,
              descriptionIcon: Icons.info_outlined,
            ),
            // Top-level Details / Elements tabs — mirrors the regular
            // CleanOps objects detail view so admins see a familiar
            // layout when browsing the catalog.
            Container(
              color: Colors.white,
              child: StandardTabBar(
                controller: _topTabController,
                isScrollable: false,
                dividerColor: Colors.grey.shade300,
                indicatorColor: Theme.of(context).primaryColor,
                indicatorWeight: 3.0,
                labelColor: Colors.black,
                unselectedLabelColor: Colors.grey.shade600,
                tabs: const [
                  Tab(text: 'Details'),
                  Tab(text: 'Elements'),
                ],
              ),
            ),
            tabBody,
            const SizedBox(height: 80),
          ],
        ),
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DetailsAppBar(title: name),
          const HomeNavBarAdapter(),
        ],
      ),
    );
  }

  /// Details tab body — all the existing sectioned content the catalog
  /// detail page used to render flat directly inside the ListView, now
  /// extracted into its own method so the top-level TabController can
  /// swap it out for the Elements tab.
  Widget _buildDetailsTab({
    required String name,
    required String productCode,
    required String upc,
    required dynamic unitQty,
    required dynamic productWeight,
    required String containerType,
    required dynamic packagingWeight,
    required String packagingType,
    required dynamic packagingLength,
    required dynamic packagingWidth,
    required dynamic packagingHeight,
    required String productLine,
    required String color,
    required String fragrance,
    required List<Map<String, dynamic>> documents,
    required String canonicalUrl,
    required bool isBulkVariant,
    required bool allowScalarContainer,
    required String categoryName,
  }) {
    return Column(
      children: [
            // 1. Brand — suppressed entirely for bulk packaging variants
            // since their brand is inherited from the parent product.
            if (!isBulkVariant)
              ContainerActionWidget(
                title: '',
                actionText: '',
                content: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    HeaderInfoIconValue(
                      header: 'Brand',
                      value: _brandName.isNotEmpty ? _brandName : 'Not set',
                      icon: Icons.branding_watermark_outlined,
                    ),
                    const SizedBox(height: 12),
                    HeaderInfoIconValue(
                      header: 'Brand Owner',
                      value: _brandOwnerName.isNotEmpty
                          ? _brandOwnerName
                          : 'Not set',
                      icon: Icons.business_outlined,
                    ),
                  ],
                ),
              ),

            // 2. Identifiers
            ContainerActionWidget(
              title: '',
              actionText: '',
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  HeaderInfoIconValue(
                    header: 'Product Code',
                    value: productCode.isNotEmpty ? productCode : 'Not set',
                    icon: Icons.confirmation_number_outlined,
                  ),
                  const SizedBox(height: 12),
                  HeaderInfoIconValue(
                    header: 'UPC',
                    value: upc.isNotEmpty ? upc : 'Not set',
                    icon: Icons.qr_code,
                  ),
                ],
              ),
            ),

            // 3. Item Packaging — field set depends on whether the
            // current object is the base product or a bulk packaging
            // variant. Variants describe the shipping case itself
            // (packaging weight + packaging type), not the product inside.
            ContainerActionWidget(
              title: '',
              actionText: '',
              content: isBulkVariant
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        HeaderInfoIconValue(
                          header: 'Packaging Weight Unit',
                          value: _resolvedPackagingWeightUnit().isNotEmpty
                              ? _resolvedPackagingWeightUnit()
                              : 'Not set',
                          icon: Icons.balance_outlined,
                        ),
                        const SizedBox(height: 12),
                        HeaderInfoIconValue(
                          header: 'Packaging Weight Value',
                          value: packagingWeight is num
                              ? packagingWeight.toStringAsFixed(2)
                              : (_s(packagingWeight) ?? 'Not set'),
                          icon: Icons.scale_outlined,
                        ),
                        const SizedBox(height: 12),
                        HeaderInfoIconValue(
                          header: 'Packaging Type',
                          value: packagingType.isNotEmpty
                              ? _titleCase(packagingType)
                              : 'Not set',
                          icon: Icons.inventory_2_outlined,
                        ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        HeaderInfoIconValue(
                          header: 'Content Unit',
                          value: _scalarUnitName.isNotEmpty
                              ? _scalarUnitName
                              : 'Not set',
                          icon: Icons.science_outlined,
                        ),
                        const SizedBox(height: 12),
                        HeaderInfoIconValue(
                          header: 'Content Value',
                          value: unitQty != null ? '$unitQty' : 'Not set',
                          icon: Icons.format_list_numbered,
                        ),
                        const SizedBox(height: 12),
                        HeaderInfoIconValue(
                          header: 'Product Weight Unit',
                          value: _resolvedWeightUnit().isNotEmpty
                              ? _resolvedWeightUnit()
                              : 'Not set',
                          icon: Icons.balance_outlined,
                        ),
                        const SizedBox(height: 12),
                        HeaderInfoIconValue(
                          header: 'Product Weight Value',
                          value: productWeight is num
                              ? productWeight.toStringAsFixed(2)
                              : (_s(productWeight) ?? 'Not set'),
                          icon: Icons.scale_outlined,
                        ),
                        const SizedBox(height: 12),
                        HeaderInfoIconValue(
                          header: 'Container Type',
                          value: containerType.isNotEmpty
                              ? _titleCase(containerType)
                              : 'Not set',
                          icon: Icons.takeout_dining_outlined,
                        ),
                      ],
                    ),
            ),

            // 3a. Packaging Dimensions — bulk variants only. L/W/H plus
            // the unit (resolved via packagingDimensionsUnitId ref under
            // scalar/Length/scalarUnit/*, so cubic-footage / density math
            // can dereference the unit instead of string-parsing).
            if (isBulkVariant)
              ContainerActionWidget(
                title: '',
                actionText: '',
                content: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    HeaderInfoIconValue(
                      header: 'Packaging Dimensions Unit',
                      value: _resolvedPackagingDimensionsUnit().isNotEmpty
                          ? _resolvedPackagingDimensionsUnit()
                          : 'Not set',
                      icon: Icons.straighten,
                    ),
                    const SizedBox(height: 12),
                    HeaderInfoIconValue(
                      header: 'Length',
                      value: packagingLength is num
                          ? packagingLength.toStringAsFixed(2)
                          : (_s(packagingLength) ?? 'Not set'),
                      icon: Icons.height,
                    ),
                    const SizedBox(height: 12),
                    HeaderInfoIconValue(
                      header: 'Width',
                      value: packagingWidth is num
                          ? packagingWidth.toStringAsFixed(2)
                          : (_s(packagingWidth) ?? 'Not set'),
                      icon: Icons.swap_horiz,
                    ),
                    const SizedBox(height: 12),
                    HeaderInfoIconValue(
                      header: 'Height',
                      value: packagingHeight is num
                          ? packagingHeight.toStringAsFixed(2)
                          : (_s(packagingHeight) ?? 'Not set'),
                      icon: Icons.vertical_align_top,
                    ),
                  ],
                ),
              ),

            // 4. Categories — suppressed on packaging variants (they
            // inherit their category from the parent product).
            if (!isBulkVariant)
              ContainerActionWidget(
                title: '',
                actionText: '',
                content: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    HeaderInfoIconValue(
                      header: 'Usage',
                      value: _scalarName.isNotEmpty ? _scalarName : 'Not set',
                      icon: Icons.straighten,
                    ),
                    const SizedBox(height: 12),
                    HeaderInfoIconValue(
                      header: 'Object Category',
                      value:
                          categoryName.isNotEmpty ? categoryName : 'Not set',
                      icon: Icons.category,
                    ),
                    if (productLine.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      HeaderInfoIconValue(
                        header: 'Object Subcategory',
                        value: productLine,
                        icon: Icons.subdirectory_arrow_right,
                      ),
                    ],
                  ],
                ),
              ),

            // 6. Attributes
            if (color.isNotEmpty || fragrance.isNotEmpty)
              ContainerActionWidget(
                title: '',
                actionText: '',
                content: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (color.isNotEmpty)
                      HeaderInfoIconValue(
                        header: 'Color',
                        value: color,
                        icon: Icons.palette_outlined,
                      ),
                    if (color.isNotEmpty && fragrance.isNotEmpty)
                      const SizedBox(height: 12),
                    if (fragrance.isNotEmpty)
                      HeaderInfoIconValue(
                        header: 'Fragrance',
                        value: fragrance,
                        icon: Icons.air,
                      ),
                  ],
                ),
              ),

            // 6a. Scalar — Floor / Wall / Ceiling Covering checkboxes.
            // Only meaningful for Furnishings or Grounds category items;
            // also suppressed on packaging variants.
            if (!isBulkVariant && allowScalarContainer)
              _buildScalarSection(),

            // 6b. Track Object / Safety Response — suppressed on
            // packaging variants (the parent product carries these flags).
            if (!isBulkVariant) _buildTrackSafetySection(),

            // 6c. Bulk Packaging — child objects whose parentProductId
            // references this product. Only rendered on the parent object
            // and only when at least one variant exists.
            if (!isBulkVariant && _packagingVariants.isNotEmpty)
              ContainerActionWidget(
                title: 'Bulk Packaging',
                actionText: '',
                content: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final v in _packagingVariants) _buildVariantTile(v),
                  ],
                ),
              ),

            // 7. Resources — suppressed on packaging variants; the
            // parent product carries the SDS/TDS/etc. for the whole line.
            if (!isBulkVariant)
              ContainerActionWidget(
                title: 'Resources',
                actionText: '',
                content: _buildResourcesContent(documents, canonicalUrl),
              ),
      ],
    );
  }

  Widget _buildResourcesContent(
      List<Map<String, dynamic>> documents, String canonicalUrl) {
    final rows = <Widget>[];
    for (final doc in documents) {
      rows.add(_buildDocTile(doc));
    }
    if (canonicalUrl.isNotEmpty) {
      rows.add(_buildWebAddressTile(canonicalUrl));
    }
    if (rows.isEmpty) {
      return Text('No resources', style: TextStyle(color: Colors.grey.shade600));
    }
    return Column(children: rows);
  }

  /// Elements tab body — Parts / Materials / Processes sub-tabs. Catalog
  /// products don't have per-company instance data so all three are
  /// placeholder shells until a future iteration wires up shared
  /// part/material/process catalogs.
  Widget _buildElementsTab() {
    final inner = <Widget>[];
    switch (_elementsTabController.index) {
      case 1:
        inner.add(_placeholderTab('Materials'));
        break;
      case 2:
        inner.add(_placeholderTab('Processes'));
        break;
      case 0:
      default:
        inner.add(_placeholderTab('Parts'));
    }
    return Column(
      children: [
        Container(
          color: Colors.white,
          child: StandardTabBar(
            controller: _elementsTabController,
            isScrollable: false,
            dividerColor: Colors.grey.shade300,
            indicatorColor: Theme.of(context).primaryColor,
            indicatorWeight: 2.0,
            labelColor: Colors.black,
            unselectedLabelColor: Colors.grey.shade600,
            tabs: const [
              Tab(text: 'Parts'),
              Tab(text: 'Materials'),
              Tab(text: 'Processes'),
            ],
          ),
        ),
        ...inner,
      ],
    );
  }

  Widget _placeholderTab(String label) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Text(
          '$label coming soon',
          style: TextStyle(color: Colors.grey.shade500),
        ),
      ),
    );
  }

  /// Scalar covering checkboxes — Floor / Wall / Ceiling. Mirrors the
  /// Scaler section in the regular CleanOps objects detail view. Writes
  /// directly to the global `object` doc since this is the catalog-level
  /// capability, not a per-company instance flag.
  Widget _buildScalarSection() {
    final d = _data ?? const <String, dynamic>{};
    final docRef = CatalogFirebaseService.instance.firestore
        .collection('object')
        .doc(widget.docId);
    return ContainerActionWidget(
      title: 'Scalar',
      actionText: '',
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextInfoCheckbox(
            text: 'Floor Covering',
            value: d['floorCovering'] == true,
            onChanged: (v) async {
              await docRef.update({'floorCovering': v ?? false});
              if (mounted) setState(() => d['floorCovering'] = v ?? false);
            },
          ),
          const SizedBox(height: 6),
          TextInfoCheckbox(
            text: 'Wall Covering',
            value: d['wallCovering'] == true,
            onChanged: (v) async {
              await docRef.update({'wallCovering': v ?? false});
              if (mounted) setState(() => d['wallCovering'] = v ?? false);
            },
          ),
          const SizedBox(height: 6),
          TextInfoCheckbox(
            text: 'Ceiling Covering',
            value: d['ceilingCovering'] == true,
            onChanged: (v) async {
              await docRef.update({'ceilingCovering': v ?? false});
              if (mounted) setState(() => d['ceilingCovering'] = v ?? false);
            },
          ),
        ],
      ),
    );
  }

  /// Track Object + Safety Response checkboxes. Same writeback pattern
  /// as _buildScalarSection — flips a boolean on the global object doc.
  Widget _buildTrackSafetySection() {
    final d = _data ?? const <String, dynamic>{};
    final docRef = CatalogFirebaseService.instance.firestore
        .collection('object')
        .doc(widget.docId);
    return ContainerActionWidget(
      title: '',
      actionText: '',
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextInfoCheckbox(
            text: 'Track Object',
            value: d['trackObject'] == true,
            onChanged: (v) async {
              await docRef.update({'trackObject': v ?? false});
              if (mounted) setState(() => d['trackObject'] = v ?? false);
            },
          ),
          const SizedBox(height: 6),
          TextInfoCheckbox(
            text: 'Safety Response',
            value: d['safetyResponse'] == true,
            onChanged: (v) async {
              await docRef.update({'safetyResponse': v ?? false});
              if (mounted) setState(() => d['safetyResponse'] = v ?? false);
            },
          ),
        ],
      ),
    );
  }

  /// Renders one row in the Bulk Packaging container. Uses
  /// StandardTileLargeDart to match the visual shape of the catalog
  /// list itself, with three lines:
  ///   1. Full product name
  ///   2. Pack quantity (e.g. "Qty: 6 (case)")
  ///   3. UPC (the bulk packaging barcode)
  Widget _buildVariantTile(Map<String, dynamic> v) {
    final name = ProcessLocalizationUtils.resolveLocalizedText(
      v['name'],
      localeCode: Localizations.localeOf(context).toString(),
    ).trim();
    final packQty = v['packQuantity'];
    final packType = (v['packagingType'] as String);
    final upc = (v['upc'] as String);

    final secondLine = packQty != null
        ? (packType.isNotEmpty
            ? 'Qty: $packQty (${packType.toLowerCase()})'
            : 'Qty: $packQty')
        : (packType.isNotEmpty ? _titleCase(packType) : '');

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                CatalogDetailsScreen(docId: v['docId'] as String),
          ),
        );
      },
      child: StandardTileLargeDart(
        // Catalog images for packaging variants live under the variant's
        // own docId in the top-level `file` collection — same shape as
        // the parent product. Empty here for now to keep the row light;
        // tapping opens the variant's own detail page where the carousel
        // shows up.
        imageUrl: '',
        firstLine: name,
        firstLineIcon: Icons.category_outlined,
        secondLine: secondLine,
        secondLineIcon: secondLine.isNotEmpty ? Icons.inventory_2_outlined : null,
        thirdLine: upc.isNotEmpty ? 'UPC: $upc' : null,
        thirdLineIcon: upc.isNotEmpty ? Icons.qr_code : null,
      ),
    );
  }

  String _titleCase(String s) {
    if (s.isEmpty) return s;
    return s
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .map((w) => w[0].toUpperCase() + w.substring(1).toLowerCase())
        .join(' ');
  }

  /// Resolves the product weight unit, preferring the reference-resolved
  /// name but falling back to a raw string field on the object doc for
  /// products transferred before the productWeightUnitId ref was wired up.
  String _resolvedWeightUnit() {
    if (_weightUnitName.isNotEmpty) return _weightUnitName;
    final d = _data ?? const <String, dynamic>{};
    final raw = (d['productWeightUnit'] ?? d['productWeightUom'] ?? '')
        .toString()
        .trim();
    return raw;
  }

  /// Packaging weight unit resolution — mirrors _resolvedWeightUnit but
  /// for the packaged-case shipping weight (stored on objectType:
  /// 'packaging' variants). Falls back to packagingWeightUnit string,
  /// then to productWeightUnit (legacy packaging variants written before
  /// the split reused the product fields).
  String _resolvedPackagingWeightUnit() {
    if (_packagingWeightUnitName.isNotEmpty) return _packagingWeightUnitName;
    final d = _data ?? const <String, dynamic>{};
    final raw = (d['packagingWeightUnit'] ??
            d['productWeightUnit'] ??
            d['productWeightUom'] ??
            '')
        .toString()
        .trim();
    return raw;
  }

  /// Packaging dimensions unit resolution — prefers the scalarUnit ref
  /// name, falls back to the raw packagingDimensionsUnit string for
  /// variants written before the ref was wired up.
  String _resolvedPackagingDimensionsUnit() {
    if (_packagingDimensionsUnitName.isNotEmpty) {
      return _packagingDimensionsUnitName;
    }
    final d = _data ?? const <String, dynamic>{};
    return (d['packagingDimensionsUnit'] ?? '').toString().trim();
  }

  /// Renders one resource row (SDS / TDS / etc.) using the same
  /// StandardTileLargeDart shape the rest of the catalog uses. Passes
  /// the PDF URL through as the tile's imageUrl — StandardTileLargeDart
  /// detects the `.pdf` extension and renders the first page via
  /// SfPdfViewer automatically, so the thumbnail shows the actual
  /// document rather than a generic icon.
  ///
  ///   firstLine  : file / document name
  ///   secondLine : file CATEGORY — "SDS", "TDS", etc.
  ///   thirdLine  : file TYPE — "PDF" (derived from the URL extension)
  Widget _buildDocTile(Map<String, dynamic> doc) {
    final url = (doc['url'] ?? doc['downloadUrl'] ?? '').toString();
    final category = (doc['type'] ?? '').toString().toUpperCase();
    final name = (doc['name'] ?? doc['fileName'] ?? 'Document').toString();

    // Derive file type from the URL extension (PDF / JPG / etc.). Falls
    // back to an explicit `fileType` / `fileExtension` field on the doc.
    String fileType = (doc['fileType'] ?? doc['fileExtension'] ?? '')
        .toString()
        .toUpperCase();
    if (fileType.isEmpty && url.isNotEmpty) {
      final path = Uri.tryParse(url)?.path ?? url;
      final dot = path.lastIndexOf('.');
      if (dot >= 0 && dot < path.length - 1) {
        fileType = path.substring(dot + 1).toUpperCase();
      }
    }

    return InkWell(
      onTap: url.isEmpty
          ? null
          : () async {
              final uri = Uri.tryParse(url);
              if (uri != null) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
      child: StandardTileLargeDart(
        imageUrl: url,
        firstLine: name,
        firstLineIcon: category == 'SDS'
            ? Icons.warning_amber_outlined
            : Icons.description_outlined,
        secondLine: category.isNotEmpty ? category : '',
        secondLineIcon:
            category.isNotEmpty ? Icons.folder_outlined : null,
        thirdLine: fileType.isNotEmpty ? fileType : null,
        thirdLineIcon: fileType.isNotEmpty ? Icons.insert_drive_file_outlined : null,
      ),
    );
  }

  /// Web Address row — the canonical source URL for the product, shown
  /// in the Resources container alongside the PDF resources. Tapping
  /// opens the URL externally.
  ///
  /// The thumbnail is a live screenshot rendered by Microlink's free
  /// screenshot API (embed=screenshot.url returns the raw PNG), so the
  /// reviewer sees a small preview of the vendor page instead of just a
  /// generic link icon.
  Widget _buildWebAddressTile(String url) {
    final screenshotUrl =
        'https://api.microlink.io/?url=${Uri.encodeComponent(url)}'
        '&screenshot=true&embed=screenshot.url&meta=false&viewport.width=800'
        '&viewport.height=600';
    return InkWell(
      onTap: () async {
        final uri = Uri.tryParse(url);
        if (uri != null) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      },
      child: StandardTileLargeDart(
        imageUrl: screenshotUrl,
        fit: BoxFit.cover,
        firstLine: url,
        firstLineIcon: Icons.link,
        secondLine: 'Web Address',
        secondLineIcon: Icons.folder_outlined,
        thirdLine: 'URL',
        thirdLineIcon: Icons.language,
      ),
    );
  }
}
