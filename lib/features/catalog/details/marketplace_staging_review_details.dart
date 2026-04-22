import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:kleenops_admin/l10n/app_localizations.dart';
import 'package:shared_widgets/services/catalog_firebase_service.dart';
import 'package:shared_widgets/containers/container_action.dart';
import 'package:shared_widgets/containers/container_header.dart';
import 'package:shared_widgets/viewers/file_carousel_viewer.dart';
import 'package:shared_widgets/labels/header_info_icon_value.dart';
import 'package:shared_widgets/labels/text_info_checkbox.dart';
import 'package:shared_widgets/tabs/standard_tab.dart';
import 'package:shared_widgets/tiles/standard_tile_large.dart';
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
    with TickerProviderStateMixin {
  late Map<String, dynamic> _data;
  // Top tabs: Details / Elements / Additional. Mirrors the catalog detail
  // structure (Details / Elements) and keeps the staging-only Additional
  // tab as a third entry for raw vendor field inspection.
  late TabController _topTabController;
  // Inner Elements tabs: Parts / Materials / Processes — mirrors the
  // catalog detail's nested element sub-tabs.
  late TabController _elementsTabController;
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
    _topTabController = TabController(length: 3, vsync: this);
    _topTabController.addListener(() { if (mounted) setState(() {}); });
    _elementsTabController = TabController(length: 3, vsync: this);
    _elementsTabController.addListener(() { if (mounted) setState(() {}); });
    _loadLatest();
  }

  @override
  void dispose() {
    _topTabController.dispose();
    _elementsTabController.dispose();
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

    // Build tab content based on current top-level tab index. Mirrors the
    // catalog detail's Details / Elements split, with Additional retained
    // as a third tab for staging-only raw vendor field inspection.
    Widget tabContent;
    switch (_topTabController.index) {
      case 1:
        tabContent = _buildElementsTab();
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
              controller: _topTabController,
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
    // Resolve the suggested/confirmed category name for flat display.
    final displayCategory = _categoryName.isNotEmpty
        ? _categoryName
        : _suggestedCategoryName.isNotEmpty
            ? _suggestedCategoryName
            : _s(_data['suggestedCategoryKey']) ?? 'Not set';
    final displayUsage = _scalarName.isNotEmpty
        ? _scalarName
        : _s(_data['suggestedScalarKey']) ?? 'Not set';

    // Covering-capable category set mirrors the catalog detail gate so
    // the staging view only shows the Scalar (floor/wall/ceiling) toggles
    // when they're actually meaningful.
    final allowScalarContainer = _categoryName == 'Furnishings' ||
        _categoryName == 'Grounds' ||
        _suggestedCategoryName == 'Furnishings' ||
        _suggestedCategoryName == 'Grounds';

    return Column(
      children: [
        // 1. Brand
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
                value: _brandOwnerName.isNotEmpty ? _brandOwnerName : 'Not set',
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

        // 3. Item Packaging — product weight + container/packing type
        ContainerActionWidget(
          title: '',
          actionText: '',
          content: Builder(builder: (_) {
            final od = _m(_data['objectData']);
            final detail = _m(_data['detailData']);
            final allSpecs = _m(detail['allSpecs']);
            final allFields = _m(detail['allFields']);
            final pdLocal = _m(_data['packagingData']);

            // Per-unit weight
            double? perUnitWeight = _toDouble(od['productWeight']);
            if (perUnitWeight == null) {
              final caseWeightRaw = _firstNonEmpty(allFields, const [
                    'ItemNetWeightSKULB__c',
                    'ItemNetWeightLB__c',
                  ]) ??
                  allSpecs['netWeightSku'] ??
                  allSpecs['netWeight'];
              final caseWeight = _toDouble(caseWeightRaw);
              if (caseWeight != null) {
                final pq = _toDouble(pdLocal['packQuantity']) ??
                    _toDouble(allFields['ItemQuantityInSKU__c']) ??
                    1.0;
                perUnitWeight = pq > 1
                    ? (caseWeight / pq * 100).roundToDouble() / 100
                    : caseWeight;
              }
            }
            final weightUom = _weightUom();

            // Content unit + value
            final contentUom = _scalarUnitName.isNotEmpty
                ? _scalarUnitName
                : _s(allFields['ItemConsumerUnitSizeUOM__c']) ??
                    _s(allFields['ItemBaseUoM__c']) ??
                    'Not set';

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                HeaderInfoIconValue(
                  header: 'Content Unit',
                  value: contentUom,
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
                  value: weightUom.isNotEmpty ? weightUom : 'Not set',
                  icon: Icons.balance_outlined,
                ),
                const SizedBox(height: 12),
                HeaderInfoIconValue(
                  header: 'Product Weight Value',
                  value: perUnitWeight != null
                      ? perUnitWeight.toStringAsFixed(2)
                      : 'Not set',
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
            );
          }),
        ),

        // 4. Categories — usage + object category as flat data (no
        // suggestion/confirm UX — the LLM's pick is displayed as fact).
        ContainerActionWidget(
          title: '',
          actionText: '',
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              HeaderInfoIconValue(
                header: 'Usage',
                value: displayUsage,
                icon: Icons.straighten,
              ),
              const SizedBox(height: 12),
              HeaderInfoIconValue(
                header: 'Object Category',
                value: displayCategory,
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

        // 6. Attributes — color, fragrance, and other product attributes.
        if (color.isNotEmpty || fragrance.isNotEmpty)
          ContainerActionWidget(
            title: '',
            actionText: '',
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (color.isNotEmpty)
                  HeaderInfoIconValue(header: 'Color', value: color, icon: Icons.palette_outlined),
                if (color.isNotEmpty && fragrance.isNotEmpty)
                  const SizedBox(height: 12),
                if (fragrance.isNotEmpty)
                  HeaderInfoIconValue(header: 'Fragrance', value: fragrance, icon: Icons.air),
              ],
            ),
          ),

        // 6a. Scalar covering checkboxes — Floor / Wall / Ceiling.
        // Only meaningful for Furnishings or Grounds category items, so
        // suppressed entirely otherwise (matches catalog detail gating).
        if (allowScalarContainer) _buildScalarSection(),

        // 6b. Track Object / Safety Response checkboxes.
        _buildTrackSafetySection(),

        // 6c. Bulk Packaging — single child variant tile (the scraper
        // currently emits one packagingData per staged product). Uses
        // StandardTileLargeDart for shape parity with the catalog detail.
        if (isMultiPack)
          ContainerActionWidget(
            title: 'Bulk Packaging',
            actionText: '',
            content: _buildVariantTile(packagingData, name, caseQty),
          ),

        // 7. Resources — documents + web-address row, merged from the
        // separate Resources / Images / Source containers the staging view
        // used to render. Mirrors the catalog detail's single Resources
        // container.
        ContainerActionWidget(
          title: 'Resources',
          actionText: '',
          content: _buildResourcesContent(allDocs, canonicalUrl),
        ),
      ],
    );
  }

  /// Resources tile body — one StandardTileLargeDart per document plus a
  /// trailing Web Address row when a canonical URL is present. PDF rows
  /// render their first page as the thumbnail because StandardTileLargeDart
  /// detects the `.pdf` extension.
  Widget _buildResourcesContent(List<dynamic> docs, String canonicalUrl) {
    final rows = <Widget>[];
    for (final doc in docs) {
      rows.add(_buildResourceTile(doc));
    }
    if (canonicalUrl.isNotEmpty) {
      rows.add(_buildWebAddressTile(canonicalUrl));
    }
    if (rows.isEmpty) {
      return Text('No resources', style: TextStyle(color: Colors.grey.shade600));
    }
    return Column(children: rows);
  }

  Widget _buildResourceTile(dynamic doc) {
    final m = _m(doc);
    final url = _s(m['downloadUrl']) ?? _s(m['href']) ?? _s(m['url']) ?? '';
    final name = _s(m['name']) ?? _s(m['text']) ?? _s(m['fileName']) ?? 'Document';
    final category = (_s(m['type']) ?? '').toUpperCase();

    String fileType = (_s(m['fileType']) ?? _s(m['fileExtension']) ?? '').toUpperCase();
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
        secondLineIcon: category.isNotEmpty ? Icons.folder_outlined : null,
        thirdLine: fileType.isNotEmpty ? fileType : null,
        thirdLineIcon: fileType.isNotEmpty ? Icons.insert_drive_file_outlined : null,
      ),
    );
  }

  Widget _buildWebAddressTile(String url) {
    return InkWell(
      onTap: () async {
        final uri = Uri.tryParse(url);
        if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
      },
      child: StandardTileLargeDart(
        imageUrl: '',
        firstLine: url,
        firstLineIcon: Icons.link,
        secondLine: 'Web Address',
        secondLineIcon: Icons.folder_outlined,
        thirdLine: 'URL',
        thirdLineIcon: Icons.language,
      ),
    );
  }

  /// Bulk Packaging variant tile — same shape as the catalog detail's
  /// `_buildVariantTile`. Tapping opens the existing modal preview sheet
  /// (the staged product hasn't been transferred yet, so there's no child
  /// object detail page to navigate to).
  Widget _buildVariantTile(Map<String, dynamic> pd, String parentName, dynamic caseQty) {
    final packQty = pd['packQuantity'];
    final packType = (_s(pd['packagingType']) ?? 'pack');
    final packName = _s(pd['packName']) ?? _s(pd['name']) ?? '';
    final upc = _s(pd['objectBarcode']) ?? _s(pd['upc']) ?? '';
    final displayName = packName.isNotEmpty
        ? packName
        : '$packQty-$packType of $parentName';
    final secondLine = packQty != null
        ? 'Qty: $packQty (${packType.toLowerCase()})'
        : _formatKey(packType);

    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => _StagingPackagingDetailsScreen(
            packagingData: pd,
            detailData: _m(_data['detailData']),
            parentName: parentName,
          ),
        ),
      ),
      child: StandardTileLargeDart(
        imageUrl: '',
        firstLine: displayName,
        firstLineIcon: Icons.category_outlined,
        secondLine: secondLine,
        secondLineIcon: Icons.inventory_2_outlined,
        thirdLine: upc.isNotEmpty ? 'UPC: $upc' : null,
        thirdLineIcon: upc.isNotEmpty ? Icons.qr_code : null,
      ),
    );
  }

  Widget _buildScalarSection() {
    final od = _m(_data['objectData']);
    return ContainerActionWidget(
      title: 'Scalar',
      actionText: '',
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextInfoCheckbox(
            text: 'Floor Covering',
            value: od['floorCovering'] == true,
            onChanged: (v) => _updateObjectDataField('floorCovering', v ?? false),
          ),
          const SizedBox(height: 6),
          TextInfoCheckbox(
            text: 'Wall Covering',
            value: od['wallCovering'] == true,
            onChanged: (v) => _updateObjectDataField('wallCovering', v ?? false),
          ),
          const SizedBox(height: 6),
          TextInfoCheckbox(
            text: 'Ceiling Covering',
            value: od['ceilingCovering'] == true,
            onChanged: (v) => _updateObjectDataField('ceilingCovering', v ?? false),
          ),
        ],
      ),
    );
  }

  Widget _buildTrackSafetySection() {
    final od = _m(_data['objectData']);
    return ContainerActionWidget(
      title: '',
      actionText: '',
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextInfoCheckbox(
            text: 'Track Object',
            value: od['trackObject'] == true,
            onChanged: (v) => _updateObjectDataField('trackObject', v ?? false),
          ),
          const SizedBox(height: 6),
          TextInfoCheckbox(
            text: 'Safety Response',
            value: od['safetyResponse'] == true,
            onChanged: (v) => _updateObjectDataField('safetyResponse', v ?? false),
          ),
        ],
      ),
    );
  }

  /// Elements tab — Parts / Materials / Processes sub-tabs. Mirrors the
  /// catalog detail's nested element tabs. Staged products don't have any
  /// element data yet (it's created on transfer), so each sub-tab is a
  /// placeholder.
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


  /// Title-cases a whitespace-separated string (e.g. "AEROSOL CAN" → "Aerosol
  /// Can"). The scraper now title-cases containerType at write time, but
  /// older staged products still carry the all-caps Solenis original — this
  /// keeps the display clean without requiring a re-scrape.
  String _titleCase(String s) {
    if (s.isEmpty) return s;
    return s
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .map((w) => w[0].toUpperCase() + w.substring(1).toLowerCase())
        .join(' ');
  }

  /// Writes a top-level boolean field on `objectData` so it transfers
  /// straight to the object collection on approval. Mirrors the in-place
  /// edit pattern used by the catalog detail's checkbox sections.
  Future<void> _updateObjectDataField(String field, bool value) async {
    try {
      await CatalogFirebaseService.instance.firestore
          .collection('stagedProduct')
          .doc(widget.docId)
          .update({'objectData.$field': value});
      final od = _m(_data['objectData']);
      od[field] = value;
      if (mounted) setState(() => _data['objectData'] = od);
    } catch (_) {}
  }

  String _formatKey(String key) {
    return key.replaceAllMapped(RegExp(r'([a-z])([A-Z])'), (m) => '${m[1]} ${m[2]}')
        .replaceAll('_', ' ')
        .split(' ')
        .map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }
}

/// Full-page packaging-variant detail view for staged products.
/// Mirrors the catalog detail's bulk-variant layout so reviewers see
/// the exact post-transfer shape before approving. Data is read from
/// the in-memory `packagingData` map (not a Firestore doc — the object
/// hasn't been created yet) with `detailData.allFields` /
/// `detailData.allSpecs` as fallbacks for older staged products that
/// pre-date the `packagingWeight` / `packagingLength` scraper fields.
class _StagingPackagingDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> packagingData;
  final Map<String, dynamic> detailData;
  final String parentName;

  const _StagingPackagingDetailsScreen({
    required this.packagingData,
    required this.detailData,
    required this.parentName,
  });

  @override
  State<_StagingPackagingDetailsScreen> createState() =>
      _StagingPackagingDetailsScreenState();
}

class _StagingPackagingDetailsScreenState
    extends State<_StagingPackagingDetailsScreen> {
  String _weightUnitName = '';
  String _dimensionsUnitName = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _resolveRefs();
  }

  Future<void> _resolveRefs() async {
    final pd = widget.packagingData;
    final wRef = pd['packagingWeightUnitId'];
    if (wRef is DocumentReference) {
      try {
        final s = await wRef.get();
        if (s.exists) {
          final m = (s.data() as Map?) ?? const {};
          _weightUnitName = (m['abbreviatedName'] ??
                  m['abbreviationName'] ??
                  m['abbreviation'] ??
                  m['name'] ??
                  '')
              .toString();
        }
      } catch (_) {}
    }
    final dRef = pd['packagingDimensionsUnitId'];
    if (dRef is DocumentReference) {
      try {
        final s = await dRef.get();
        if (s.exists) {
          final m = (s.data() as Map?) ?? const {};
          _dimensionsUnitName = (m['abbreviatedName'] ??
                  m['abbreviationName'] ??
                  m['abbreviation'] ??
                  m['name'] ??
                  '')
              .toString();
        }
      } catch (_) {}
    }
    if (mounted) setState(() => _loading = false);
  }

  String? _s(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }

  double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString().trim());
  }

  String _titleCase(String s) {
    if (s.isEmpty) return s;
    return s
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .map((w) => w[0].toUpperCase() + w.substring(1).toLowerCase())
        .join(' ');
  }

  /// Resolves the packaging weight unit. Prefers the scalarUnit ref name,
  /// falls back to the raw `packagingWeightUnit` string, then to the
  /// parent product's weight UoM stashed on detailData.
  String _resolvedWeightUnit() {
    if (_weightUnitName.isNotEmpty) return _weightUnitName;
    final pd = widget.packagingData;
    final raw = (pd['packagingWeightUnit'] ?? '').toString().trim();
    if (raw.isNotEmpty) return raw;
    final allSpecs = widget.detailData['allSpecs'];
    if (allSpecs is Map) {
      return (allSpecs['unitOfMeasure'] ?? '').toString().trim();
    }
    return '';
  }

  String _resolvedDimensionsUnit() {
    if (_dimensionsUnitName.isNotEmpty) return _dimensionsUnitName;
    final pd = widget.packagingData;
    final raw = (pd['packagingDimensionsUnit'] ?? '').toString().trim();
    if (raw.isNotEmpty) return raw;
    final allSpecs = widget.detailData['allSpecs'];
    if (allSpecs is Map) {
      return (allSpecs['dimensionsUnit'] ?? '').toString().trim();
    }
    return '';
  }

  /// Reads a raw Solenis field from detailData.allFields, trying each
  /// candidate key in order. Used as a fallback for packagingLength /
  /// Width / Height when the staged doc pre-dates the new scraper fields.
  dynamic _rawFromDetail(List<String> keys) {
    final fields = widget.detailData['allFields'];
    if (fields is! Map) return null;
    for (final k in keys) {
      final v = fields[k];
      if (v == null) continue;
      final s = v.toString().trim();
      if (s.isNotEmpty) return v;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final pd = widget.packagingData;
    final packQty = pd['packQuantity'];
    final packType = _s(pd['packagingType']) ?? 'case';
    final packName = _s(pd['name']) ?? _s(pd['packName']) ?? '';
    final displayName =
        packName.isNotEmpty ? packName : '$packQty-$packType of ${widget.parentName}';

    final productCode =
        _s(pd['objectProductCode']) ?? _s(pd['productNumber']) ?? '';
    final upc = _s(pd['objectBarcode']) ?? _s(pd['upc']) ?? '';

    // Packaging weight: prefer the new packagingWeight field, else compute
    // from the per-case raw Solenis weight.
    dynamic packagingWeight = pd['packagingWeight'];
    if (packagingWeight == null) {
      packagingWeight = _rawFromDetail(const [
        'ItemNetWeightSKULB__c',
        'ItemNetWeightLB__c',
      ]);
      final d = _toDouble(packagingWeight);
      if (d != null) packagingWeight = (d * 100).roundToDouble() / 100;
    }

    // Dimensions: prefer the new packagingLength/Width/Height, fall back
    // to raw Solenis fields (noting Solenis's "Heigth" typo).
    final length = pd['packagingLength'] ??
        _rawFromDetail(const ['ItemLengthTUin__c', 'ItemDepthSKUin__c']);
    final width = pd['packagingWidth'] ??
        _rawFromDetail(const ['ItemWidthTUin__c', 'ItemWidthSKUin__c']);
    final height = pd['packagingHeight'] ??
        _rawFromDetail(const ['ItemHeigthTUin__c', 'ItemHeightSKUin__c']);

    return Scaffold(
      appBar: null,
      body: SafeArea(
        top: true,
        bottom: false,
        child: ListView(
          children: [
            ContainerHeader(
              titleHeader: 'Product',
              title: displayName,
              descriptionHeader: '',
              description: '',
              textIcon: Icons.category_outlined,
              showImage: false,
            ),

            // Identifiers — headerless, matches catalog bulk variant.
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

            // Item Packaging — packaging weight unit/value, packaging type.
            ContainerActionWidget(
              title: '',
              actionText: '',
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  HeaderInfoIconValue(
                    header: 'Packaging Weight Unit',
                    value: _resolvedWeightUnit().isNotEmpty
                        ? _resolvedWeightUnit()
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
                    value:
                        packType.isNotEmpty ? _titleCase(packType) : 'Not set',
                    icon: Icons.inventory_2_outlined,
                  ),
                ],
              ),
            ),

            // Packaging Dimensions — unit + L/W/H.
            ContainerActionWidget(
              title: '',
              actionText: '',
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  HeaderInfoIconValue(
                    header: 'Packaging Dimensions Unit',
                    value: _resolvedDimensionsUnit().isNotEmpty
                        ? _resolvedDimensionsUnit()
                        : 'Not set',
                    icon: Icons.straighten,
                  ),
                  const SizedBox(height: 12),
                  HeaderInfoIconValue(
                    header: 'Length',
                    value: length is num
                        ? length.toStringAsFixed(2)
                        : (_s(length) ?? 'Not set'),
                    icon: Icons.height,
                  ),
                  const SizedBox(height: 12),
                  HeaderInfoIconValue(
                    header: 'Width',
                    value: width is num
                        ? width.toStringAsFixed(2)
                        : (_s(width) ?? 'Not set'),
                    icon: Icons.swap_horiz,
                  ),
                  const SizedBox(height: 12),
                  HeaderInfoIconValue(
                    header: 'Height',
                    value: height is num
                        ? height.toStringAsFixed(2)
                        : (_s(height) ?? 'Not set'),
                    icon: Icons.vertical_align_top,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 80),
          ],
        ),
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DetailsAppBar(title: displayName),
          const HomeNavBarAdapter(),
        ],
      ),
    );
  }
}
