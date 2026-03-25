import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:kleenops_admin/l10n/app_localizations.dart';
import 'package:kleenops_admin/services/catalog_firebase_service.dart';
import 'package:shared_widgets/containers/container_action.dart';
import 'package:shared_widgets/containers/container_header.dart';
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
        setState(() {
          _data = snap.data() ?? _data;
          _loading = false;
        });
      } else {
        setState(() => _loading = false);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
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
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(loc.commonCancel),
          ),
          FilledButton(
            onPressed: () {
              final text = reasonController.text.trim();
              Navigator.pop(
                ctx,
                text.isEmpty ? loc.marketplaceRejectedByReviewer : text,
              );
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

  Future<void> _openExternalUrl(String url) async {
    final uri = Uri.tryParse(url.trim());
    if (uri == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid link')),
      );
      return;
    }

    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open link')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final normalized = _asMap(_data['normalizedData']);
    final rawData = _asMap(_data['rawData']);
    final detailData = _asMap(_data['detailData']);

    final name = _firstNonEmptyString(<dynamic>[
          normalized['name'],
          rawData['name'],
        ]) ??
        loc.marketplaceUnnamedProduct;
    final description = _firstNonEmptyString(<dynamic>[
      normalized['description'],
      normalized['Description'],
      rawData['description'],
      rawData['Description'],
      detailData['description'],
      detailData['Description'],
      _data['description'],
      _data['Description'],
    ]);
    final productNumber = _firstNonEmptyString(<dynamic>[
          normalized['productNumber'],
          rawData['productNumber'],
        ]) ??
        '';
    final brandName = _firstNonEmptyString(<dynamic>[
          normalized['brandName'],
          rawData['brandName'],
        ]) ??
        '';
    final vendorName = _firstNonEmptyString(<dynamic>[
          normalized['vendorName'],
          rawData['vendorName'],
        ]) ??
        '';

    final imageUrls = _collectImageUrls(_data);
    final headerImage = imageUrls.isNotEmpty ? imageUrls.first : '';
    final documentLinks = _collectDocumentLinks(_data, imageUrls.toSet());

    final documentUrlSet = <String>{};
    for (final link in documentLinks) {
      documentUrlSet.add(_normalizeUrl(link.url));
    }
    final imageUrlSet = <String>{};
    for (final url in imageUrls) {
      imageUrlSet.add(_normalizeUrl(url));
    }

    final additionalEntries = _buildAdditionalDataEntries(
      data: _data,
      imageUrls: imageUrlSet,
      documentUrls: documentUrlSet,
    );

    return Scaffold(
      appBar: AppBar(title: Text(loc.marketplaceStagedProductDetailsTitle)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                ContainerHeader(
                  image: headerImage,
                  images: imageUrls.isEmpty ? null : imageUrls,
                  showImage: headerImage.isNotEmpty,
                  titleHeader: loc.commonName,
                  title: name,
                  descriptionHeader: loc.commonDescription,
                  description: description ?? loc.commonNotAvailable,
                ),
                ContainerActionWidget(
                  title: loc.commonDetails,
                  actionText: '',
                  content: Column(
                    children: [
                      _detailTile(
                        icon: Icons.confirmation_number_outlined,
                        label: loc.marketplaceProductNumber,
                        value: productNumber,
                        fallback: loc.commonNotAvailable,
                      ),
                      _detailTile(
                        icon: Icons.branding_watermark_outlined,
                        label: loc.marketplaceBrand,
                        value: brandName,
                        fallback: loc.commonNotAvailable,
                      ),
                      _detailTile(
                        icon: Icons.storefront_outlined,
                        label: loc.marketplaceVendor,
                        value: vendorName,
                        fallback: loc.commonNotAvailable,
                      ),
                    ],
                  ),
                ),
                ContainerActionWidget(
                  title: 'Associated Documents',
                  actionText: '',
                  content: documentLinks.isEmpty
                      ? const Center(
                          child: Text('No associated documents found'))
                      : Column(
                          children: [
                            for (final link in documentLinks)
                              ListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(
                                    Icons.insert_drive_file_outlined),
                                title: Text(link.label),
                                subtitle: Text(
                                  link.url,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                trailing:
                                    const Icon(Icons.open_in_new, size: 18),
                                onTap: () => _openExternalUrl(link.url),
                              ),
                          ],
                        ),
                ),
                ContainerActionWidget(
                  title: 'Additional Data',
                  actionText: '',
                  content: additionalEntries.isEmpty
                      ? const Center(child: Text('No additional data found'))
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (final entry in additionalEntries)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _formatPathLabel(entry.key),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    SelectableText(entry.value),
                                  ],
                                ),
                              ),
                          ],
                        ),
                ),
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
                  label: Text(
                    _processing
                        ? loc.marketplaceWorking
                        : loc.marketplaceApprove,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailTile({
    required IconData icon,
    required String label,
    required String value,
    required String fallback,
  }) {
    final display = value.trim().isEmpty ? fallback : value.trim();
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      minLeadingWidth: 24,
      leading: Icon(icon, size: 20),
      title: Text(label),
      subtitle: Text(display),
    );
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((key, dynamic mapValue) {
        return MapEntry(key.toString(), mapValue);
      });
    }
    return <String, dynamic>{};
  }

  String? _firstNonEmptyString(List<dynamic> candidates) {
    for (final candidate in candidates) {
      final text = (candidate ?? '').toString().trim();
      if (text.isNotEmpty) return text;
    }
    return null;
  }

  List<String> _collectImageUrls(Map<String, dynamic> data) {
    final urls = <String>[];
    final seen = <String>{};

    void addUrl(String candidate) {
      final trimmed = candidate.trim();
      if (trimmed.isEmpty || !_isHttpUrl(trimmed)) return;
      if (_isLikelyPrivateImageAssetUrl(trimmed)) return;
      final normalized = _normalizeUrl(trimmed);
      if (!seen.add(normalized)) return;
      urls.add(trimmed);
    }

    void visit(dynamic node, {required bool keySuggestsImage}) {
      if (node is String) {
        if (!keySuggestsImage && !_looksLikeImageUrl(node)) return;
        addUrl(node);
        return;
      }
      if (node is Iterable) {
        for (final item in node) {
          visit(item, keySuggestsImage: keySuggestsImage);
        }
        return;
      }
      if (node is Map) {
        node.forEach((dynamic key, dynamic value) {
          final keyText = key.toString().toLowerCase();
          final suggestsImage = keySuggestsImage ||
              keyText.contains('image') ||
              keyText.contains('img') ||
              keyText.contains('photo') ||
              keyText.contains('thumbnail');
          visit(value, keySuggestsImage: suggestsImage);
        });
      }
    }

    final normalized = _asMap(data['normalizedData']);
    final rawData = _asMap(data['rawData']);
    final candidates = <dynamic>[
      data['imageUrl'],
      data['imageUrls'],
      data['images'],
      normalized['imageUrl'],
      normalized['imageUrls'],
      normalized['images'],
      rawData['imageUrl'],
      rawData['imageUrls'],
      rawData['images'],
      rawData['imageLinks'],
    ];

    for (final candidate in candidates) {
      visit(candidate, keySuggestsImage: true);
    }

    visit(data, keySuggestsImage: false);
    return urls;
  }

  List<_DocumentLink> _collectDocumentLinks(
    Map<String, dynamic> data,
    Set<String> imageUrls,
  ) {
    final links = <_DocumentLink>[];
    final seen = <String>{};

    for (final url in imageUrls) {
      seen.add(_normalizeUrl(url));
    }

    bool pathSuggestsDocument(String path) {
      final lower = path.toLowerCase();
      return lower.contains('sds') ||
          lower.contains('safety') ||
          lower.contains('document') ||
          lower.contains('download') ||
          lower.contains('sheet') ||
          lower.contains('manual') ||
          lower.contains('datasheet') ||
          lower.contains('productsheet') ||
          lower.contains('productsheetlinks');
    }

    bool looksLikeDocumentUrl(String value) {
      final lower = value.toLowerCase();
      if (RegExp(r'\.(pdf|docx?|xlsx?|pptx?|txt)(\?|#|$)').hasMatch(lower)) {
        return true;
      }
      return lower.contains('safety-data') ||
          lower.contains('document.aspx') ||
          lower.contains('taskispares') ||
          lower.contains('/download') ||
          lower.contains('/resource') ||
          lower.contains('/servlet.shepherd') ||
          lower.contains('/sfc/dist/version/download');
    }

    bool looksLikeDocumentLabel(String value) {
      final lower = value.toLowerCase();
      return lower.contains('sds') ||
          lower.contains('safety data') ||
          lower.contains('product information sheet') ||
          lower.contains('technical data') ||
          lower.contains('datasheet') ||
          lower.contains('.pdf');
    }

    bool isGenericSdsLibraryUrl(String value) {
      final uri = Uri.tryParse(value.trim());
      if (uri == null) return false;
      final host = uri.host.toLowerCase();
      final path = uri.path.toLowerCase();
      return host.contains('solenis.com') &&
          (path == '/en/resources/safety-data-sheets' ||
              path == '/en/resources/safety-data-sheets/');
    }

    void addLink(String candidate, String label) {
      final trimmed = candidate.trim();
      if (trimmed.isEmpty || !_isHttpUrl(trimmed)) return;
      if (isGenericSdsLibraryUrl(trimmed)) return;
      final normalized = _normalizeUrl(trimmed);
      if (seen.contains(normalized)) return;
      if (_looksLikeImageUrl(trimmed)) return;
      seen.add(normalized);
      links.add(_DocumentLink(label: label, url: trimmed));
    }

    void visit(
      dynamic node,
      String path, {
      required bool keySuggestsDocument,
    }) {
      if (node is String) {
        if (!_isHttpUrl(node)) return;
        if (!keySuggestsDocument) return;
        final label = _formatPathLabel(path);
        addLink(node, label.isEmpty ? 'Document Link' : label);
        return;
      }
      if (node is Iterable) {
        var index = 0;
        for (final item in node) {
          index += 1;
          visit(
            item,
            '$path[$index]',
            keySuggestsDocument: keySuggestsDocument,
          );
        }
        return;
      }
      if (node is Map) {
        final mapNode = _asMap(node);
        final structuredHref = _firstNonEmptyString(<dynamic>[
          mapNode['href'],
          mapNode['url'],
          mapNode['downloadUrl'],
          mapNode['downloadURL'],
          mapNode['link'],
        ]);
        final structuredLabel = _firstNonEmptyString(<dynamic>[
          mapNode['text'],
          mapNode['label'],
          mapNode['title'],
          mapNode['name'],
          mapNode['fileName'],
          mapNode['filename'],
        ]);
        final hasStructuredLink =
            structuredHref != null && _isHttpUrl(structuredHref);
        final shouldUseStructuredLink = hasStructuredLink &&
            (keySuggestsDocument ||
                pathSuggestsDocument(path) ||
                looksLikeDocumentUrl(structuredHref) ||
                (structuredLabel != null &&
                    looksLikeDocumentLabel(structuredLabel)));

        if (shouldUseStructuredLink) {
          final fallback = _formatPathLabel(path);
          addLink(
            structuredHref,
            (structuredLabel != null && structuredLabel.trim().isNotEmpty)
                ? structuredLabel.trim()
                : (fallback.isEmpty ? 'Document Link' : fallback),
          );
        }

        node.forEach((dynamic key, dynamic value) {
          final keyText = key.toString().toLowerCase();
          if (shouldUseStructuredLink &&
              (keyText == 'href' ||
                  keyText == 'url' ||
                  keyText == 'downloadurl' ||
                  keyText == 'link' ||
                  keyText == 'text' ||
                  keyText == 'label' ||
                  keyText == 'title' ||
                  keyText == 'name' ||
                  keyText == 'filename')) {
            return;
          }
          final suggestsDocument = keySuggestsDocument ||
              keyText.contains('source') ||
              keyText.contains('url') ||
              keyText.contains('link') ||
              keyText.contains('doc') ||
              keyText.contains('pdf') ||
              keyText.contains('sheet') ||
              keyText.contains('file') ||
              keyText.contains('manual') ||
              keyText.contains('sds');
          final childPath =
              path.isEmpty ? key.toString() : '$path.${key.toString()}';
          visit(value, childPath, keySuggestsDocument: suggestsDocument);
        });
      }
    }

    final sourceUrl = _firstNonEmptyString(<dynamic>[
      data['sourceUrl'],
      _asMap(data['rawData'])['sourceUrl'],
    ]);
    if (sourceUrl != null) {
      addLink(sourceUrl, 'Source URL');
    }

    visit(data, '', keySuggestsDocument: false);
    return links;
  }

  List<MapEntry<String, String>> _buildAdditionalDataEntries({
    required Map<String, dynamic> data,
    required Set<String> imageUrls,
    required Set<String> documentUrls,
  }) {
    final entries = <MapEntry<String, String>>[];

    bool isConsumedPath(String lowerPath) {
      const consumedExact = <String>{
        'normalizeddata.name',
        'normalizeddata.description',
        'normalizeddata.productnumber',
        'normalizeddata.brandname',
        'normalizeddata.vendorname',
        'rawdata.name',
        'rawdata.description',
        'rawdata.productnumber',
        'rawdata.brandname',
        'rawdata.vendorname',
        'normalizeddata.imageurl',
        'rawdata.imageurl',
        'imageurl',
      };
      if (consumedExact.contains(lowerPath)) return true;
      if (lowerPath.contains('images')) return true;
      if (lowerPath.contains('imagelinks')) return true;
      if (lowerPath.contains('imageurls')) return true;
      if (lowerPath.contains('sourceurl')) return true;
      if (lowerPath.contains('sdslinks')) return true;
      if (lowerPath.contains('productsheetlinks')) return true;
      return false;
    }

    void visit(dynamic node, String path) {
      if (node is Map) {
        node.forEach((dynamic key, dynamic value) {
          final childPath =
              path.isEmpty ? key.toString() : '$path.${key.toString()}';
          visit(value, childPath);
        });
        return;
      }

      if (node is Iterable) {
        var index = 0;
        for (final item in node) {
          index += 1;
          visit(item, '$path[$index]');
        }
        return;
      }

      final lowerPath = path.toLowerCase();
      if (isConsumedPath(lowerPath)) return;

      final text = _valueToDisplayText(node);
      if (text.isEmpty) return;

      if (_isHttpUrl(text)) {
        final normalized = _normalizeUrl(text);
        if (imageUrls.contains(normalized) ||
            documentUrls.contains(normalized)) {
          return;
        }
      }

      entries.add(MapEntry(path, text));
    }

    visit(data, '');
    entries.sort((a, b) => a.key.compareTo(b.key));
    return entries;
  }

  String _valueToDisplayText(dynamic value) {
    if (value == null) return '';
    if (value is String) return value.trim();
    if (value is Timestamp) return value.toDate().toIso8601String();
    if (value is DateTime) return value.toIso8601String();
    if (value is DocumentReference) return value.path;
    return value.toString().trim();
  }

  bool _isHttpUrl(String value) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null) return false;
    if (uri.host.isEmpty) return false;
    return uri.scheme == 'http' || uri.scheme == 'https';
  }

  bool _isLikelyPrivateImageAssetUrl(String value) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null) return false;

    final host = uri.host.toLowerCase();
    final path = uri.path.toLowerCase();

    // These Salesforce file-distribution links are often auth-gated and
    // render as broken image placeholders in-app.
    if (host.contains('.my.salesforce.com')) return true;
    if (host.endsWith('salesforce.com') &&
        path.contains('/sfc/dist/version/download')) {
      return true;
    }

    return false;
  }

  bool _looksLikeImageUrl(String value) {
    final text = value.trim().toLowerCase();
    if (text.isEmpty) return false;
    if (RegExp(r'\.(png|jpe?g|gif|webp|bmp|svg)(\?|#|$)').hasMatch(text)) {
      return true;
    }
    return text.contains('image');
  }

  String _normalizeUrl(String value) {
    final trimmed = value.trim();
    if (trimmed.endsWith('/')) {
      return trimmed.substring(0, trimmed.length - 1);
    }
    return trimmed;
  }

  String _formatPathLabel(String path) {
    final trimmedPath = path.trim();
    if (trimmedPath.isEmpty) return '';

    final last = trimmedPath.split('.').last;
    final withIndex = last.replaceAll('[', ' ').replaceAll(']', '');
    final withSpaces = withIndex
        .replaceAll('_', ' ')
        .replaceAllMapped(
          RegExp(r'([a-z])([A-Z])'),
          (match) => '${match.group(1)} ${match.group(2)}',
        )
        .trim();

    if (withSpaces.isEmpty) return '';
    final words = withSpaces.split(RegExp(r'\s+'));
    return words.map((word) {
      if (word.isEmpty) return word;
      return '${word[0].toUpperCase()}${word.substring(1)}';
    }).join(' ');
  }
}

class _DocumentLink {
  const _DocumentLink({
    required this.label,
    required this.url,
  });

  final String label;
  final String url;
}
