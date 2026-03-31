import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:kleenops_admin/l10n/app_localizations.dart';
import 'package:kleenops_admin/services/catalog_firebase_service.dart';
import 'package:shared_widgets/containers/container_action.dart';
import 'package:shared_widgets/containers/container_header.dart';
import 'package:shared_widgets/viewers/file_carousel_viewer.dart';
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
    extends State<MarketplaceStagingReviewDetailsScreen> {
  late Map<String, dynamic> _data;
  bool _loading = true;
  bool _processing = false;

  // Resolved reference names (loaded async)
  String _categoryName = '';
  String _scalarName = '';
  String _scalarUnitName = '';
  String _brandName = '';

  @override
  void initState() {
    super.initState();
    _data = Map<String, dynamic>.from(widget.initialData);
    _loadLatest();
  }

  Future<void> _loadLatest() async {
    try {
      final snap = await CatalogFirebaseService.instance.firestore
          .collection('stagedProduct')
          .doc(widget.docId)
          .get();
      if (!mounted) return;
      if (snap.exists) {
        _data = snap.data() ?? _data;
      }
    } catch (_) {}

    await _resolveReferences();
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _resolveReferences() async {
    final detailData = _asMap(_data['detailData']);
    final normalized = _asMap(_data['normalizedData']);
    final solenisData = _asMap(detailData['solenisData']);
    final allSpecs = _asMap(detailData['allSpecs']);

    // Resolve brand
    final brandId = normalized['brandId'];
    if (brandId is DocumentReference) {
      try {
        final snap = await brandId.get();
        if (snap.exists) {
          final d = snap.data() as Map<String, dynamic>?;
          _brandName = (d?['name'] ?? d?['brand'] ?? '').toString();
        }
      } catch (_) {}
    }
    if (_brandName.isEmpty) {
      _brandName = _str(normalized['brandName']) ?? _str(solenisData['brand']) ?? '';
    }

    // Try to determine what category/scalar would be assigned
    // by looking at the skuConfig and product characteristics
    final skuConfig = _str(allSpecs['skuConfig']) ?? _str(solenisData['skuConfig']) ?? '';
    final scalarType = _inferScalarType(skuConfig, allSpecs);
    _scalarName = scalarType ?? '';
    _scalarUnitName = _inferUnitName(skuConfig);
    _categoryName = _inferCategoryName(scalarType, solenisData, allSpecs, normalized);
  }

  String? _inferScalarType(String skuConfig, Map<String, dynamic> specs) {
    final lower = skuConfig.toLowerCase();
    if (lower.contains('oz') || lower.contains('gal') || lower.contains('qt') || lower.contains('l')) return 'Volume';
    if (lower.contains('lb') || lower.contains('kg') || lower.contains('g')) return 'Weight';
    if (lower.contains('ct') || lower.contains('pk') || lower.contains('ea')) return 'Count';
    if (lower.contains('ft') || lower.contains('in') || lower.contains('m')) return 'Length';
    return null;
  }

  String _inferUnitName(String skuConfig) {
    final match = RegExp(r'\d+\s*[x×/]\s*\d+(?:\.\d+)?\s*(.+)', caseSensitive: false).firstMatch(skuConfig);
    if (match != null) return match.group(1)?.trim() ?? '';
    final single = RegExp(r'\d+(?:\.\d+)?\s*(.+)', caseSensitive: false).firstMatch(skuConfig);
    if (single != null) return single.group(1)?.trim() ?? '';
    return '';
  }

  String _inferCategoryName(String? scalarType, Map<String, dynamic> solenis, Map<String, dynamic> specs, Map<String, dynamic> norm) {
    if (scalarType == 'Volume') return 'Consumables - Liquid';
    if (scalarType == 'Count') return 'Consumables - Non Liquid';
    if (scalarType == 'Weight') return 'Consumables - Liquid';
    final prodLine = (_str(solenis['productLine']) ?? '').toLowerCase();
    if (prodLine.contains('odor') || prodLine.contains('clean') || prodLine.contains('disinfect')) return 'Consumables - Liquid';
    return '';
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

    final reasonController = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(loc.marketplaceRejectProductTitle),
        content: TextField(
          controller: reasonController,
          autofocus: true,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: loc.marketplaceEnterReasonOptional,
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(loc.commonCancel)),
          FilledButton(
            onPressed: () {
              final text = reasonController.text.trim();
              Navigator.pop(ctx, text.isEmpty ? loc.marketplaceRejectedByReviewer : text);
            },
            child: Text(loc.marketplaceReject),
          ),
        ],
      ),
    );
    reasonController.dispose();
    if (reason == null) return;

    setState(() => _processing = true);
    try {
      final callable = FirebaseFunctions.instanceFor(region: 'us-central1')
          .httpsCallable('rejectStagedProduct');
      await callable.call({'stagedId': widget.docId, 'reason': reason});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.marketplaceProductRejected)),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.marketplaceRejectFailed(e.toString()))),
      );
      setState(() => _processing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final rawData = _asMap(_data['rawData']);
    final detailData = _asMap(_data['detailData']);
    final objectData = _asMap(_data['objectData']);
    final packagingData = _asMap(_data['packagingData']);
    final normalized = _asMap(_data['normalizedData']);
    final allSpecs = _asMap(detailData['allSpecs']);
    final solenisData = _asMap(detailData['solenisData']);

    // Use pre-resolved objectData if available, fallback to normalized
    final parentName = _str(objectData['name']) ?? _str(normalized['name']) ?? _str(rawData['name']) ?? 'Unnamed';
    final description = _str(objectData['description']) ?? _str(normalized['description']) ?? '';
    final productNumber = _str(objectData['productNumber']) ?? _str(normalized['productNumber']) ?? '';
    final upc = _str(objectData['upc']) ?? _str(normalized['upc']) ?? '';
    final packageUpc = _str(packagingData['upc']) ?? _str(allSpecs['packageUpc']) ?? '';
    final skuConfig = _str(objectData['skuConfig']) ?? _str(allSpecs['skuConfig']) ?? '';
    final materialNumber = _str(objectData['materialNumber']) ?? '';
    final unitValue = (objectData['scalarUnitQuantity'] ?? '').toString();
    final isMultiPack = packagingData.isNotEmpty;
    final packQuantity = (packagingData['packQuantity'] ?? 0) as num;

    // --- Images from Storage ---
    final storageImages = _asList(detailData['storageImages']);
    final mediaItems = <FileCarouselItem>[];
    for (final img in storageImages) {
      final imgMap = _asMap(img);
      final url = _str(imgMap['downloadUrl']) ?? '';
      if (url.isNotEmpty) {
        mediaItems.add(FileCarouselItem.image(imageUrl: url));
      }
    }
    // Fallback to vendor image URLs if no storage images
    if (mediaItems.isEmpty) {
      final imageLinks = _asList(detailData['imageLinks']);
      for (final link in imageLinks) {
        final linkMap = _asMap(link);
        final url = _str(linkMap['href']) ?? _str(linkMap['url']) ?? '';
        if (url.isNotEmpty) {
          mediaItems.add(FileCarouselItem.image(imageUrl: url));
        }
      }
    }

    // --- Documents ---
    final storageDocs = _asList(detailData['storageDocuments']);
    final sdsLinks = _asList(detailData['sdsLinks']);
    final productSheetLinks = _asList(detailData['productSheetLinks']);

    // --- Additional product attributes ---
    final color = _str(allSpecs['color']) ?? '';
    final scent = _str(allSpecs['scent']) ?? _str(allSpecs['fragrance']) ?? '';
    final containerType = _str(allSpecs['containerType']) ?? '';
    final productLine = _str(solenisData['productLine']) ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text('Staged Product Review')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                // --- Header with images ---
                ContainerHeader(
                  mediaItems: mediaItems.isNotEmpty ? mediaItems : null,
                  image: mediaItems.isNotEmpty ? mediaItems.first.url : null,
                  showImage: mediaItems.isNotEmpty,
                  titleHeader: 'Product Name (Individual Unit)',
                  title: parentName,
                  descriptionHeader: loc.commonDescription,
                  description: description.isNotEmpty ? description : 'No description',
                  textIcon: Icons.category_outlined,
                  descriptionIcon: Icons.info_outlined,
                ),

                // --- Core identifiers (matches object collection fields) ---
                ContainerActionWidget(
                  title: 'Product Identifiers',
                  actionText: '',
                  content: Column(
                    children: [
                      _fieldRow(Icons.qr_code, 'UPC (Individual)', upc),
                      if (packageUpc.isNotEmpty) _fieldRow(Icons.qr_code_2, 'UPC (Package)', packageUpc),
                      _fieldRow(Icons.confirmation_number_outlined, 'Product Code', productNumber),
                      if (materialNumber.isNotEmpty) _fieldRow(Icons.tag, 'Material Number', materialNumber),
                      _fieldRow(Icons.branding_watermark_outlined, 'Brand', _brandName.isNotEmpty ? _brandName : 'Not set'),
                      _fieldRow(Icons.category_outlined, 'Category', _categoryName.isNotEmpty ? _categoryName : 'Not set'),
                      if (productLine.isNotEmpty) _fieldRow(Icons.linear_scale, 'Product Line', productLine),
                    ],
                  ),
                ),

                // --- Scalar / Measurement (critical for process cost) ---
                ContainerActionWidget(
                  title: 'Measurement & Scalar',
                  actionText: '',
                  content: Column(
                    children: [
                      _fieldRow(Icons.straighten, 'Scalar Type', _scalarName.isNotEmpty ? _scalarName : 'Not set'),
                      _fieldRow(Icons.science_outlined, 'Unit', _scalarUnitName.isNotEmpty ? _scalarUnitName : 'Not set'),
                      _fieldRow(Icons.format_list_numbered, 'Unit Quantity', unitValue.isNotEmpty ? unitValue : 'Not set'),
                      _fieldRow(Icons.inventory_2_outlined, 'SKU Config', skuConfig.isNotEmpty ? skuConfig : 'N/A'),
                    ],
                  ),
                ),

                // --- Packaging (if multi-pack) ---
                if (isMultiPack)
                  ContainerActionWidget(
                    title: 'Packaging',
                    actionText: '',
                    content: Column(
                      children: [
                        _fieldRow(Icons.inventory, 'Packaging Type', 'Case'),
                        _fieldRow(Icons.looks_one, 'Pack Quantity', '$packQuantity'),
                        _fieldRow(Icons.straighten, 'Per Unit', '$unitValue ${_scalarUnitName.isNotEmpty ? _scalarUnitName : ''}'),
                        _fieldRow(Icons.calculate_outlined, 'Case Quantity', '$packQuantity (for process cost calculation)'),
                        if (packageUpc.isNotEmpty) _fieldRow(Icons.qr_code_2, 'Package UPC', packageUpc),
                      ],
                    ),
                  ),

                // --- Product attributes ---
                if (color.isNotEmpty || scent.isNotEmpty || containerType.isNotEmpty)
                  ContainerActionWidget(
                    title: 'Product Attributes',
                    actionText: '',
                    content: Column(
                      children: [
                        if (color.isNotEmpty) _fieldRow(Icons.palette_outlined, 'Color', color),
                        if (scent.isNotEmpty) _fieldRow(Icons.air, 'Scent / Fragrance', scent),
                        if (containerType.isNotEmpty) _fieldRow(Icons.takeout_dining_outlined, 'Container Type', containerType),
                      ],
                    ),
                  ),

                // --- Documents (SDS, TDS from Storage) ---
                ContainerActionWidget(
                  title: 'Documents',
                  actionText: '',
                  content: _buildDocumentsList(storageDocs, sdsLinks, productSheetLinks),
                ),

                // --- Images list ---
                ContainerActionWidget(
                  title: 'Images (${mediaItems.length})',
                  actionText: '',
                  content: mediaItems.isEmpty
                      ? const Text('No images')
                      : Column(
                          children: [
                            for (int i = 0; i < mediaItems.length; i++)
                              ListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                leading: ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: Image.network(
                                    mediaItems[i].url,
                                    width: 48,
                                    height: 48,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, size: 48),
                                  ),
                                ),
                                title: Text(
                                  i == 0 ? 'Primary Image' : 'Image ${i + 1}',
                                  style: TextStyle(fontWeight: i == 0 ? FontWeight.bold : FontWeight.normal),
                                ),
                                subtitle: Text(
                                  storageImages.length > i
                                      ? (_str(_asMap(storageImages[i])['fileName']) ?? 'From Storage')
                                      : 'From vendor',
                                  style: TextStyle(
                                    color: storageImages.length > i ? Colors.green : Colors.orange,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                          ],
                        ),
                ),

                const SizedBox(height: 80),
              ],
            ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _processing ? null : _reject,
                  icon: const Icon(Icons.cancel_outlined),
                  label: Text(loc.marketplaceReject),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _processing ? null : _approve,
                  icon: const Icon(Icons.check_circle_outline),
                  label: Text(_processing ? loc.marketplaceWorking : loc.marketplaceApprove),
                ),
              ),
            ],
          ),
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
          SizedBox(
            width: 140,
            child: Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? 'Not set' : value,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: value.isEmpty || value == 'Not set' ? Colors.red[300] : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentsList(List<dynamic> storageDocs, List<dynamic> sdsLinks, List<dynamic> productSheetLinks) {
    // Prefer storage docs, fallback to vendor URLs
    final docs = storageDocs.isNotEmpty ? storageDocs : [...sdsLinks, ...productSheetLinks];
    if (docs.isEmpty) return const Text('No documents');

    return Column(
      children: [
        for (final doc in docs) Builder(builder: (context) {
          final docMap = _asMap(doc);
          final url = _str(docMap['downloadUrl']) ?? _str(docMap['href']) ?? _str(docMap['url']) ?? '';
          final name = _str(docMap['name']) ?? _str(docMap['text']) ?? _str(docMap['fileName']) ?? 'Document';
          final type = _str(docMap['type']) ?? _str(docMap['docType']) ?? '';
          final isFromStorage = _str(docMap['storagePath'])?.isNotEmpty == true;

          return ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              type.toUpperCase() == 'SDS' ? Icons.warning_amber_outlined : Icons.description_outlined,
              color: type.toUpperCase() == 'SDS' ? Colors.orange : Colors.blue,
            ),
            title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Row(
              children: [
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
                Icon(
                  isFromStorage ? Icons.cloud_done : Icons.cloud_off,
                  size: 14,
                  color: isFromStorage ? Colors.green : Colors.orange,
                ),
                const SizedBox(width: 4),
                Text(isFromStorage ? 'In Storage' : 'Vendor URL', style: TextStyle(fontSize: 11, color: isFromStorage ? Colors.green : Colors.orange)),
              ],
            ),
            trailing: url.isNotEmpty ? IconButton(
              icon: const Icon(Icons.open_in_new, size: 18),
              onPressed: () async {
                final uri = Uri.tryParse(url);
                if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
              },
            ) : null,
          );
        }),
      ],
    );
  }

  // --- Helpers ---
  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return value.map((key, dynamic v) => MapEntry(key.toString(), v));
    return <String, dynamic>{};
  }

  List<dynamic> _asList(dynamic value) {
    if (value is List) return value;
    return const [];
  }

  String? _str(dynamic value) {
    if (value == null) return null;
    final s = value.toString().trim();
    return s.isEmpty ? null : s;
  }
}
