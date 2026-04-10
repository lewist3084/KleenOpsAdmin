import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:kleenops_admin/l10n/app_localizations.dart';
import 'package:shared_widgets/services/catalog_firebase_service.dart';
import 'package:shared_widgets/containers/container_action.dart';
import 'package:shared_widgets/containers/container_header.dart';
import 'package:shared_widgets/viewers/file_carousel_viewer.dart';
import 'package:shared_widgets/labels/header_info_icon_value.dart';
import 'package:shared_widgets/tabs/standard_tab.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/details_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/home_navbar_adapter.dart';
import 'package:url_launcher/url_launcher.dart';

class MarketplaceStagingReviewDetailsScreen extends StatefulWidget {
  final String docId;
  final Map<String, dynamic> initialData;

  const MarketplaceStagingReviewDetailsScreen({
    super.key,
    required this.docId,
    required this.initialData,
  });

  @override
  State<MarketplaceStagingReviewDetailsScreen> createState() =>
      _MarketplaceStagingReviewDetailsScreenState();
}

class _MarketplaceStagingReviewDetailsScreenState
    extends State<MarketplaceStagingReviewDetailsScreen>
    with SingleTickerProviderStateMixin {
  late Map<String, dynamic> _data;
  late TabController _tabController;
  bool _loading = true;

  String _categoryName = '';
  String _suggestedCategoryName = '';
  String _scalarName = '';
  String _scalarUnitName = '';
  String _brandName = '';
  String _brandOwnerName = '';

  @override
  void initState() {
    super.initState();
    _data = Map<String, dynamic>.from(widget.initialData);
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() { if (mounted) setState(() {}); });
    _loadLatest();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Map<String, dynamic> _m(dynamic v) {
    if (v is Map<String, dynamic>) return v;
    if (v is Map) return v.map((k, dynamic val) => MapEntry(k.toString(), val));
    return <String, dynamic>{};
  }

  List<dynamic> _l(dynamic v) => v is List ? v : const [];
  String? _s(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }

  /// Returns the longest non-empty string from the given candidates (or '' if
  /// none). Used for fields like `description` whose value lives in several
  /// places on a stagedProduct doc — some short, some long — and we want to
  /// surface the most descriptive variant.
  String _longestString(List<String?> candidates) {
    String best = '';
    for (final c in candidates) {
      if (c == null) continue;
      if (c.length > best.length) best = c;
    }
    return best;
  }

  /// Resolves the weight unit of measure (e.g. "LB", "OZ", "KG") from the
  /// staged product, checking objectData → top-level → normalizedData →
  /// detailData → detailData.allSpecs. The scraper writes the literal UOM
  /// to both `detailData.unitOfMeasure` and `detailData.allSpecs.unitOfMeasure`
  /// so we cover both as a defensive layer.
  String _weightUom() {
    final od = _m(_data['objectData']);
    final nd = _m(_data['normalizedData']);
    final dd = _m(_data['detailData']);
    final allSpecs = _m(dd['allSpecs']);
    return _s(od['unitOfMeasure']) ??
        _s(_data['unitOfMeasure']) ??
        _s(nd['unitOfMeasure']) ??
        _s(dd['unitOfMeasure']) ??
        _s(allSpecs['unitOfMeasure']) ??
        '';
  }

  /// Formats a `<value> <uom>` weight string. Returns 'Not set' when no
  /// numeric value is present. Trusts that `value` and `uom` are stored as
  /// separate fields by the scraper — does not parse mixed strings.
  String _formatWeight(dynamic value, String uom) {
    final v = _s(value);
    if (v == null) return 'Not set';
    if (uom.isEmpty) return v;
    return '$v $uom';
  }

  /// Walks `keys` in order and returns the first non-empty value found in
  /// `map` (or null). Used as a safety net when reading raw SF custom fields
  /// from `detailData.allFields` — we don't always know the exact field name
  /// the vendor uses, so the caller passes a list of likely candidates.
  dynamic _firstNonEmpty(Map<String, dynamic> map, List<String> keys) {
    for (final k in keys) {
      final v = map[k];
      if (v == null) continue;
      final s = v.toString().trim();
      if (s.isNotEmpty) return v;
    }
    return null;
  }

  /// Coerces a Firestore-stored value to a double. Solenis writes most
  /// numeric fields as strings ("6.261", "12"), so callers that want to do
  /// math need to parse first. Returns null when the value can't be parsed.
  double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    final s = value.toString().trim();
    if (s.isEmpty) return null;
    return double.tryParse(s);
  }

  Future<void> _loadLatest() async {
    try {
      final snap = await CatalogFirebaseService.instance.firestore
          .collection('stagedProduct').doc(widget.docId).get();
      if (snap.exists && mounted) _data = snap.data() ?? _data;
    } catch (_) {}
    await _resolveReferences();
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _resolveReferences() async {
    final od = _m(_data['objectData']);
    final nd = _m(_data['normalizedData']);
    final pd = _m(_data['packagingData']);
    final dd = _m(_data['detailData']);
    final sd = _m(dd['solenisData']);

    final catRef = od['objectCategoryId'];
    if (catRef is DocumentReference) {
      try { final s = await catRef.get(); if (s.exists) _categoryName = ((s.data() as Map?)?['name'] ?? '').toString(); } catch (_) {}
    }

    // Suggested category — written by the scraper to a top-level
    // `suggestedCategoryId` field. Reviewer must explicitly confirm before
    // it copies into objectData.objectCategoryId.
    final suggestedRef = _data['suggestedCategoryId'];
    if (suggestedRef is DocumentReference) {
      try {
        final s = await suggestedRef.get();
        if (s.exists) {
          _suggestedCategoryName =
              ((s.data() as Map?)?['name'] ?? '').toString();
        }
      } catch (_) {}
    }
    final scRef = od['scalarId'];
    if (scRef is DocumentReference) {
      try { final s = await scRef.get(); if (s.exists) _scalarName = ((s.data() as Map?)?['name'] ?? '').toString(); } catch (_) {}
    }
    final suRef = od['scalarUnitId'];
    if (suRef is DocumentReference) {
      try { final s = await suRef.get(); if (s.exists) _scalarUnitName = ((s.data() as Map?)?['name'] ?? '').toString(); } catch (_) {}
    }
    _brandName = _s(od['brand']) ?? _s(nd['brandName']) ?? _s(sd['brand']) ?? '';

    // Resolve brand owner. The scraper writes brandOwnerId in two places on
    // every staged product:
    //   1. `objectData.brandOwnerId` as a DocumentReference (for direct copy
    //      to the object collection)
    //   2. top-level `brandOwnerId` as a plain string id (for filter queries)
    // Try the direct paths first; only fall back to the brand-indirection
    // (brandId → brand doc → brandOwnerId) when neither is set.
    _brandOwnerName = await _resolveBrandOwnerName(od, pd);
  }

  /// Walks the known places a brand owner identifier can live on a staged
  /// product and returns the matching brandOwner doc's `name`. Returns ''
  /// when nothing resolves.
  Future<String> _resolveBrandOwnerName(
    Map<String, dynamic> od,
    Map<String, dynamic> pd,
  ) async {
    // 1. objectData.brandOwnerId — DocumentReference (preferred)
    final directRef = od['brandOwnerId'];
    if (directRef is DocumentReference) {
      try {
        final s = await directRef.get();
        if (s.exists) {
          final n = ((s.data() as Map?)?['name'] ?? '').toString();
          if (n.isNotEmpty) return n;
        }
      } catch (_) {}
    }

    // 2. top-level `brandOwnerId` — plain string id
    final topLevelId = _s(_data['brandOwnerId']);
    if (topLevelId != null) {
      try {
        final s = await CatalogFirebaseService.instance.firestore
            .collection('brandOwner')
            .doc(topLevelId)
            .get();
        if (s.exists) {
          final n = (s.data()?['name'] ?? '').toString();
          if (n.isNotEmpty) return n;
        }
      } catch (_) {}
    }

    // 3. Indirect via brand reference: brandId → brand doc → brandOwnerId.
    //    Some staged products only carry the brand reference and the
    //    relationship has to be walked.
    final brandRef = od['brandId'] ?? pd['brandId'];
    if (brandRef is DocumentReference) {
      try {
        final brandSnap = await brandRef.get();
        if (brandSnap.exists) {
          final brandData = (brandSnap.data() as Map?) ?? const {};
          if (_brandName.isEmpty) {
            _brandName = (brandData['name'] ?? '').toString();
          }
          final ownerRef = brandData['brandOwnerId'];
          if (ownerRef is DocumentReference) {
            final ownerSnap = await ownerRef.get();
            if (ownerSnap.exists) {
              return ((ownerSnap.data() as Map?)?['name'] ?? '').toString();
            }
          } else if (ownerRef is String && ownerRef.isNotEmpty) {
            final ownerSnap = await CatalogFirebaseService.instance.firestore
                .collection('brandOwner')
                .doc(ownerRef)
                .get();
            if (ownerSnap.exists) {
              return (ownerSnap.data()?['name'] ?? '').toString();
            }
          }
        }
      } catch (_) {}
    }

    return '';
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final od = _m(_data['objectData']);
    final nd = _m(_data['normalizedData']);
    final rd = _m(_data['rawData']);
    final dd = _m(_data['detailData']);
    final pd = _m(_data['packagingData']);
    final sd = _m(dd['solenisData']);
    final specs = _m(dd['allSpecs']);

    // Core fields
    final name = _s(od['name']) ?? _s(nd['name']) ?? _s(rd['name']) ?? 'Unnamed';
    // Description can live in several places; some sources hold a short
    // tagline (e.g. packagingData/rawData) while others hold the full
    // marketing copy (top-level, objectData, or detailData). Prefer the
    // longest non-empty value so the user always sees the most descriptive
    // variant — the scraper writes the full marketing copy to
    // `detailData.description` for Solenis products.
    final description = _longestString(<String?>[
      _s(dd['description']),
      _s(_data['description']),
      _s(od['description']),
      _s(nd['description']),
      _s(rd['description']),
      _s(pd['description']),
    ]);
    final productCode = _s(od['objectProductCode']) ?? _s(od['productNumber']) ?? '';
    final upc = _s(od['upc']) ?? '';
    final unitQty = od['scalarUnitQuantity'];
    final caseQty = od['caseQuantity'];
    final isMultiPack = pd.isNotEmpty;
    final packQty = pd['packQuantity'];
    final color = _s(od['color']) ?? '';
    // Prefer the specific `fragrance` value (e.g. "Apple") from
    // detailData.allSpecs over the more generic `scent` (e.g. "Characteristic")
    // that the scraper writes onto objectData. The Solenis API exposes both
    // ProductScent__c and ItemCatFragrance__c — fragrance is the user-facing
    // term we want to display.
    final fragrance = _s(_m(_m(_data['detailData'])['allSpecs'])['fragrance']) ??
        _s(od['scent']) ??
        '';
    final containerType = _s(od['containerType']) ?? '';
    final productLine = _s(od['productLine']) ?? '';
    final canonicalUrl = _s(od['canonicalUrl']) ?? '';
    final materialNumber = _s(od['materialNumber']) ?? '';
    final isConsumable = _categoryName.toLowerCase().contains('consumable');

    // Images
    final storageImages = _l(dd['storageImages']);
    final mediaItems = <FileCarouselItem>[];
    for (final img in storageImages) {
      final url = _s(_m(img)['downloadUrl']) ?? '';
      if (url.isNotEmpty) mediaItems.add(FileCarouselItem.image(imageUrl: url));
    }
    if (mediaItems.isEmpty) {
      for (final link in _l(dd['imageLinks'])) {
        final url = _s(_m(link)['href']) ?? _s(_m(link)['url']) ?? '';
        if (url.isNotEmpty) mediaItems.add(FileCarouselItem.image(imageUrl: url));
      }
    }

    // Documents
    final storageDocs = _l(dd['storageDocuments']);
    final sdsLinks = _l(dd['sdsLinks']);
    final productSheetLinks = _l(dd['productSheetLinks']);
    final allDocs = storageDocs.isNotEmpty ? storageDocs : [...sdsLinks, ...productSheetLinks];

    // Build tab content based on current index
    Widget tabContent;
    switch (_tabController.index) {
      case 1:
        tabContent = const Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: Text('Parts, Materials, Inventory, and Processes will appear here after transfer.')),
        );
        break;
      case 2:
        tabContent = _buildAdditionalTabInline(sd, specs, materialNumber, rd);
        break;
      default:
        tabContent = _buildDetailsTabInline(name, productCode, upc, unitQty, caseQty,
            isMultiPack, packQty, pd, color, fragrance, containerType, productLine,
            isConsumable, allDocs, canonicalUrl, storageImages);
    }

    return Scaffold(
      appBar: null,
      body: SafeArea(
        top: true,
        bottom: false,
        child: ListView(
          children: [
            // ContainerHeader scrolls with the content
            ContainerHeader(
              mediaItems: mediaItems.isNotEmpty ? mediaItems : null,
              showImage: mediaItems.isNotEmpty,
              titleHeader: 'Product',
              title: name,
              descriptionHeader: loc.commonDescription,
              description: description.isNotEmpty ? description : '',
              textIcon: Icons.category_outlined,
              descriptionIcon: Icons.info_outlined,
            ),
            // Tabs
            StandardTabBar(
              controller: _tabController,
              isScrollable: false,
              tabs: const [
                Tab(text: 'Details'),
                Tab(text: 'Elements'),
                Tab(text: 'Additional'),
              ],
            ),
            // Tab content inline (no nested scroll)
            tabContent,
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

  Widget _buildDetailsTabInline(
    String name, String productCode, String upc,
    dynamic unitQty, dynamic caseQty,
    bool isMultiPack, dynamic packQty, Map<String, dynamic> packagingData,
    String color, String fragrance, String containerType, String productLine,
    bool isConsumable, List<dynamic> allDocs, String canonicalUrl, List<dynamic> storageImages,
  ) {
    return Column(
      children: [
        // 1. Product Details — header suppressed; ordered Brand, Brand Owner,
        // Product Code, UPC.
        ContainerActionWidget(
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
                value:
                    _brandOwnerName.isNotEmpty ? _brandOwnerName : 'Not set',
                icon: Icons.business_outlined,
              ),
              const SizedBox(height: 12),
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

        // 2. Specifications — header suppressed; Usage, Unit, Unit Value.
        // SKU Config intentionally omitted (lives at the packaging level).
        ContainerActionWidget(
          actionText: '',
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              HeaderInfoIconValue(
                header: 'Usage',
                // Prefer the confirmed scalar name (resolved from
                // objectData.scalarId). Falls back to the scraper's
                // suggestedScalarKey so the reviewer sees the LLM's pick
                // before they've confirmed the category.
                value: _scalarName.isNotEmpty
                    ? _scalarName
                    : _s(_data['suggestedScalarKey']) ?? 'Not set',
                icon: Icons.straighten,
              ),
              const SizedBox(height: 12),
              HeaderInfoIconValue(
                header: 'Unit',
                // Prefer the resolved scalarUnitId reference name; fall back
                // to the literal unitOfMeasure string via the shared
                // `_weightUom()` helper, which checks objectData →
                // top-level → normalizedData → detailData → allSpecs.
                // The scraper writes the value to `detailData.allSpecs`
                // (and `detailData` top-level), so an inline fallback that
                // misses those paths will show "Not set" even when "LB" is
                // present.
                value: _scalarUnitName.isNotEmpty
                    ? _scalarUnitName
                    : (() {
                        final uom = _weightUom();
                        return uom.isEmpty ? 'Not set' : uom;
                      })(),
                icon: Icons.science_outlined,
              ),
              const SizedBox(height: 12),
              HeaderInfoIconValue(
                header: 'Unit Value',
                value: unitQty != null ? '$unitQty' : 'Not set',
                icon: Icons.format_list_numbered,
              ),
              const SizedBox(height: 12),
              // Unit Weight = weight of one individual consumer unit (one
              // can, one bottle, one wipe, etc.).
              //
              // CRITICAL: Solenis does NOT expose a per-individual-unit
              // weight field. The `ItemNetWeightSKULB__c` family is the
              // CASE-level total — for a 6×16oz multipack of air freshener,
              // ItemNetWeightSKULB__c = 6.261 LB which is the whole case,
              // not one can. To get per-can weight you have to divide by
              // ItemQuantityInSKU__c (or equivalently the pack quantity the
              // scraper writes into packagingData).
              //
              // We prefer the `*LB__c` suffixed fields because the
              // unsuffixed fields hold the metric base value (KG):
              //   ItemNetWeight__c       = "2.84"  (KG)
              //   ItemNetWeightLB__c     = "6.261" (LB ← what we want)
              Builder(builder: (_) {
                final detail = _m(_data['detailData']);
                final allSpecs = _m(detail['allSpecs']);
                final allFields = _m(detail['allFields']);
                final pd = _m(_data['packagingData']);
                final uom = _weightUom();

                // Case-level net weight, LB-first.
                final caseWeightRaw = _firstNonEmpty(allFields, const [
                      'ItemNetWeightSKULB__c',
                      'ItemNetWeightLB__c',
                    ]) ??
                    allSpecs['netWeightSku'] ??
                    allSpecs['netWeight'] ??
                    allSpecs['grossWeightSku'] ??
                    allSpecs['grossWeight'];
                final caseWeight = _toDouble(caseWeightRaw);

                // Pack quantity — how many consumer units share this case.
                // The scraper already extracts this into packagingData; we
                // also accept the raw Solenis field as a fallback.
                final packQty = _toDouble(pd['packQuantity']) ??
                    _toDouble(allFields['ItemQuantityInSKU__c']) ??
                    1.0;

                String displayValue;
                if (caseWeight == null) {
                  displayValue = 'Not set';
                } else if (packQty > 1) {
                  final perUnit = caseWeight / packQty;
                  // 2 decimal places matches Solenis's own display
                  // precision (they publish "6.261" → 1 unit = 1.04).
                  displayValue = uom.isEmpty
                      ? perUnit.toStringAsFixed(2)
                      : '${perUnit.toStringAsFixed(2)} $uom';
                } else {
                  // Single-unit product — case IS the unit, no division.
                  displayValue = _formatWeight(caseWeightRaw, uom);
                }

                return HeaderInfoIconValue(
                  header: 'Unit Weight',
                  value: displayValue,
                  icon: Icons.scale_outlined,
                );
              }),

              // Per-consumer-unit dimensions. Solenis exposes these under
              // the CU field family (ItemLengthCU__c / ItemLengthCUin__c
              // etc.) and uses a dedicated UOM field `ItemCUDimensionsUOM__c`.
              //
              // These fields are commonly null for multipack consumables
              // (where Solenis doesn't bother publishing per-can dimensions),
              // but populated for products where the individual unit's
              // footprint matters — dispensers, floor machines, bulk tools.
              //
              // Rendered conditionally: if ALL six candidate keys are
              // missing/empty, the block is omitted entirely so products
              // that don't publish CU data don't show empty rows.
              Builder(builder: (_) {
                final detail = _m(_data['detailData']);
                final allFields = _m(detail['allFields']);

                final cuLength = _firstNonEmpty(allFields, const [
                  'ItemLengthCUin__c',
                  'ItemLengthCU__c',
                ]);
                final cuWidth = _firstNonEmpty(allFields, const [
                  'ItemWidthCUin__c',
                  'ItemWidthCU__c',
                ]);
                final cuHeight = _firstNonEmpty(allFields, const [
                  'ItemHeightCUin__c',
                  'ItemHeightCU__c',
                ]);

                // If any are present, render the rows. Otherwise emit an
                // empty widget so the container collapses without the
                // "Not set" noise.
                final hasAnyCu =
                    cuLength != null || cuWidth != null || cuHeight != null;
                if (!hasAnyCu) return const SizedBox.shrink();

                // The `in` suffix on ItemLength**CUin**__c is already the
                // unit. For the unsuffixed ItemLengthCU__c family we fall
                // back to the vendor's declared CU UOM.
                final cuUom = _s(allFields['ItemCUDimensionsUOM__c']) ?? 'in';

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 12),
                    HeaderInfoIconValue(
                      header: 'Length',
                      value: _formatWeight(cuLength, cuUom),
                      icon: Icons.straighten,
                    ),
                    const SizedBox(height: 12),
                    HeaderInfoIconValue(
                      header: 'Width',
                      value: _formatWeight(cuWidth, cuUom),
                      icon: Icons.straighten,
                    ),
                    const SizedBox(height: 12),
                    HeaderInfoIconValue(
                      header: 'Height',
                      value: _formatWeight(cuHeight, cuUom),
                      icon: Icons.height,
                    ),
                  ],
                );
              }),
            ],
          ),
        ),

        // 3. Attributes — moved above Category per UX direction. Header kept.
        if (color.isNotEmpty || fragrance.isNotEmpty || containerType.isNotEmpty || productLine.isNotEmpty)
          ContainerActionWidget(
            title: 'Attributes',
            actionText: '',
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (productLine.isNotEmpty) HeaderInfoIconValue(header: 'Product Line', value: productLine, icon: Icons.linear_scale),
                if (color.isNotEmpty) ...[if (productLine.isNotEmpty) const SizedBox(height: 12), HeaderInfoIconValue(header: 'Color', value: color, icon: Icons.palette_outlined)],
                if (fragrance.isNotEmpty) ...[const SizedBox(height: 12), HeaderInfoIconValue(header: 'Fragrance', value: fragrance, icon: Icons.air)],
                if (containerType.isNotEmpty) ...[const SizedBox(height: 12), HeaderInfoIconValue(header: 'Container', value: containerType, icon: Icons.takeout_dining_outlined)],
              ],
            ),
          ),

        // 4. Category — header suppressed. Three visual states:
        //   • CONFIRMED  : objectData.objectCategoryId is set; show the
        //                  category name with a green check, "Change" action.
        //   • SUGGESTED  : only suggestedCategoryId is set; show the
        //                  suggestion with an amber pill + "Confirm" /
        //                  "Change" actions. Reviewer must act to advance.
        //   • UNSET      : neither set; show "Pick a category" CTA.
        ContainerActionWidget(
          actionText: '',
          content: _buildCategoryRow(),
        ),

        // 5. Packaging (if multi-pack) — interactive preview tile
        if (isMultiPack)
          ContainerActionWidget(
            title: 'Packaging (1)',
            actionText: '',
            content: _buildPackagingPreviewTile(context, packagingData, name, caseQty),
          ),

        // 6. Resources (documents)
        ContainerActionWidget(
          title: 'Resources (${allDocs.length})',
          actionText: '',
          content: allDocs.isEmpty
              ? const Text('No documents')
              : Column(
                  children: [
                    for (final doc in allDocs)
                      _buildDocTile(doc),
                  ],
                ),
        ),

        // 7. Images
        ContainerActionWidget(
          title: 'Images (${storageImages.length})',
          actionText: '',
          content: storageImages.isEmpty
              ? const Text('No images uploaded')
              : Column(
                  children: [
                    for (int i = 0; i < storageImages.length; i++)
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: Image.network(
                            (_m(storageImages[i])['downloadUrl'] ?? '').toString(),
                            width: 48, height: 48, fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, size: 48),
                          ),
                        ),
                        title: Text(i == 0 ? 'Primary Image' : 'Image ${i + 1}',
                            style: TextStyle(fontWeight: i == 0 ? FontWeight.bold : FontWeight.normal)),
                        subtitle: Row(children: [
                          const Icon(Icons.cloud_done, size: 14, color: Colors.green),
                          const SizedBox(width: 4),
                          const Text('In Storage', style: TextStyle(fontSize: 11, color: Colors.green)),
                        ]),
                      ),
                  ],
                ),
        ),

        // 8. Source
        if (canonicalUrl.isNotEmpty)
          ContainerActionWidget(
            title: 'Source',
            actionText: '',
            content: InkWell(
              onTap: () async {
                final uri = Uri.tryParse(canonicalUrl);
                if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
              },
              child: Row(children: [
                const Icon(Icons.link, size: 18, color: Colors.blue),
                const SizedBox(width: 8),
                Expanded(child: Text(canonicalUrl, style: const TextStyle(color: Colors.blue, fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis)),
              ]),
            ),
          ),
      ],
    );
  }

  Widget _buildAdditionalTabInline(Map<String, dynamic> solenisData, Map<String, dynamic> specs, String materialNumber, Map<String, dynamic> rawData) {
    return Column(
      children: [
        if (materialNumber.isNotEmpty)
          ContainerActionWidget(
            title: 'Identifiers',
            actionText: '',
            content: HeaderInfoIconValue(header: 'Material Number', value: materialNumber, icon: Icons.tag),
          ),

        if (solenisData.isNotEmpty)
          ContainerActionWidget(
            title: 'Vendor Data',
            actionText: '',
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final entry in solenisData.entries)
                  if (_s(entry.value.toString()) != null && entry.key != 'extractionMethod')
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_formatKey(entry.key), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Colors.grey)),
                          const SizedBox(height: 2),
                          SelectableText(
                            entry.value is List ? (entry.value as List).join(', ') : entry.value.toString(),
                            style: const TextStyle(fontSize: 13),
                          ),
                        ],
                      ),
                    ),
              ],
            ),
          ),

        if (specs.isNotEmpty)
          ContainerActionWidget(
            title: 'Product Specs',
            actionText: '',
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final entry in specs.entries)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_formatKey(entry.key), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Colors.grey)),
                        const SizedBox(height: 2),
                        SelectableText(
                          entry.value is List ? (entry.value as List).join(', ') : entry.value.toString(),
                          style: const TextStyle(fontSize: 13),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildDocTile(dynamic doc) {
    final m = _m(doc);
    final url = _s(m['downloadUrl']) ?? _s(m['href']) ?? _s(m['url']) ?? '';
    final name = _s(m['name']) ?? _s(m['text']) ?? _s(m['fileName']) ?? 'Document';
    final type = _s(m['type']) ?? '';
    final isFromStorage = _s(m['storagePath'])?.isNotEmpty == true;
    final isSds = type.toUpperCase() == 'SDS';

    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(isSds ? Icons.warning_amber_outlined : Icons.description_outlined, color: isSds ? Colors.orange : Colors.blue),
      title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Row(children: [
        if (type.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: (isSds ? Colors.orange : Colors.blue).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(3),
            ),
            child: Text(type.toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 6),
        ],
        Icon(isFromStorage ? Icons.cloud_done : Icons.cloud_off, size: 14, color: isFromStorage ? Colors.green : Colors.orange),
        const SizedBox(width: 4),
        Text(isFromStorage ? 'In Storage' : 'Vendor URL', style: TextStyle(fontSize: 11, color: isFromStorage ? Colors.green : Colors.orange)),
      ]),
      trailing: url.isNotEmpty ? IconButton(icon: const Icon(Icons.open_in_new, size: 18), onPressed: () async {
        final uri = Uri.tryParse(url);
        if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
      }) : null,
    );
  }

  /// Renders the Category row in one of three states:
  ///   • CONFIRMED — `_categoryName` set; show the category in green with a
  ///     checkmark and a "Change" button.
  ///   • SUGGESTED — only `_suggestedCategoryName` set; show an amber pill
  ///     with the suggestion and a "Confirm" / "Change" pair.
  ///   • UNSET — neither set; show "No category yet" with a "Pick" button.
  Widget _buildCategoryRow() {
    final isConfirmed = _categoryName.isNotEmpty;
    final hasSuggestion = !isConfirmed && _suggestedCategoryName.isNotEmpty;

    if (isConfirmed) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(Icons.check_circle, size: 20, color: Colors.green.shade700),
          const SizedBox(width: 8),
          Expanded(
            child: HeaderInfoIconValue(
              header: 'Category',
              value: _categoryName,
              icon: Icons.category,
            ),
          ),
          TextButton(
            onPressed: _openCategoryPicker,
            child: const Text('Change'),
          ),
        ],
      );
    }

    if (hasSuggestion) {
      // Reasoning written by the scraper's LLM classifier (Gemini 2.5 Flash).
      // Falls back to '(keyword fallback)' when the LLM call failed at scrape
      // time and the keyword classifier filled in.
      final reasoning = _s(_data['suggestedCategoryReasoning']) ?? '';

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'SUGGESTED',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Colors.orange.shade800,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _suggestedCategoryName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
              // Suggested usage (scalar) shown inline so the reviewer
              // sees both category + usage without scrolling.
              Builder(builder: (_) {
                final suggestedScalar =
                    _s(_data['suggestedScalarKey']) ?? '';
                if (suggestedScalar.isEmpty) return const SizedBox.shrink();
                return Text(
                  suggestedScalar,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade600,
                  ),
                );
              }),
            ],
          ),
          if (reasoning.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              reasoning,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade700,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              FilledButton.icon(
                onPressed: _confirmSuggestedCategory,
                icon: const Icon(Icons.check, size: 18),
                label: const Text('Confirm'),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _openCategoryPicker,
                icon: const Icon(Icons.swap_horiz, size: 18),
                label: const Text('Change'),
              ),
            ],
          ),
        ],
      );
    }

    // Unset
    return Row(
      children: [
        Icon(Icons.warning_amber_outlined, size: 20, color: Colors.grey.shade600),
        const SizedBox(width: 8),
        const Expanded(child: Text('No category yet')),
        FilledButton.icon(
          onPressed: _openCategoryPicker,
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Pick'),
        ),
      ],
    );
  }

  /// Copies the suggested category onto `objectData.objectCategoryId` without
  /// reopening the picker. Used when the reviewer agrees with the scraper.
  /// Passes copyScalar:true so the matching scalar (Volume / Time / Count
  /// derived by the scraper) lands on objectData.scalarId in the same write.
  Future<void> _confirmSuggestedCategory() async {
    final suggestedRef = _data['suggestedCategoryId'];
    if (suggestedRef is! DocumentReference) return;
    await _writeConfirmedCategory(suggestedRef, copyScalar: true);
  }

  /// Opens a picker that lists every doc in `objectCategory`. On selection,
  /// writes the chosen ref to `objectData.objectCategoryId` on the staged
  /// product and refreshes the local state.
  Future<void> _openCategoryPicker() async {
    final snap = await CatalogFirebaseService.instance.firestore
        .collection('objectCategory')
        .get();
    final docs = snap.docs.toList()
      ..sort((a, b) {
        final an = ((a.data())['name'] ?? '').toString().toLowerCase();
        final bn = ((b.data())['name'] ?? '').toString().toLowerCase();
        return an.compareTo(bn);
      });

    if (!mounted) return;
    final chosen = await showModalBottomSheet<DocumentReference>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text(
                  'Pick a category',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
              for (final doc in docs)
                ListTile(
                  leading: const Icon(Icons.category_outlined),
                  title: Text((doc.data()['name'] ?? '').toString()),
                  onTap: () => Navigator.of(ctx).pop(doc.reference),
                ),
            ],
          ),
        ),
      ),
    );

    if (chosen != null) {
      await _writeConfirmedCategory(chosen);
    }
  }

  /// Writes the chosen category ref into `objectData.objectCategoryId` on
  /// the staged product and refreshes local state. Uses dotted-field update
  /// so we don't have to round-trip the entire objectData map.
  ///
  /// Also writes `objectData.scalarId` from the scraper's
  /// `suggestedScalarId` (when the reviewer accepts the LLM's category, the
  /// matching scalar — Volume / Time / Count — comes along automatically per
  /// the deterministic mapping baked into the scraper). The reviewer can
  /// still override the scalar later in the standard objects form.
  ///
  /// Skips the scalar copy when the reviewer is overriding the category via
  /// the picker — the suggested scalar was derived from the suggested
  /// category, not the new one — so the scalar field stays at whatever the
  /// staged product's `objectData.scalarId` already holds (often null).
  Future<void> _writeConfirmedCategory(
    DocumentReference ref, {
    bool copyScalar = false,
  }) async {
    try {
      final updates = <String, dynamic>{
        'objectData.objectCategoryId': ref,
      };

      // When the reviewer confirms the LLM's suggested category, the
      // matching scalar ref also moves onto objectData. The scraper writes
      // both `suggestedCategoryId` and `suggestedScalarId` so we don't have
      // to re-derive anything client-side.
      DocumentReference? scalarRef;
      if (copyScalar) {
        final raw = _data['suggestedScalarId'];
        if (raw is DocumentReference) {
          scalarRef = raw;
          updates['objectData.scalarId'] = raw;
        }
      }

      // Clear scalarUnitId so a stale unit from the scraper's initial
      // skuConfig parsing doesn't carry through to the object collection.
      // Example: the scraper matched "oz" → Ounce under Volume, but the
      // LLM then changed the scalar to Units (cartridge product). Keeping
      // the old Ounce reference would be wrong. The reviewer picks the
      // correct unit in the CleanOps objects form after transfer.
      updates['objectData.scalarUnitId'] = FieldValue.delete();

      await CatalogFirebaseService.instance.firestore
          .collection('stagedProduct')
          .doc(widget.docId)
          .update(updates);

      // Optimistically update local state so the UI flips to CONFIRMED
      // without waiting for a full reload.
      final od = _m(_data['objectData']);
      od['objectCategoryId'] = ref;
      if (scalarRef != null) {
        od['scalarId'] = scalarRef;
      }
      _data['objectData'] = od;

      try {
        final s = await ref.get();
        if (s.exists) {
          _categoryName = ((s.data() as Map?)?['name'] ?? '').toString();
        }
      } catch (_) {}

      // If we copied a scalar, refresh _scalarName too so the Specifications
      // container's "Usage" row updates from "Not set" to (e.g.) "Time".
      if (scalarRef != null) {
        try {
          final s = await scalarRef.get();
          if (s.exists) {
            _scalarName = ((s.data() as Map?)?['name'] ?? '').toString();
          }
        } catch (_) {}
      }

      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Category set: $_categoryName')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to set category: $e')),
        );
      }
    }
  }

  Widget _buildPackagingPreviewTile(BuildContext context, Map<String, dynamic> pd, String parentName, dynamic caseQty) {
    final packQty = pd['packQuantity'];
    final packName = _s(pd['packName']) ?? _s(pd['name']) ?? '';
    final packType = _s(pd['packagingType']) ?? 'pack';
    final displayName = packName.isNotEmpty ? packName : '$packQty-$packType of $parentName';

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => _showPackagingPreviewSheet(context, pd, parentName, caseQty),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.inventory_2_outlined, color: Colors.blue, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(displayName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  const SizedBox(height: 2),
                  Text(
                    'Qty: ${packQty ?? '—'}  •  Type: ${_formatKey(packType)}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }

  void _showPackagingPreviewSheet(BuildContext context, Map<String, dynamic> pd, String parentName, dynamic caseQty) {
    final packQty = pd['packQuantity'];
    final packName = _s(pd['packName']) ?? _s(pd['name']) ?? '';
    final packType = _s(pd['packagingType']) ?? 'pack';
    final upc = _s(pd['objectBarcode']) ?? _s(pd['upc']) ?? '';
    final productCode = _s(pd['productNumber']) ?? _s(pd['objectProductCode']) ?? '';
    final displayName = packName.isNotEmpty ? packName : '$packQty-$packType of $parentName';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.55,
        minChildSize: 0.3,
        maxChildSize: 0.85,
        expand: false,
        builder: (_, scrollController) => ListView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            // Header
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.inventory_2_outlined, color: Colors.blue, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Packaging Variant', style: TextStyle(fontSize: 11, color: Colors.grey)),
                      const SizedBox(height: 2),
                      Text(displayName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Divider(),
            const SizedBox(height: 8),
            // Parent reference
            ContainerActionWidget(
              title: 'Parent Product',
              actionText: '',
              content: Row(
                children: [
                  const Icon(Icons.category_outlined, size: 18, color: Colors.grey),
                  const SizedBox(width: 8),
                  Expanded(child: Text(parentName, style: const TextStyle(fontSize: 14))),
                ],
              ),
            ),
            // Packaging details
            ContainerActionWidget(
              title: 'Packaging Details',
              actionText: '',
              content: Builder(builder: (_) {
                // Read the raw Solenis fields directly from `detailData.allFields`
                // (the safety net we added when the named extracts in the
                // scraper didn't match the real SF field names). The
                // candidate lists below were derived from a real staged
                // product dump:
                //   - dimensions live as ItemLengthTUin__c / ItemWidthTUin__c
                //     / ItemHeigthTUin__c  (note Solenis's "Heigth" typo)
                //   - pallet counts live as ItemNumberSSKULayerGMAPallet__c
                //     / ItemNumberSSKUGMAPallet__c
                //
                // For weights we prefer the `*LB__c` suffixed fields because
                // Solenis exposes the same physical measurement twice — the
                // unsuffixed version is the metric base (KG) and the LB
                // version is already converted to the display unit
                // (`ItemWeightUnitOfMeasure__c: "LB"`). Showing the metric
                // value labeled as LB would be wrong (e.g. "2.84 LB" when
                // the value is actually 2.84 KG / 6.261 LB).
                final detail = _m(_data['detailData']);
                final allSpecs = _m(detail['allSpecs']);
                final allFields = _m(detail['allFields']);
                final weightUom = _weightUom();

                // Per-case weights, LB-first.
                final packageWeightValue = _firstNonEmpty(allFields, const [
                      'ItemPackageWeightSKULB__c',
                      'ItemPackageWeightLB__c',
                    ]) ??
                    allSpecs['packageWeight'];
                final grossWeightValue = _firstNonEmpty(allFields, const [
                      'ItemGrossWeightSKULB__c',
                      'ItemGrossWeightLB__c',
                    ]) ??
                    allSpecs['grossWeightSku'] ??
                    allSpecs['grossWeight'];

                // Case dimensions — always inches when read from the
                // ItemXXXTUin__c / ItemXXXSKUin__c family (the `in` suffix
                // is the unit). Solenis also exposes mm via ItemDimensionsUOM__c;
                // we ignore that for the inch fields.
                const dimensionsUom = 'in';
                final lengthValue = _firstNonEmpty(allFields, const [
                      'ItemLengthTUin__c',
                      'ItemDepthSKUin__c',
                    ]) ??
                    allSpecs['length'];
                final widthValue = _firstNonEmpty(allFields, const [
                      'ItemWidthTUin__c',
                      'ItemWidthSKUin__c',
                    ]) ??
                    allSpecs['width'];
                // Solenis spells the field "Heigth" (sic). We try the
                // misspelled name first, then the corrected one.
                final heightValue = _firstNonEmpty(allFields, const [
                      'ItemHeigthTUin__c',
                      'ItemHeightSKUin__c',
                    ]) ??
                    allSpecs['height'];

                // Pallet counts.
                final tuPerLayer = _firstNonEmpty(allFields, const [
                      'ItemNumberSSKULayerGMAPallet__c',
                      'ItemNumberSSKULayerEUPallet__c',
                    ]) ??
                    allSpecs['tradedUnitsPerLayer'];
                final tuPerPallet = _firstNonEmpty(allFields, const [
                      'ItemNumberSSKUGMAPallet__c',
                      'ItemNumberSSKUEUPallet__c',
                    ]) ??
                    allSpecs['tradedUnitsPerPallet'];

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    HeaderInfoIconValue(header: 'Packaging Type', value: _formatKey(packType), icon: Icons.style_outlined),
                    const SizedBox(height: 12),
                    HeaderInfoIconValue(header: 'Pack Quantity', value: '${packQty ?? '—'}', icon: Icons.inventory),
                    if (caseQty != null) ...[
                      const SizedBox(height: 12),
                      HeaderInfoIconValue(header: 'Case Quantity', value: '$caseQty', icon: Icons.calculate_outlined),
                    ],
                    const SizedBox(height: 12),
                    HeaderInfoIconValue(
                      header: 'Package Weight',
                      value: _formatWeight(packageWeightValue, weightUom),
                      icon: Icons.scale_outlined,
                    ),
                    const SizedBox(height: 12),
                    HeaderInfoIconValue(
                      header: 'Gross Weight',
                      value: _formatWeight(grossWeightValue, weightUom),
                      icon: Icons.fitness_center_outlined,
                    ),
                    const SizedBox(height: 12),
                    HeaderInfoIconValue(
                      header: 'Length',
                      value: _formatWeight(lengthValue, dimensionsUom),
                      icon: Icons.straighten,
                    ),
                    const SizedBox(height: 12),
                    HeaderInfoIconValue(
                      header: 'Width',
                      value: _formatWeight(widthValue, dimensionsUom),
                      icon: Icons.straighten,
                    ),
                    const SizedBox(height: 12),
                    HeaderInfoIconValue(
                      header: 'Height',
                      value: _formatWeight(heightValue, dimensionsUom),
                      icon: Icons.height,
                    ),
                    const SizedBox(height: 12),
                    HeaderInfoIconValue(
                      header: 'Units per Layer',
                      value: _s(tuPerLayer) ?? 'Not set',
                      icon: Icons.layers_outlined,
                    ),
                    const SizedBox(height: 12),
                    HeaderInfoIconValue(
                      header: 'Units per Pallet',
                      value: _s(tuPerPallet) ?? 'Not set',
                      icon: Icons.dashboard_outlined,
                    ),
                  ],
                );
              }),
            ),
            // Identifiers
            if (upc.isNotEmpty || productCode.isNotEmpty)
              ContainerActionWidget(
                title: 'Identifiers',
                actionText: '',
                content: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (productCode.isNotEmpty)
                      HeaderInfoIconValue(header: 'Product Code', value: productCode, icon: Icons.confirmation_number_outlined),
                    if (productCode.isNotEmpty && upc.isNotEmpty)
                      const SizedBox(height: 12),
                    if (upc.isNotEmpty)
                      HeaderInfoIconValue(header: 'UPC', value: upc, icon: Icons.qr_code),
                  ],
                ),
              ),
            // Preview note
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 14, color: Colors.grey.shade500),
                  const SizedBox(width: 6),
                  Text(
                    'This packaging object will be created on transfer.',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontStyle: FontStyle.italic),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatKey(String key) {
    return key.replaceAllMapped(RegExp(r'([a-z])([A-Z])'), (m) => '${m[1]} ${m[2]}')
        .replaceAll('_', ' ')
        .split(' ')
        .map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }
}
