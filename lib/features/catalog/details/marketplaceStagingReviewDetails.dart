import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:kleenops_admin/l10n/app_localizations.dart';
import 'package:kleenops_admin/services/catalog_firebase_service.dart';
import 'package:shared_widgets/containers/container_action.dart';
import 'package:shared_widgets/containers/container_header.dart';
import 'package:shared_widgets/viewers/file_carousel_viewer.dart';
import 'package:shared_widgets/tabs/standard_tab.dart';
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
  bool _processing = false;

  String _categoryName = '';
  String _scalarName = '';
  String _scalarUnitName = '';
  String _brandName = '';

  @override
  void initState() {
    super.initState();
    _data = Map<String, dynamic>.from(widget.initialData);
    _tabController = TabController(length: 2, vsync: this);
    _loadLatest();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return value.map((key, dynamic v) => MapEntry(key.toString(), v));
    return <String, dynamic>{};
  }

  List<dynamic> _asList(dynamic value) => value is List ? value : const [];

  String? _str(dynamic value) {
    if (value == null) return null;
    final s = value.toString().trim();
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
    final objectData = _asMap(_data['objectData']);
    final normalized = _asMap(_data['normalizedData']);
    final detailData = _asMap(_data['detailData']);
    final solenisData = _asMap(detailData['solenisData']);

    // Category
    final catRef = objectData['objectCategoryId'];
    if (catRef is DocumentReference) {
      try {
        final snap = await catRef.get();
        if (snap.exists) _categoryName = ((snap.data() as Map?)?['name'] ?? '').toString();
      } catch (_) {}
    }

    // Scalar
    final scalarRef = objectData['scalarId'];
    if (scalarRef is DocumentReference) {
      try {
        final snap = await scalarRef.get();
        if (snap.exists) _scalarName = ((snap.data() as Map?)?['name'] ?? '').toString();
      } catch (_) {}
    }

    // Scalar Unit
    final unitRef = objectData['scalarUnitId'];
    if (unitRef is DocumentReference) {
      try {
        final snap = await unitRef.get();
        if (snap.exists) _scalarUnitName = ((snap.data() as Map?)?['name'] ?? '').toString();
      } catch (_) {}
    }

    // Brand
    _brandName = _str(objectData['brand']) ?? _str(normalized['brandName']) ?? _str(solenisData['brand']) ?? '';
  }

  Future<void> _approve() async {
    final loc = AppLocalizations.of(context)!;
    if (_processing) return;
    setState(() => _processing = true);
    try {
      final callable = FirebaseFunctions.instanceFor(region: 'us-central1')
          .httpsCallable('approveStagedProduct');
      await callable.call({'stagedId': widget.docId});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.marketplaceProductApprovedSuccessfully)),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.marketplaceApprovalFailed(e.toString()))),
      );
      setState(() => _processing = false);
    }
  }

  Future<void> _reject() async {
    final loc = AppLocalizations.of(context)!;
    if (_processing) return;
    final reasonCtl = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(loc.marketplaceRejectProductTitle),
        content: TextField(controller: reasonCtl, autofocus: true, maxLines: 3,
          decoration: InputDecoration(hintText: loc.marketplaceEnterReasonOptional, border: const OutlineInputBorder())),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(loc.commonCancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, reasonCtl.text.trim().isEmpty ? loc.marketplaceRejectedByReviewer : reasonCtl.text.trim()), child: Text(loc.marketplaceReject)),
        ],
      ),
    );
    reasonCtl.dispose();
    if (reason == null) return;
    setState(() => _processing = true);
    try {
      final callable = FirebaseFunctions.instanceFor(region: 'us-central1')
          .httpsCallable('rejectStagedProduct');
      await callable.call({'stagedId': widget.docId, 'reason': reason});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(loc.marketplaceProductRejected)));
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(loc.marketplaceRejectFailed(e.toString()))));
      setState(() => _processing = false);
    }
  }

  Future<void> _confirmClear(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear Review Item'),
        content: const Text('Are you sure you want to remove this item from review? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _processing = true);
    try {
      await CatalogFirebaseService.instance.firestore
          .collection('stagedProduct').doc(widget.docId).delete();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Review item cleared')));
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
      setState(() => _processing = false);
    }
  }

  Future<void> _confirmTransfer(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Transfer to Catalog'),
        content: const Text('Are you sure you want to transfer this product to the object catalog? The parent product and any packaging variants will be created.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.amber[700]),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Transfer'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _processing = true);
    try {
      final callable = FirebaseFunctions.instanceFor(region: 'us-central1')
          .httpsCallable('approveStagedProduct');
      await callable.call({'stagedId': widget.docId});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Product transferred to catalog')));
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Transfer failed: $e')));
      setState(() => _processing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final objectData = _asMap(_data['objectData']);
    final normalized = _asMap(_data['normalizedData']);
    final rawData = _asMap(_data['rawData']);
    final detailData = _asMap(_data['detailData']);
    final packagingData = _asMap(_data['packagingData']);

    final name = _str(objectData['name']) ?? _str(normalized['name']) ?? _str(rawData['name']) ?? 'Unnamed';
    final description = _str(objectData['description']) ?? _str(normalized['description']) ?? '';
    final productCode = _str(objectData['objectProductCode']) ?? _str(objectData['productNumber']) ?? '';
    final upc = _str(objectData['upc']) ?? '';
    final skuConfig = _str(objectData['skuConfig']) ?? '';
    final unitQty = objectData['scalarUnitQuantity'];
    final caseQty = objectData['caseQuantity'];
    final isMultiPack = packagingData.isNotEmpty;
    final packQuantity = packagingData['packQuantity'];
    final color = _str(objectData['color']) ?? '';
    final scent = _str(objectData['scent']) ?? '';
    final containerType = _str(objectData['containerType']) ?? '';
    final productLine = _str(objectData['productLine']) ?? '';
    final canonicalUrl = _str(objectData['canonicalUrl']) ?? '';

    // Images
    final storageImages = _asList(detailData['storageImages']);
    final mediaItems = <FileCarouselItem>[];
    for (final img in storageImages) {
      final m = _asMap(img);
      final url = _str(m['downloadUrl']) ?? '';
      if (url.isNotEmpty) mediaItems.add(FileCarouselItem.image(imageUrl: url));
    }
    if (mediaItems.isEmpty) {
      for (final link in _asList(detailData['imageLinks'])) {
        final m = _asMap(link);
        final url = _str(m['href']) ?? _str(m['url']) ?? '';
        if (url.isNotEmpty) mediaItems.add(FileCarouselItem.image(imageUrl: url));
      }
    }

    // Documents
    final storageDocs = _asList(detailData['storageDocuments']);
    final sdsLinks = _asList(detailData['sdsLinks']);
    final productSheetLinks = _asList(detailData['productSheetLinks']);

    // Is consumable?
    final isConsumable = _categoryName.toLowerCase().contains('consumable');

    return Scaffold(
      appBar: AppBar(title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis)),
      body: Column(
        children: [
          StandardTabBar(
            controller: _tabController,
            isScrollable: false,
            tabs: const [
              Tab(text: 'Details'),
              Tab(text: 'Elements'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // --- Details Tab ---
                ListView(
                  children: [
                    ContainerHeader(
                      mediaItems: mediaItems.isNotEmpty ? mediaItems : null,
                      image: mediaItems.isNotEmpty ? mediaItems.first.url : null,
                      showImage: mediaItems.isNotEmpty,
                      titleHeader: 'Product',
                      title: name,
                      descriptionHeader: loc.commonDescription,
                      description: description.isNotEmpty ? description : 'No description',
                      textIcon: Icons.category_outlined,
                      descriptionIcon: Icons.info_outlined,
                    ),

                    // Product Details
                    ContainerActionWidget(
                      title: loc.commonDetails,
                      actionText: '',
                      content: Column(children: [
                        if (productCode.isNotEmpty) _fieldRow(Icons.confirmation_number_outlined, 'Product Code', productCode),
                        _fieldRow(Icons.qr_code, 'UPC', upc.isNotEmpty ? upc : 'Not set'),
                        if (_brandName.isNotEmpty) _fieldRow(Icons.branding_watermark_outlined, 'Brand', _brandName),
                      ]),
                    ),

                    // Specifications
                    ContainerActionWidget(
                      title: 'Specifications',
                      actionText: '',
                      content: Column(children: [
                        _fieldRow(Icons.straighten, 'Usage', _scalarName.isNotEmpty ? _scalarName : 'Not set'),
                        _fieldRow(Icons.science_outlined, 'Unit', _scalarUnitName.isNotEmpty ? _scalarUnitName : 'Not set'),
                        if (unitQty != null) _fieldRow(Icons.format_list_numbered, 'Unit Value', '$unitQty'),
                        if (skuConfig.isNotEmpty) _fieldRow(Icons.inventory_2_outlined, 'SKU Config', skuConfig),
                      ]),
                    ),

                    // Category
                    ContainerActionWidget(
                      title: 'Category',
                      actionText: '',
                      content: _fieldRow(Icons.category, 'Category', _categoryName.isNotEmpty ? _categoryName : 'Not set'),
                    ),

                    // Packaging (if multi-pack)
                    if (isMultiPack)
                      ContainerActionWidget(
                        title: 'Packaging',
                        actionText: '',
                        content: Column(children: [
                          _fieldRow(Icons.inventory, 'Pack Quantity', '$packQuantity'),
                          if (caseQty != null) _fieldRow(Icons.calculate_outlined, 'Case Quantity', '$caseQty'),
                        ]),
                      ),

                    // Attributes
                    if (color.isNotEmpty || scent.isNotEmpty || containerType.isNotEmpty || productLine.isNotEmpty)
                      ContainerActionWidget(
                        title: 'Attributes',
                        actionText: '',
                        content: Column(children: [
                          if (productLine.isNotEmpty) _fieldRow(Icons.linear_scale, 'Product Line', productLine),
                          if (color.isNotEmpty) _fieldRow(Icons.palette_outlined, 'Color', color),
                          if (scent.isNotEmpty) _fieldRow(Icons.air, 'Scent', scent),
                          if (containerType.isNotEmpty) _fieldRow(Icons.takeout_dining_outlined, 'Container', containerType),
                        ]),
                      ),

                    // Unique Identifiers (non-consumables only)
                    if (!isConsumable) ...[
                      // placeholder — these would come from inventory level
                    ],

                    // Resources (documents)
                    ContainerActionWidget(
                      title: 'Resources (${storageDocs.length + sdsLinks.length + productSheetLinks.length})',
                      actionText: '',
                      content: _buildDocumentsList(storageDocs, sdsLinks, productSheetLinks),
                    ),

                    // Images list
                    ContainerActionWidget(
                      title: 'Images (${mediaItems.length})',
                      actionText: '',
                      content: mediaItems.isEmpty
                          ? const Text('No images')
                          : Column(children: [
                              for (int i = 0; i < mediaItems.length; i++)
                                ListTile(
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                  leading: ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: Image.network(mediaItems[i].url, width: 48, height: 48, fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, size: 48)),
                                  ),
                                  title: Text(i == 0 ? 'Primary Image' : 'Image ${i + 1}',
                                    style: TextStyle(fontWeight: i == 0 ? FontWeight.bold : FontWeight.normal)),
                                  subtitle: Text(
                                    storageImages.length > i ? 'In Storage' : 'Vendor URL',
                                    style: TextStyle(fontSize: 11, color: storageImages.length > i ? Colors.green : Colors.orange),
                                  ),
                                ),
                            ]),
                    ),

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

                    const SizedBox(height: 80),
                  ],
                ),

                // --- Elements Tab (placeholder) ---
                const Center(child: Text('Parts, Materials, Inventory, and Processes will appear here after approval.')),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(color: Colors.grey.withValues(alpha: 0.3), offset: const Offset(0, -2), blurRadius: 4),
                ],
              ),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Row(children: [
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.grey[300], foregroundColor: Colors.black),
                    onPressed: _processing ? null : () => _confirmClear(context),
                    child: const Text('Clear'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.amber[700], foregroundColor: Colors.white),
                    onPressed: _processing ? null : () => _confirmTransfer(context),
                    child: Text(_processing ? 'Working...' : 'Transfer'),
                  ),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fieldRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 12),
          SizedBox(width: 120, child: Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 13))),
          Expanded(child: Text(
            value.isEmpty || value == 'Not set' ? 'Not set' : value,
            style: TextStyle(fontWeight: FontWeight.w500, color: value == 'Not set' ? Colors.red[300] : null),
          )),
        ],
      ),
    );
  }

  Widget _buildDocumentsList(List<dynamic> storageDocs, List<dynamic> sdsLinks, List<dynamic> productSheetLinks) {
    final docs = storageDocs.isNotEmpty ? storageDocs : [...sdsLinks, ...productSheetLinks];
    if (docs.isEmpty) return const Text('No documents');
    return Column(children: [
      for (final doc in docs)
        Builder(builder: (context) {
          final m = _asMap(doc);
          final url = _str(m['downloadUrl']) ?? _str(m['href']) ?? _str(m['url']) ?? '';
          final name = _str(m['name']) ?? _str(m['text']) ?? _str(m['fileName']) ?? 'Document';
          final type = _str(m['type']) ?? '';
          final isFromStorage = _str(m['storagePath'])?.isNotEmpty == true;
          return ListTile(
            dense: true, contentPadding: EdgeInsets.zero,
            leading: Icon(
              type.toUpperCase() == 'SDS' ? Icons.warning_amber_outlined : Icons.description_outlined,
              color: type.toUpperCase() == 'SDS' ? Colors.orange : Colors.blue,
            ),
            title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Row(children: [
              if (type.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: type.toUpperCase() == 'SDS' ? Colors.orange.withValues(alpha: 0.15) : Colors.blue.withValues(alpha: 0.15),
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
        }),
    ]);
  }
}
