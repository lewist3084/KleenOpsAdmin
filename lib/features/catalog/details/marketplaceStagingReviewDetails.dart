import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:kleenops_admin/l10n/app_localizations.dart';
import 'package:kleenops_admin/services/catalog_firebase_service.dart';
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
  String _scalarName = '';
  String _scalarUnitName = '';
  String _brandName = '';

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
    final dd = _m(_data['detailData']);
    final sd = _m(dd['solenisData']);

    final catRef = od['objectCategoryId'];
    if (catRef is DocumentReference) {
      try { final s = await catRef.get(); if (s.exists) _categoryName = ((s.data() as Map?)?['name'] ?? '').toString(); } catch (_) {}
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
    final description = _s(od['description']) ?? _s(nd['description']) ?? '';
    final productCode = _s(od['objectProductCode']) ?? _s(od['productNumber']) ?? '';
    final upc = _s(od['upc']) ?? '';
    final skuConfig = _s(od['skuConfig']) ?? '';
    final unitQty = od['scalarUnitQuantity'];
    final caseQty = od['caseQuantity'];
    final isMultiPack = pd.isNotEmpty;
    final packQty = pd['packQuantity'];
    final color = _s(od['color']) ?? '';
    final scent = _s(od['scent']) ?? '';
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
        tabContent = _buildDetailsTabInline(loc, name, productCode, upc, skuConfig, unitQty, caseQty,
            isMultiPack, packQty, pd, color, scent, containerType, productLine,
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
    AppLocalizations loc, String name, String productCode, String upc,
    String skuConfig, dynamic unitQty, dynamic caseQty,
    bool isMultiPack, dynamic packQty, Map<String, dynamic> packagingData,
    String color, String scent, String containerType, String productLine,
    bool isConsumable, List<dynamic> allDocs, String canonicalUrl, List<dynamic> storageImages,
  ) {
    return Column(
      children: [
        // 1. Product Details
        ContainerActionWidget(
          title: loc.commonDetails,
          actionText: '',
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (productCode.isNotEmpty) ...[
                HeaderInfoIconValue(header: 'Product Code', value: productCode, icon: Icons.confirmation_number_outlined),
                const SizedBox(height: 12),
              ],
              HeaderInfoIconValue(header: 'UPC', value: upc.isNotEmpty ? upc : 'Not set', icon: Icons.qr_code),
              if (_brandName.isNotEmpty) ...[
                const SizedBox(height: 12),
                HeaderInfoIconValue(header: 'Brand', value: _brandName, icon: Icons.branding_watermark_outlined),
              ],
            ],
          ),
        ),

        // 2. Specifications
        ContainerActionWidget(
          title: 'Specifications',
          actionText: '',
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              HeaderInfoIconValue(header: 'Usage', value: _scalarName.isNotEmpty ? _scalarName : 'Not set', icon: Icons.straighten),
              const SizedBox(height: 12),
              HeaderInfoIconValue(header: 'Unit', value: _scalarUnitName.isNotEmpty ? _scalarUnitName : 'Not set', icon: Icons.science_outlined),
              if (unitQty != null) ...[
                const SizedBox(height: 12),
                HeaderInfoIconValue(header: 'Unit Value', value: '$unitQty', icon: Icons.format_list_numbered),
              ],
              if (skuConfig.isNotEmpty) ...[
                const SizedBox(height: 12),
                HeaderInfoIconValue(header: 'SKU Config', value: skuConfig, icon: Icons.inventory_2_outlined),
              ],
            ],
          ),
        ),

        // 3. Category
        ContainerActionWidget(
          title: 'Category',
          actionText: '',
          content: HeaderInfoIconValue(
            header: 'Category',
            value: _categoryName.isNotEmpty ? _categoryName : 'Not set',
            icon: Icons.category,
          ),
        ),

        // 4. Packaging (if multi-pack) — interactive preview tile
        if (isMultiPack)
          ContainerActionWidget(
            title: 'Packaging (1)',
            actionText: '',
            content: _buildPackagingPreviewTile(context, packagingData, name, caseQty),
          ),

        // 5. Attributes
        if (color.isNotEmpty || scent.isNotEmpty || containerType.isNotEmpty || productLine.isNotEmpty)
          ContainerActionWidget(
            title: 'Attributes',
            actionText: '',
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (productLine.isNotEmpty) HeaderInfoIconValue(header: 'Product Line', value: productLine, icon: Icons.linear_scale),
                if (color.isNotEmpty) ...[if (productLine.isNotEmpty) const SizedBox(height: 12), HeaderInfoIconValue(header: 'Color', value: color, icon: Icons.palette_outlined)],
                if (scent.isNotEmpty) ...[const SizedBox(height: 12), HeaderInfoIconValue(header: 'Scent', value: scent, icon: Icons.air)],
                if (containerType.isNotEmpty) ...[const SizedBox(height: 12), HeaderInfoIconValue(header: 'Container', value: containerType, icon: Icons.takeout_dining_outlined)],
              ],
            ),
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
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  HeaderInfoIconValue(header: 'Packaging Type', value: _formatKey(packType), icon: Icons.style_outlined),
                  const SizedBox(height: 12),
                  HeaderInfoIconValue(header: 'Pack Quantity', value: '${packQty ?? '—'}', icon: Icons.inventory),
                  if (caseQty != null) ...[
                    const SizedBox(height: 12),
                    HeaderInfoIconValue(header: 'Case Quantity', value: '$caseQty', icon: Icons.calculate_outlined),
                  ],
                ],
              ),
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
