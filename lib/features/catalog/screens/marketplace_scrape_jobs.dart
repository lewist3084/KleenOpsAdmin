// marketplace_scrape_jobs.dart

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:shared_widgets/services/catalog_firebase_service.dart';
import 'package:shared_widgets/lists/standardView.dart';
import 'package:shared_widgets/tiles/standard_tile_large.dart';
import 'package:kleenops_admin/features/catalog/details/marketplace_staging_review_details.dart';
import 'package:kleenops_admin/features/catalog/details/website_details.dart';
import 'package:kleenops_admin/features/catalog/details/scrape_job_details.dart';
// Scrape workflow collections now live in the catalog Firebase project.
import 'package:shared_widgets/dialogs/dialog_select.dart';
import 'package:shared_widgets/tabs/standard_tab.dart';

import 'package:kleenops_admin/l10n/app_localizations.dart';

Map<String, dynamic> _asStringDynamicMap(dynamic value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return value.map((key, val) => MapEntry(key.toString(), val));
  }
  return <String, dynamic>{};
}

/// Scraping screen with two tabs: Websites (brand owners) and Scraping (jobs).
class ScrapeJobsScreen extends ConsumerStatefulWidget {
  const ScrapeJobsScreen({super.key});

  @override
  ConsumerState<ScrapeJobsScreen> createState() => _ScrapeJobsScreenState();
}

class _ScrapeJobsScreenState extends ConsumerState<ScrapeJobsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() { if (mounted) setState(() {}); });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Container(
            color: Colors.white,
            child: StandardTabBar(
              controller: _tabController,
              isScrollable: true,
              dividerColor: Colors.grey[300],
              indicatorColor: Theme.of(context).primaryColor,
              indicatorWeight: 3.0,
              labelColor: Colors.black,
              unselectedLabelColor: Colors.grey[600],
              tabs: const [
                Tab(text: 'Websites'),
                Tab(text: 'Jobs'),
                Tab(text: 'Review'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: const [
                _WebsitesTab(),
                _ScrapingTab(),
                _ReviewTab(),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: _tabController.index == 2
          ? null
          : FloatingActionButton(
              onPressed: () {
                if (_tabController.index == 0) {
                  showDialog(context: context, builder: (_) => const _AddWebsiteDialog());
                } else {
                  showDialog(context: context, builder: (_) => const _CombinedScrapeDialog());
                }
              },
              child: const Icon(Icons.add),
            ),
    );
  }
}

/// Websites tab — brand owners list.
class _WebsitesTab extends StatelessWidget {
  const _WebsitesTab();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('brandOwner')
          .orderBy('name')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) return const Center(child: Text('No websites yet. Tap + to add one.'));
        return ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data();
            final name = (data['name'] ?? '').toString();
            final baseUrl = (data['baseUrl'] ?? '').toString();
            final websiteType = (data['websiteType'] ?? '').toString();
            final lastScraped = data['lastScrapedAt'];
            final apiConfig = data['apiConfig'] is Map ? Map<String, dynamic>.from(data['apiConfig'] as Map) : <String, dynamic>{};

            return Card(
              child: ListTile(
                leading: const CircleAvatar(child: Icon(Icons.language)),
                title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (baseUrl.isNotEmpty) Text(baseUrl, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
                    Row(
                      children: [
                        if (websiteType.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: Colors.blue.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: Text(websiteType, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                          ),
                        if (apiConfig['webstoreId'] != null) ...[
                          const SizedBox(width: 6),
                          Icon(Icons.api, size: 14, color: Colors.green[400]),
                          const SizedBox(width: 2),
                          Text('API configured', style: TextStyle(fontSize: 10, color: Colors.green[600])),
                        ],
                        if (lastScraped != null) ...[
                          const SizedBox(width: 8),
                          Text(
                            'Last: ${_fmtTs(lastScraped)}',
                            style: const TextStyle(fontSize: 10, color: Colors.grey),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
                isThreeLine: true,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => WebsiteDetails(docId: doc.id),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  static String _fmtTs(dynamic ts) {
    if (ts is Timestamp) {
      final dt = ts.toDate();
      return '${dt.month}/${dt.day}/${dt.year}';
    }
    return '';
  }
}

/// Scraping tab — jobs list.
class _ScrapingTab extends StatelessWidget {
  const _ScrapingTab();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('scrapeJob')
          .orderBy('createdAt', descending: true)
          .limit(50)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) return const Center(child: Text('No scraping jobs yet. Tap + to create one.'));
        return ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data();
            final status = (data['status'] ?? 'unknown').toString();
            final vendorName = (data['vendorName'] ?? '').toString();
            final brandName = (data['brandName'] ?? '').toString();
            final targetUrl = (data['targetUrl'] ?? '').toString();
            final results = data['results'] is Map
                ? Map<String, dynamic>.from(data['results'] as Map)
                : <String, dynamic>{};
            final progress = data['progress'] is Map
                ? Map<String, dynamic>.from(data['progress'] as Map)
                : <String, dynamic>{};
            // While the job is running, the live count lives on
            // `progress.staged`. After completion the worker also writes
            // `results.stagedProducts`. Pick whichever is greater so we
            // never regress to the createScrapeJob-initialized 0.
            final stagedLive = (progress['staged'] as num?)?.toInt() ?? 0;
            final stagedFinal =
                (results['stagedProducts'] as num?)?.toInt() ?? 0;
            final stagedCount =
                stagedLive > stagedFinal ? stagedLive : stagedFinal;

            // Prefer the live progress.totalFound that the worker writes
            // immediately after the category listing is collected, so
            // the tile shows "Found: 62" while items are still being
            // staged. Same zero-init hazard as above.
            final totalLive = (progress['totalFound'] as num?)?.toInt() ?? 0;
            final totalFinal = (results['totalFound'] as num?)?.toInt() ??
                (results['totalProducts'] as num?)?.toInt() ??
                0;
            final totalFound =
                totalLive > totalFinal ? totalLive : totalFinal;

            final failedLive = (progress['failed'] as num?)?.toInt() ?? 0;
            final failedFinal = (results['failed'] as num?)?.toInt() ?? 0;
            final failedCount =
                failedLive > failedFinal ? failedLive : failedFinal;

            final statusColor = switch (status) {
              'completed' => Colors.green,
              'running' => Colors.blue,
              'failed' => Colors.red,
              'cancelled' => Colors.grey,
              _ => Colors.orange,
            };

            final subtitle = [
              if (brandName.isNotEmpty) brandName,
              if (targetUrl.isNotEmpty) targetUrl.length > 60
                  ? '${targetUrl.substring(0, 60)}...'
                  : targetUrl,
            ].join(' \u2014 ');

            return Card(
              child: ListTile(
                leading: Icon(Icons.downloading, color: statusColor),
                title: Text(
                  vendorName.isNotEmpty ? vendorName : 'Scrape Job',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (subtitle.isNotEmpty) Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            status.toUpperCase(),
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: statusColor),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // While running, show "staged / totalFound" so the
                        // reviewer can see live progress. When the job
                        // reaches a terminal state, fall back to the
                        // summary totals written to `results`.
                        if ((totalFound as num) > 0)
                          Text(
                            status == 'running'
                                ? '$stagedCount / $totalFound'
                                : 'Found: $totalFound  Staged: $stagedCount',
                            style: const TextStyle(fontSize: 12),
                          ),
                        if ((failedCount as num) > 0) ...[
                          const SizedBox(width: 8),
                          Text('Failed: $failedCount', style: const TextStyle(fontSize: 12, color: Colors.red)),
                        ],
                      ],
                    ),
                  ],
                ),
                isThreeLine: true,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ScrapeJobDetails(docId: doc.id),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

/// Review tab — staged products needing review.
class _ReviewTab extends StatefulWidget {
  const _ReviewTab();
  @override
  State<_ReviewTab> createState() => _ReviewTabState();
}

class _ReviewTabState extends State<_ReviewTab> {
  bool _processing = false;
  List<String> _currentDocIds = [];

  String _resolveImageUrl(Map<String, dynamic> data) {
    final detailData = data['detailData'] is Map ? Map<String, dynamic>.from(data['detailData'] as Map) : <String, dynamic>{};
    // Prefer Firebase Storage URLs (CORS-enabled for the admin domain).
    final storageImages = detailData['storageImages'] is List ? detailData['storageImages'] as List : [];
    if (storageImages.isNotEmpty) {
      final first = storageImages.first is Map ? Map<String, dynamic>.from(storageImages.first as Map) : <String, dynamic>{};
      final url = (first['downloadUrl'] ?? '').toString();
      if (url.startsWith('http')) return url;
    }
    // Fall back to imageLinks (productmarketingcloud.com CDN — may work on
    // mobile but blocked by CORS on web for some vendors).
    final imageLinks = detailData['imageLinks'] is List ? detailData['imageLinks'] as List : [];
    if (imageLinks.isNotEmpty) {
      final first = imageLinks.first is Map ? Map<String, dynamic>.from(imageLinks.first as Map) : <String, dynamic>{};
      final url = (first['href'] ?? first['url'] ?? '').toString();
      if (url.startsWith('http')) return url;
    }
    // Last resort: normalizedData.imageUrl. Skip if it's a relative path
    // (e.g. "/cms/delivery/media/...") — those render as broken images on
    // web because there's no host to resolve against.
    final normalized = data['normalizedData'] is Map ? Map<String, dynamic>.from(data['normalizedData'] as Map) : <String, dynamic>{};
    final fallback = (normalized['imageUrl'] ?? '').toString();
    return fallback.startsWith('http') ? fallback : '';
  }

  Future<void> _confirmClear(BuildContext context) async {
    if (_currentDocIds.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear All Review Items'),
        content: Text('Are you sure you want to clear ${_currentDocIds.length} items from review? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _processing = true);
    try {
      final db = FirebaseFirestore.instance;
      final batch = db.batch();
      for (final id in _currentDocIds) {
        batch.delete(db.collection('stagedProduct').doc(id));
      }
      await batch.commit();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${_currentDocIds.length} items cleared')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<void> _confirmTransfer(BuildContext context) async {
    if (_currentDocIds.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Transfer All to Catalog'),
        content: Text('Are you sure you want to transfer ${_currentDocIds.length} products to the object catalog?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Transfer All')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _processing = true);
    try {
      // 9-minute client-side timeout to match the 540s Cloud Function
      // cap. The httpsCallable default is 70s — short enough that large
      // batches (20+ items) would show "internal" errors in the UI
      // even though the server was still correctly processing the rest.
      final callable = FirebaseFunctions.instanceFor(region: 'us-central1')
          .httpsCallable(
        'bulkApproveStaged',
        options: HttpsCallableOptions(timeout: const Duration(minutes: 9)),
      );
      await callable.call({'stagedIds': _currentDocIds});
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${_currentDocIds.length} products transferred')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Transfer failed: $e')));
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('stagedProduct')
                .where('status', isEqualTo: 'needs_review')
                .orderBy('createdAt', descending: true)
                .limit(100)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              final docs = snapshot.data!.docs;
              _currentDocIds = docs.map((d) => d.id).toList();
              if (docs.isEmpty) return const Center(child: Text('No products to review.'));

              final items = docs.map((doc) {
                final data = doc.data();
                final objectData = data['objectData'] is Map
                    ? Map<String, dynamic>.from(data['objectData'] as Map)
                    : <String, dynamic>{};
                final normalized = data['normalizedData'] is Map
                    ? Map<String, dynamic>.from(data['normalizedData'] as Map)
                    : <String, dynamic>{};
                final rawData = data['rawData'] is Map
                    ? Map<String, dynamic>.from(data['rawData'] as Map)
                    : <String, dynamic>{};

                return {
                  'docId': doc.id,
                  'data': data,
                  'name': (objectData['name'] ?? normalized['name'] ?? rawData['name'] ?? 'Unnamed').toString(),
                  'suggestedCategoryKey': (data['suggestedCategoryKey'] ?? '').toString(),
                  'suggestedScalarKey': (data['suggestedScalarKey'] ?? '').toString(),
                  'suggestedCategoryId': data['suggestedCategoryId'],
                  'objectProductCode': (objectData['objectProductCode'] ??
                          objectData['productNumber'] ??
                          rawData['productNumber'] ??
                          '')
                      .toString(),
                  'upc': (objectData['objectBarcode'] ??
                          objectData['upc'] ??
                          rawData['upc'] ??
                          '')
                      .toString(),
                  'brand': (objectData['brand'] ??
                          normalized['brandName'] ??
                          rawData['brandName'] ??
                          '')
                      .toString(),
                  'imageUrl': _resolveImageUrl(data),
                };
              }).toList();

              return Column(
                children: [
                  Expanded(
                    child: StandardView<Map<String, dynamic>>(
                      items: items,
                      // Group by the LLM-suggested category so the reviewer sees
                      // products clustered by type (Consumables - Liquid, Furnishings,
                      // etc.) before they even open the detail view.
                      groupBy: (item) {
                        final key = item['suggestedCategoryKey'] as String;
                        return key.isNotEmpty ? key : 'Uncategorized';
                      },
                      groupCollapsible: true,
                      initialGroupExpanded: true,
                      headerIcon: null,
                      disableGrouping: false,
                      onTap: (item) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => MarketplaceStagingReviewDetailsScreen(
                              docId: item['docId'] as String,
                              initialData: item['data'] as Map<String, dynamic>,
                            ),
                          ),
                        );
                      },
                      itemBuilder: (item) {
                        final name = item['name'] as String;
                        final imageUrl = item['imageUrl'] as String;
                        final brand = item['brand'] as String;
                        final usage =
                            (item['suggestedScalarKey'] as String? ?? '');

                        // Row 1 = name, row 2 = brand, row 3 = usage
                        // (suggestedScalarKey — e.g. Volume, Time, Count).
                        final secondLine = brand.isNotEmpty ? brand : '';
                        final thirdLine =
                            usage.isNotEmpty ? usage : null;

                        return StandardTileLargeDart(
                          imageUrl: imageUrl,
                          firstLine: name,
                          firstLineIcon: Icons.category_outlined,
                          secondLine: secondLine,
                          secondLineIcon: secondLine.isNotEmpty
                              ? Icons.branding_watermark_outlined
                              : null,
                          thirdLine: thirdLine,
                          thirdLineIcon:
                              thirdLine != null ? Icons.straighten : null,
                        );
                      },
                    ),
                  ),
                  // Clear / Transfer bar — inside the StreamBuilder so it
                  // renders as soon as docs arrive, instead of waiting for a
                  // parent setState that may never fire.
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
                          style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.secondary, foregroundColor: Colors.white),
                          onPressed: _processing ? null : () => _confirmTransfer(context),
                          child: Text(_processing ? 'Working...' : 'Transfer'),
                        ),
                      ),
                    ]),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Simple dialog: just company name + base URL. Auto-detects website type.
class _AddWebsiteDialog extends StatefulWidget {
  const _AddWebsiteDialog();
  @override
  State<_AddWebsiteDialog> createState() => _AddWebsiteDialogState();
}

class _AddWebsiteDialogState extends State<_AddWebsiteDialog> {
  final _nameCtl = TextEditingController();
  final _urlCtl = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() { _nameCtl.dispose(); _urlCtl.dispose(); super.dispose(); }

  Future<void> _save() async {
    final name = _nameCtl.text.trim();
    final url = _urlCtl.text.trim();
    if (name.isEmpty || url.isEmpty) {
      setState(() => _error = 'Name and URL are required');
      return;
    }
    setState(() { _saving = true; _error = null; });

    try {
      // Auto-detect website type from URL
      String websiteType = 'custom_html';
      Map<String, dynamic> apiConfig = {};
      int interItemDelayMs = 3000;

      // Detect Salesforce Commerce (LWR) sites
      final callable = FirebaseFunctions.instanceFor(region: 'us-central1')
          .httpsCallable('detectWebsiteType');
      try {
        final result = await callable.call({'baseUrl': url});
        final payload = Map<String, dynamic>.from(result.data as Map);
        websiteType = (payload['websiteType'] ?? websiteType).toString();
        if (payload['apiConfig'] is Map) {
          apiConfig = Map<String, dynamic>.from(payload['apiConfig'] as Map);
        }
        if (payload['interItemDelayMs'] is num) {
          interItemDelayMs = (payload['interItemDelayMs'] as num).toInt();
        }
      } catch (_) {
        // Detection failed, use defaults — will be refined on first scrape
      }

      final saveCallable = FirebaseFunctions.instanceFor(region: 'us-central1')
          .httpsCallable('saveBrandOwner');
      await saveCallable.call({
        'name': name,
        'baseUrl': url,
        'websiteType': websiteType,
        'rateLimits': { 'interItemDelayMs': interItemDelayMs, 'maxProductsPerRun': 200 },
        if (apiConfig.isNotEmpty) 'apiConfig': apiConfig,
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$name added')),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 450),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Add Website', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              TextField(
                controller: _nameCtl,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Company Name',
                  hintText: 'e.g., Solenis',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.business),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _urlCtl,
                decoration: const InputDecoration(
                  labelText: 'Website URL',
                  hintText: 'https://products.solenis.com',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.language),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
              ],
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(onPressed: _saving ? null : () => Navigator.pop(context), child: const Text('Cancel')),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Add'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Brand owner detail/edit screen (full form with all fields).
class _BrandOwnerDetailScreen extends StatefulWidget {
  final String docId;
  final Map<String, dynamic> data;
  const _BrandOwnerDetailScreen({required this.docId, required this.data});
  @override
  State<_BrandOwnerDetailScreen> createState() => _BrandOwnerDetailScreenState();
}

class _BrandOwnerDetailScreenState extends State<_BrandOwnerDetailScreen> {
  late final TextEditingController _nameCtl;
  late final TextEditingController _baseUrlCtl;
  late final TextEditingController _notesCtl;
  late final TextEditingController _delayCtl;
  late final TextEditingController _maxProductsCtl;
  late final TextEditingController _webstoreIdCtl;
  late final TextEditingController _communityIdCtl;
  late String _websiteType;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.data;
    final rl = e['rateLimits'] is Map ? Map<String, dynamic>.from(e['rateLimits'] as Map) : <String, dynamic>{};
    final ac = e['apiConfig'] is Map ? Map<String, dynamic>.from(e['apiConfig'] as Map) : <String, dynamic>{};
    _nameCtl = TextEditingController(text: (e['name'] ?? '').toString());
    _baseUrlCtl = TextEditingController(text: (e['baseUrl'] ?? '').toString());
    _notesCtl = TextEditingController(text: (e['notes'] ?? '').toString());
    _delayCtl = TextEditingController(text: (rl['interItemDelayMs'] ?? 3000).toString());
    _maxProductsCtl = TextEditingController(text: (rl['maxProductsPerRun'] ?? 200).toString());
    _webstoreIdCtl = TextEditingController(text: (ac['webstoreId'] ?? '').toString());
    _communityIdCtl = TextEditingController(text: (ac['communityId'] ?? '').toString());
    _websiteType = (e['websiteType'] ?? 'custom_html').toString();
  }

  @override
  void dispose() {
    _nameCtl.dispose(); _baseUrlCtl.dispose(); _notesCtl.dispose();
    _delayCtl.dispose(); _maxProductsCtl.dispose();
    _webstoreIdCtl.dispose(); _communityIdCtl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final ac = <String, dynamic>{};
      if (_webstoreIdCtl.text.trim().isNotEmpty) ac['webstoreId'] = _webstoreIdCtl.text.trim();
      if (_communityIdCtl.text.trim().isNotEmpty) ac['communityId'] = _communityIdCtl.text.trim();

      final callable = FirebaseFunctions.instanceFor(region: 'us-central1')
          .httpsCallable('saveBrandOwner');
      await callable.call({
        'brandOwnerId': widget.docId,
        'name': _nameCtl.text.trim(),
        'baseUrl': _baseUrlCtl.text.trim(),
        'websiteType': _websiteType,
        'rateLimits': {
          'interItemDelayMs': int.tryParse(_delayCtl.text.trim()) ?? 3000,
          'maxProductsPerRun': int.tryParse(_maxProductsCtl.text.trim()) ?? 200,
        },
        if (ac.isNotEmpty) 'apiConfig': ac,
        'notes': _notesCtl.text.trim(),
      });
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Updated')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_nameCtl.text)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(controller: _nameCtl, decoration: const InputDecoration(labelText: 'Company Name', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          TextField(controller: _baseUrlCtl, decoration: const InputDecoration(labelText: 'Website URL', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _websiteType,
            decoration: const InputDecoration(labelText: 'Website Type', border: OutlineInputBorder()),
            items: const [
              DropdownMenuItem(value: 'salesforce_lwr', child: Text('Salesforce LWR')),
              DropdownMenuItem(value: 'shopify', child: Text('Shopify')),
              DropdownMenuItem(value: 'woocommerce', child: Text('WooCommerce')),
              DropdownMenuItem(value: 'custom_html', child: Text('Custom HTML')),
              DropdownMenuItem(value: 'other', child: Text('Other')),
            ],
            onChanged: (v) => setState(() => _websiteType = v!),
          ),
          const SizedBox(height: 16),
          const Text('Rate Limits', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: TextField(controller: _delayCtl, decoration: const InputDecoration(labelText: 'Delay (ms)', border: OutlineInputBorder()), keyboardType: TextInputType.number)),
            const SizedBox(width: 12),
            Expanded(child: TextField(controller: _maxProductsCtl, decoration: const InputDecoration(labelText: 'Max Products', border: OutlineInputBorder()), keyboardType: TextInputType.number)),
          ]),
          if (_websiteType == 'salesforce_lwr') ...[
            const SizedBox(height: 16),
            const Text('Salesforce API Config', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            TextField(controller: _webstoreIdCtl, decoration: const InputDecoration(labelText: 'Webstore ID', border: OutlineInputBorder())),
            const SizedBox(height: 8),
            TextField(controller: _communityIdCtl, decoration: const InputDecoration(labelText: 'Community ID', border: OutlineInputBorder())),
          ],
          const SizedBox(height: 12),
          TextField(controller: _notesCtl, maxLines: 3, decoration: const InputDecoration(labelText: 'Notes', border: OutlineInputBorder())),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving ? const CircularProgressIndicator(strokeWidth: 2, color: Colors.white) : const Text('Save Changes'),
          ),
        ],
      ),
    );
  }
}

/// Simple dialog for creating a combined scrape job.
class _CombinedScrapeDialog extends StatefulWidget {
  const _CombinedScrapeDialog();

  @override
  State<_CombinedScrapeDialog> createState() => _CombinedScrapeDialogState();
}

class _CombinedScrapeDialogState extends State<_CombinedScrapeDialog> {
  final _urlController = TextEditingController();
  final _nameController = TextEditingController();
  final _startPageController = TextEditingController(text: '1');
  final _endPageController = TextEditingController(text: '50');
  bool _creating = false;
  String? _error;

  // Brand
  bool _loadingBrands = true;
  List<_BrandOption> _brands = [];
  String? _selectedBrandId;
  String? _selectedBrandName;

  // Brand Owner
  bool _loadingBrandOwners = true;
  List<_BrandOption> _brandOwners = [];
  String? _selectedBrandOwnerId;

  @override
  void initState() {
    super.initState();
    _loadBrands();
    _loadBrandOwners();
  }

  @override
  void dispose() {
    _urlController.dispose();
    _nameController.dispose();
    _startPageController.dispose();
    _endPageController.dispose();
    super.dispose();
  }

  Future<void> _loadBrands() async {
    // Read directly from Firestore instead of going through the
    // getCatalogBrands Cloud Function. The function was silently failing
    // in the web app (likely auth/CORS), leaving the dropdown empty.
    // Direct reads match how brand owners are loaded (_loadBrandOwners)
    // and remove the Cloud Function as a failure surface.
    try {
      final snap = await FirebaseFirestore.instance
          .collection('brand')
          .orderBy('name')
          .get();
      final brands = <_BrandOption>[];
      for (final doc in snap.docs) {
        final data = doc.data();
        final name = (data['name'] ?? data['brand'] ?? '').toString().trim();
        brands.add(_BrandOption(id: doc.id, name: name));
      }
      brands.sort((a, b) {
        final aName = a.name.toLowerCase();
        final bName = b.name.toLowerCase();
        if (aName.isEmpty && bName.isEmpty) return a.id.compareTo(b.id);
        if (aName.isEmpty) return 1;
        if (bName.isEmpty) return -1;
        return aName.compareTo(bName);
      });
      if (!mounted) return;
      setState(() { _brands = brands; _loadingBrands = false; });
    } catch (e) {
      debugPrint('Failed to load brands: $e');
      if (!mounted) return;
      setState(() { _brands = []; _loadingBrands = false; });
    }
  }

  Future<void> _loadBrandOwners() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('brandOwner')
          .orderBy('name')
          .get();
      if (!mounted) return;
      setState(() {
        _brandOwners = snap.docs.map((doc) {
          final data = doc.data();
          return _BrandOption(id: doc.id, name: (data['name'] ?? '').toString().trim());
        }).toList();
        _loadingBrandOwners = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _brandOwners = []; _loadingBrandOwners = false; });
    }
  }

  Future<void> _openBrandPicker() async {
    FocusScope.of(context).unfocus();
    final selected = await showDialog<_BrandOption?>(
      context: context,
      builder: (dialogCtx) => DialogSelect<_BrandOption>(
        title: 'Brand',
        items: _brands,
        itemLabel: (b) => b.name.isEmpty ? b.id : b.name,
        itemSearchString: (b) => b.name.isEmpty ? b.id : b.name,
        initialSelection: _selectedBrandId == null
            ? null
            : _brands.firstWhere(
                (b) => b.id == _selectedBrandId,
                orElse: () => const _BrandOption(id: '', name: ''),
              ),
        tileType: DialogSelectTileType.radio,
        searchLabelText: 'Search',
        emptyStateText: 'No brands yet',
        onCancel: () => Navigator.of(dialogCtx).pop(),
        onSubmit: (result) => Navigator.of(dialogCtx).pop(result.firstOrNull),
      ),
    );
    if (!mounted || selected == null || selected.id.isEmpty) return;
    setState(() {
      _selectedBrandId = selected.id;
      _selectedBrandName = selected.name;
    });
  }

  Future<void> _openBrandOwnerPicker() async {
    FocusScope.of(context).unfocus();
    final selected = await showDialog<_BrandOption?>(
      context: context,
      builder: (dialogCtx) => DialogSelect<_BrandOption>(
        title: 'Brand Owner',
        items: _brandOwners,
        itemLabel: (bo) => bo.name.isEmpty ? bo.id : bo.name,
        itemSearchString: (bo) => bo.name.isEmpty ? bo.id : bo.name,
        initialSelection: _selectedBrandOwnerId == null
            ? null
            : _brandOwners.firstWhere(
                (bo) => bo.id == _selectedBrandOwnerId,
                orElse: () => const _BrandOption(id: '', name: ''),
              ),
        tileType: DialogSelectTileType.radio,
        searchLabelText: 'Search',
        emptyStateText: 'No brand owners yet',
        onCancel: () => Navigator.of(dialogCtx).pop(),
        onSubmit: (result) => Navigator.of(dialogCtx).pop(result.firstOrNull),
      ),
    );
    if (!mounted || selected == null || selected.id.isEmpty) return;
    setState(() => _selectedBrandOwnerId = selected.id);
  }

  Future<void> _create() async {
    final url = _urlController.text.trim();
    final name = _nameController.text.trim();
    if (url.isEmpty) {
      setState(() => _error = 'URL is required');
      return;
    }

    setState(() { _creating = true; _error = null; });

    try {
      // First save a vendor config (or reuse if exists)
      final configCallable = FirebaseFunctions.instanceFor(region: 'us-central1')
          .httpsCallable('saveVendorScrapeConfig');
      final configResult = await configCallable.call({
        'vendorName': name.isNotEmpty ? name : url,
        'vendorUrl': url,
        'scrapeMethod': 'html',
        'htmlConfig': {'catalogUrl': url, 'usesJavaScript': true},
      });
      final configPayload = Map<String, dynamic>.from(configResult.data as Map);
      final vendorConfigId = configPayload['configId'] as String;

      // Create the combined scrape job
      final jobCallable = FirebaseFunctions.instanceFor(region: 'us-central1')
          .httpsCallable('createScrapeJob');
      final startPage = int.tryParse(_startPageController.text.trim()) ?? 1;
      final endPage = int.tryParse(_endPageController.text.trim()) ?? 50;
      final maxProducts = ((endPage - startPage + 1) * 25).clamp(1, 5000);

      await jobCallable.call({
        'vendorConfigId': vendorConfigId,
        'jobType': 'combined',
        if (_selectedBrandId != null) 'brandId': _selectedBrandId,
        if ((_selectedBrandName ?? '').isNotEmpty) 'brandName': _selectedBrandName,
        if (_selectedBrandOwnerId != null) 'brandOwnerId': _selectedBrandOwnerId,
        'maxProducts': maxProducts,
        'pageOffset': (startPage - 1).clamp(0, 10000),
      });

      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Scraping job started')),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DialogAction(
      title: 'New Scrape Job',
      cancelText: 'Cancel',
      onCancel: () => Navigator.pop(context),
      actionText: _creating ? 'Starting...' : 'Start Scraping',
      onAction: _creating ? null : _create,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _urlController,
            decoration: const InputDecoration(
              labelText: 'Catalog URL',
              hintText: 'https://products.solenis.com/category/...',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.link),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Name',
              hintText: 'e.g., Solenis - Good Sense',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.label_outline),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _startPageController,
                  decoration: const InputDecoration(
                    labelText: 'Start Page',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.first_page),
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _endPageController,
                  decoration: const InputDecoration(
                    labelText: 'End Page',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.last_page),
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _BrandPickerField(
            label: 'Brand',
            selectedName: _selectedBrandName,
            loading: _loadingBrands,
            onTap: _loadingBrands ? null : _openBrandPicker,
          ),
          const SizedBox(height: 12),
          _BrandPickerField(
            label: 'Brand Owner',
            selectedName: _selectedBrandOwnerId == null
                ? null
                : _brandOwners
                    .firstWhere(
                      (bo) => bo.id == _selectedBrandOwnerId,
                      orElse: () => const _BrandOption(id: '', name: ''),
                    )
                    .name,
            loading: _loadingBrandOwners,
            onTap: _loadingBrandOwners ? null : _openBrandOwnerPicker,
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
          ],
        ],
      ),
    );
  }
}

/// List of scrape jobs
class _ScrapeJobsList extends StatelessWidget {
  const _ScrapeJobsList();

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final query = CatalogFirebaseService.instance.firestore
        .collection('scrapeJob')
        .orderBy('createdAt', descending: true)
        .limit(50);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Text(loc.commonErrorWithDetails(snapshot.error.toString())),
          );
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.web, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  loc.marketplaceNoScrapeJobsYet,
                  style: TextStyle(color: Colors.grey[600], fontSize: 16),
                ),
                const SizedBox(height: 8),
                Text(
                  loc.marketplaceCreateVendorConfigFirst,
                  style: TextStyle(color: Colors.grey[500], fontSize: 14),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            return _ScrapeJobTile(docId: doc.id, data: doc.data());
          },
        );
      },
    );
  }
}

/// Single scrape job tile
class _ScrapeJobTile extends StatefulWidget {
  final String docId;
  final Map<String, dynamic> data;

  const _ScrapeJobTile({required this.docId, required this.data});

  @override
  State<_ScrapeJobTile> createState() => _ScrapeJobTileState();
}

class _ScrapeJobTileState extends State<_ScrapeJobTile> {
  bool _processing = false;

  String get _status => widget.data['status']?.toString() ?? 'unknown';

  Map<String, dynamic> get _progress =>
      _asStringDynamicMap(widget.data['progress']);

  Map<String, dynamic> get _results =>
      _asStringDynamicMap(widget.data['results']);

  Color _getStatusColor() {
    switch (_status) {
      case 'queued':
        return Colors.grey;
      case 'running':
        return Colors.blue;
      case 'completed':
        return Colors.green;
      case 'failed':
        return Colors.red;
      case 'cancelled':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon() {
    switch (_status) {
      case 'queued':
        return Icons.schedule;
      case 'running':
        return Icons.sync;
      case 'completed':
        return Icons.check_circle;
      case 'failed':
        return Icons.error;
      case 'cancelled':
        return Icons.cancel;
      default:
        return Icons.help_outline;
    }
  }

  Future<void> _cancelJob() async {
    final loc = AppLocalizations.of(context)!;
    if (_processing) return;
    setState(() => _processing = true);

    try {
      final callable = FirebaseFunctions.instanceFor(region: 'us-central1')
          .httpsCallable('cancelScrapeJob');
      await callable.call({'jobId': widget.docId});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(loc.marketplaceJobCancelled)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(loc.marketplaceActionFailed(e.toString()))),
        );
      }
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<void> _retryJob() async {
    final loc = AppLocalizations.of(context)!;
    if (_processing) return;
    setState(() => _processing = true);

    try {
      final callable = FirebaseFunctions.instanceFor(region: 'us-central1')
          .httpsCallable('retryScrapeJob');
      await callable.call({'jobId': widget.docId});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(loc.marketplaceJobRequeued)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(loc.marketplaceActionFailed(e.toString()))),
        );
      }
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final vendorName =
        widget.data['vendorName']?.toString() ?? loc.marketplaceUnknownVendor;
    final jobType = widget.data['jobType']?.toString() ?? 'full_catalog';
    final pagesVisited = _progress['pagesVisited'] ?? 0;
    final productsFound = _progress['productsFound'] ?? 0;
    final stagedProducts = _results['stagedProducts'] ?? 0;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _getStatusColor().withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _getStatusIcon(),
                    color: _getStatusColor(),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        vendorName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        jobType.replaceAll('_', ' ').toUpperCase(),
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Chip(
                  label: Text(
                    _status.toUpperCase(),
                    style: TextStyle(
                      color: _getStatusColor(),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  backgroundColor: _getStatusColor().withValues(alpha: 0.1),
                  side: BorderSide.none,
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Progress stats
            Row(
              children: [
                _StatChip(
                    icon: Icons.web,
                    label: loc.marketplacePagesLabel,
                    statValue: pagesVisited.toString()),
                const SizedBox(width: 12),
                _StatChip(
                    icon: Icons.inventory_2,
                    label: loc.marketplaceFoundLabel,
                    statValue: productsFound.toString()),
                const SizedBox(width: 12),
                _StatChip(
                    icon: Icons.pending_actions,
                    label: loc.marketplaceStagedLabel,
                    statValue: stagedProducts.toString()),
              ],
            ),
            // Progress bar for running jobs
            if (_status == 'running') ...[
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: null, // Indeterminate
                backgroundColor: Colors.grey[200],
                valueColor: AlwaysStoppedAnimation(_getStatusColor()),
              ),
            ],
            // Actions
            if (!_processing &&
                (_status == 'queued' ||
                    _status == 'running' ||
                    _status == 'failed' ||
                    _status == 'cancelled' ||
                    _status == 'completed')) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (_status == 'queued' || _status == 'running')
                    TextButton.icon(
                      onPressed: _cancelJob,
                      icon: const Icon(Icons.cancel, size: 18),
                      label: Text(loc.commonCancel),
                      style: TextButton.styleFrom(foregroundColor: Colors.red),
                    ),
                  if (_status == 'failed' ||
                      _status == 'cancelled' ||
                      _status == 'completed')
                    TextButton.icon(
                      onPressed: _retryJob,
                      icon: const Icon(Icons.refresh, size: 18),
                      label: Text(
                        _status == 'completed'
                            ? loc.marketplaceRerun
                            : loc.marketplaceRetry,
                      ),
                    ),
                ],
              ),
            ],
            if (_processing)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(8),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String statValue;

  const _StatChip({
    required this.icon,
    required this.label,
    required this.statValue,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.grey[600]),
        const SizedBox(width: 4),
        Text(
          '$label: $statValue',
          style: TextStyle(color: Colors.grey[600], fontSize: 12),
        ),
      ],
    );
  }
}

/// List of vendor configurations
class _VendorConfigList extends StatelessWidget {
  const _VendorConfigList();

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final query = CatalogFirebaseService.instance.firestore
        .collection('scrapeVendorConfig')
        .where('isActive', isEqualTo: true)
        .orderBy('vendorName');

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Text(loc.commonErrorWithDetails(snapshot.error.toString())),
          );
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.store, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  loc.marketplaceNoVendorConfigurations,
                  style: TextStyle(color: Colors.grey[600], fontSize: 16),
                ),
                const SizedBox(height: 8),
                Text(
                  loc.marketplaceAddVendorToStart,
                  style: TextStyle(color: Colors.grey[500], fontSize: 14),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            return _VendorConfigTile(docId: doc.id, data: doc.data());
          },
        );
      },
    );
  }
}

/// Single vendor config tile
class _VendorConfigTile extends StatelessWidget {
  final String docId;
  final Map<String, dynamic> data;

  const _VendorConfigTile({required this.docId, required this.data});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final vendorName =
        data['vendorName']?.toString() ?? loc.marketplaceUnknownVendor;
    final vendorUrl = data['vendorUrl']?.toString() ?? '';
    final scrapeMethod = data['scrapeMethod']?.toString() ?? 'html';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.blue.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.store, color: Colors.blue),
        ),
        title: Text(vendorName),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (vendorUrl.isNotEmpty)
              Text(
                vendorUrl,
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            Row(
              children: [
                Icon(
                  scrapeMethod == 'api' ? Icons.api : Icons.html,
                  size: 14,
                  color: Colors.grey[500],
                ),
                const SizedBox(width: 4),
                Text(
                  scrapeMethod.toUpperCase(),
                  style: TextStyle(color: Colors.grey[500], fontSize: 11),
                ),
              ],
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (action) => _handleAction(context, action),
          itemBuilder: (ctx) => [
            PopupMenuItem(
              value: 'scrape',
              child: Row(
                children: [
                  Icon(Icons.play_arrow),
                  SizedBox(width: 8),
                  Text(loc.marketplaceStartScrape),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'edit',
              child: Row(
                children: [
                  Icon(Icons.edit),
                  SizedBox(width: 8),
                  Text(loc.commonEdit),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete, color: Colors.red),
                  SizedBox(width: 8),
                  Text(loc.commonDelete,
                      style: const TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleAction(BuildContext context, String action) async {
    switch (action) {
      case 'scrape':
        _startScrape(context);
        break;
      case 'edit':
        _editConfig(context);
        break;
      case 'delete':
        _deleteConfig(context);
        break;
    }
  }

  Future<void> _startScrape(BuildContext context) async {
    final loc = AppLocalizations.of(context)!;
    try {
      final callable = FirebaseFunctions.instanceFor(region: 'us-central1')
          .httpsCallable('createScrapeJob');
      await callable.call({'vendorConfigId': docId});
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(loc.marketplaceScrapeJobCreated)),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(loc.marketplaceActionFailed(e.toString()))),
        );
      }
    }
  }

  void _editConfig(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => _VendorConfigDialog(
        configId: docId,
        initialData: data,
      ),
    );
  }

  Future<void> _deleteConfig(BuildContext context) async {
    final loc = AppLocalizations.of(context)!;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(loc.marketplaceDeleteVendorConfigTitle),
        content: Text(loc.marketplaceDeleteVendorConfigConfirm(
          (data['vendorName'] ?? '').toString(),
        )),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(loc.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(loc.commonDelete),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final callable = FirebaseFunctions.instanceFor(region: 'us-central1')
          .httpsCallable('deleteVendorScrapeConfig');
      await callable.call({'configId': docId});
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(loc.marketplaceVendorConfigDeleted)),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(loc.marketplaceActionFailed(e.toString()))),
        );
      }
    }
  }
}

/// Wizard step enum for vendor setup
enum _VendorSetupStep { urlInput, analyzing, review }

/// Dialog to create/edit vendor configuration with auto-detection
class _VendorConfigDialog extends StatefulWidget {
  final String? configId;
  final Map<String, dynamic>? initialData;

  const _VendorConfigDialog({this.configId, this.initialData});

  @override
  State<_VendorConfigDialog> createState() => _VendorConfigDialogState();
}

class _VendorConfigDialogState extends State<_VendorConfigDialog> {
  final _formKey = GlobalKey<FormState>();
  final _catalogUrlController = TextEditingController();
  final _vendorNameController = TextEditingController();
  final _productListSelectorController = TextEditingController();
  final _productNameSelectorController = TextEditingController();
  final _productImageSelectorController = TextEditingController();
  final _productNumberSelectorController = TextEditingController();
  final _productLinkSelectorController = TextEditingController();
  final _nextPageSelectorController = TextEditingController();
  final _notesController = TextEditingController();

  _VendorSetupStep _currentStep = _VendorSetupStep.urlInput;
  String _scrapeMethod = 'html';
  bool _usesJavaScript = false;
  bool _saving = false;
  bool _reanalyzing = false;
  String? _error;

  // Analysis results
  Map<String, dynamic>? _analysisResult;
  List<Map<String, dynamic>> _sampleProducts = [];
  Map<String, double> _confidence = {};

  @override
  void initState() {
    super.initState();
    if (widget.initialData != null) {
      _loadExistingData();
      // Skip to review step if editing
      _currentStep = _VendorSetupStep.review;
    }
  }

  void _loadExistingData() {
    final data = widget.initialData!;
    _vendorNameController.text = data['vendorName'] ?? '';
    _scrapeMethod = data['scrapeMethod'] ?? 'html';
    _notesController.text = data['notes'] ?? '';

    final htmlConfig = _asStringDynamicMap(data['htmlConfig']);
    _catalogUrlController.text = htmlConfig['catalogUrl'] ?? '';
    _usesJavaScript = htmlConfig['usesJavaScript'] ?? false;

    final selectors = _asStringDynamicMap(htmlConfig['selectors']);
    _productListSelectorController.text = selectors['productList'] ?? '';
    _productNameSelectorController.text = selectors['productName'] ?? '';
    _productImageSelectorController.text = selectors['productImage'] ?? '';
    _productNumberSelectorController.text = selectors['productNumber'] ?? '';
    _productLinkSelectorController.text = selectors['productLink'] ?? '';
    _nextPageSelectorController.text = selectors['nextPage'] ?? '';
  }

  @override
  void dispose() {
    _catalogUrlController.dispose();
    _vendorNameController.dispose();
    _productListSelectorController.dispose();
    _productNameSelectorController.dispose();
    _productImageSelectorController.dispose();
    _productNumberSelectorController.dispose();
    _productLinkSelectorController.dispose();
    _nextPageSelectorController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _startAnalysis() async {
    final url = _catalogUrlController.text.trim();
    if (url.isEmpty) {
      setState(() => _error = 'Please enter a catalog URL');
      return;
    }

    // Basic URL validation
    Uri? parsed;
    try {
      parsed = Uri.parse(url);
      if (!parsed.hasScheme || !['http', 'https'].contains(parsed.scheme)) {
        throw const FormatException();
      }
    } catch (_) {
      setState(() => _error = 'Please enter a valid URL (https://...)');
      return;
    }

    setState(() {
      _currentStep = _VendorSetupStep.analyzing;
      _error = null;
    });

    try {
      final callable = FirebaseFunctions.instanceFor(region: 'us-central1')
          .httpsCallable('analyzeVendorCatalog');

      final result = await callable.call({
        'catalogUrl': url,
        'vendorName': _vendorNameController.text.trim(),
      });

      final data = Map<String, dynamic>.from(result.data as Map);

      if (data['success'] != true) {
        throw Exception(data['error'] ?? 'Analysis failed');
      }

      // Populate form with detected values
      if (data['vendorName'] != null && _vendorNameController.text.isEmpty) {
        _vendorNameController.text = data['vendorName'];
      }

      _usesJavaScript = data['usesJavaScript'] ?? false;

      final selectors = data['selectors'] != null
          ? Map<String, dynamic>.from(data['selectors'] as Map)
          : <String, dynamic>{};
      _productListSelectorController.text = selectors['productList'] ?? '';
      _productNameSelectorController.text = selectors['productName'] ?? '';
      _productImageSelectorController.text = selectors['productImage'] ?? '';
      _productNumberSelectorController.text = selectors['productNumber'] ?? '';
      _productLinkSelectorController.text = selectors['productLink'] ?? '';
      _nextPageSelectorController.text = selectors['nextPage'] ?? '';

      _analysisResult = data;
      _sampleProducts = (data['sampleProducts'] as List<dynamic>?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          [];

      final conf = data['confidence'] != null
          ? Map<String, dynamic>.from(data['confidence'] as Map)
          : <String, dynamic>{};
      _confidence = {
        'overall': (conf['overall'] as num?)?.toDouble() ?? 0,
        'productList': (conf['productList'] as num?)?.toDouble() ?? 0,
        'productName': (conf['productName'] as num?)?.toDouble() ?? 0,
        'productImage': (conf['productImage'] as num?)?.toDouble() ?? 0,
        'productNumber': (conf['productNumber'] as num?)?.toDouble() ?? 0,
        'productLink': (conf['productLink'] as num?)?.toDouble() ?? 0,
        'nextPage': (conf['nextPage'] as num?)?.toDouble() ?? 0,
      };

      setState(() {
        _currentStep = _VendorSetupStep.review;
      });
    } catch (e) {
      setState(() {
        _currentStep = _VendorSetupStep.urlInput;
        _error = 'Analysis failed: ${_formatFunctionsError(e)}';
      });
    }
  }

  Future<void> _reanalyze() async {
    final loc = AppLocalizations.of(context)!;
    final url = _catalogUrlController.text.trim();
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.marketplaceEnterCatalogUrlFirst)),
      );
      return;
    }

    setState(() {
      _reanalyzing = true;
      _error = null;
    });

    try {
      final callable = FirebaseFunctions.instanceFor(region: 'us-central1')
          .httpsCallable('analyzeVendorCatalog');

      final result = await callable.call({
        'catalogUrl': url,
        'vendorName': _vendorNameController.text.trim(),
      });

      final data = Map<String, dynamic>.from(result.data as Map);

      if (data['success'] != true) {
        throw Exception(data['error'] ?? 'Analysis failed');
      }

      // Update form with newly detected values
      _usesJavaScript = data['usesJavaScript'] ?? false;

      final selectors = data['selectors'] != null
          ? Map<String, dynamic>.from(data['selectors'] as Map)
          : <String, dynamic>{};
      _productListSelectorController.text = selectors['productList'] ?? '';
      _productNameSelectorController.text = selectors['productName'] ?? '';
      _productImageSelectorController.text = selectors['productImage'] ?? '';
      _productNumberSelectorController.text = selectors['productNumber'] ?? '';
      _productLinkSelectorController.text = selectors['productLink'] ?? '';
      _nextPageSelectorController.text = selectors['nextPage'] ?? '';

      _analysisResult = data;
      _sampleProducts = (data['sampleProducts'] as List<dynamic>?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          [];

      final conf = data['confidence'] != null
          ? Map<String, dynamic>.from(data['confidence'] as Map)
          : <String, dynamic>{};
      _confidence = {
        'overall': (conf['overall'] as num?)?.toDouble() ?? 0,
        'productList': (conf['productList'] as num?)?.toDouble() ?? 0,
        'productName': (conf['productName'] as num?)?.toDouble() ?? 0,
        'productImage': (conf['productImage'] as num?)?.toDouble() ?? 0,
        'productNumber': (conf['productNumber'] as num?)?.toDouble() ?? 0,
        'productLink': (conf['productLink'] as num?)?.toDouble() ?? 0,
        'nextPage': (conf['nextPage'] as num?)?.toDouble() ?? 0,
      };

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(loc.marketplaceReanalysisComplete(
              data['productCount'] ?? 0,
              ((_confidence['overall'] ?? 0) * 100).toInt(),
            )),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(loc.marketplaceReanalysisFailed(
            _formatFunctionsError(e),
          ))),
        );
      }
    } finally {
      if (mounted) setState(() => _reanalyzing = false);
    }
  }

  String _formatFunctionsError(Object error) {
    if (error is FirebaseFunctionsException) {
      final parts = <String>[];
      if (error.code.isNotEmpty) parts.add(error.code);
      if (error.message?.isNotEmpty == true) parts.add(error.message!);
      if (error.details != null) parts.add(error.details.toString());
      if (parts.isNotEmpty) return parts.join(' | ');
    }

    return error.toString().replaceAll('Exception: ', '');
  }

  Future<void> _save() async {
    final loc = AppLocalizations.of(context)!;
    if (!_formKey.currentState!.validate()) return;
    if (_saving) return;

    setState(() => _saving = true);

    try {
      final callable = FirebaseFunctions.instanceFor(region: 'us-central1')
          .httpsCallable('saveVendorScrapeConfig');

      await callable.call({
        if (widget.configId != null) 'configId': widget.configId,
        'vendorName': _vendorNameController.text.trim(),
        'vendorUrl': _catalogUrlController.text.trim(),
        'scrapeMethod': _scrapeMethod,
        'htmlConfig': {
          'catalogUrl': _catalogUrlController.text.trim(),
          'usesJavaScript': _usesJavaScript,
          'selectors': {
            'productList': _productListSelectorController.text.trim(),
            'productName': _productNameSelectorController.text.trim(),
            'productImage': _productImageSelectorController.text.trim(),
            'productNumber': _productNumberSelectorController.text.trim(),
            'productLink': _productLinkSelectorController.text.trim(),
            'nextPage': _nextPageSelectorController.text.trim(),
          },
        },
        'notes': _notesController.text.trim(),
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(loc.marketplaceVendorConfigurationSaved)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(loc.marketplaceActionFailed(e.toString()))),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final isEdit = widget.configId != null;
    final bool showActionButton = _currentStep != _VendorSetupStep.analyzing;
    final String actionText = _currentStep == _VendorSetupStep.urlInput
        ? loc.marketplaceAutoDetect
        : _saving
            ? loc.marketplaceSaving
            : loc.marketplaceSaveConfiguration;
    final VoidCallback onAction =
        _currentStep == _VendorSetupStep.urlInput ? _startAnalysis : _save;

    return DialogAction(
      title: isEdit ? loc.marketplaceEditVendor : loc.marketplaceAddVendor,
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 550, maxHeight: 750),
        child: Form(
          key: _formKey,
          child: _buildStepContent(),
        ),
      ),
      cancelText: loc.commonCancel,
      onCancel: () => Navigator.pop(context),
      actionText: actionText,
      onAction: onAction,
      showActionButton: showActionButton,
      wrapContentInScrollView: false,
    );
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case _VendorSetupStep.urlInput:
        return _buildUrlInputStep();
      case _VendorSetupStep.analyzing:
        return _buildAnalyzingStep();
      case _VendorSetupStep.review:
        return _buildReviewStep();
    }
  }

  Widget _buildUrlInputStep() {
    final loc = AppLocalizations.of(context)!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.auto_fix_high, size: 48, color: Colors.blue),
          const SizedBox(height: 16),
          Text(
            loc.marketplaceAutoDetectCatalogSettings,
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            loc.marketplacePasteCatalogUrlHelp,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          TextFormField(
            controller: _catalogUrlController,
            decoration: InputDecoration(
              labelText: loc.marketplaceCatalogPageUrlRequired,
              hintText: loc.marketplaceCatalogPageUrlHint,
              prefixIcon: Icon(Icons.link),
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.url,
            autofocus: true,
            validator: (v) => v?.trim().isEmpty == true
                ? loc.objectsInventoryRequiredField
                : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _vendorNameController,
            decoration: InputDecoration(
              labelText: loc.marketplaceVendorNameOptional,
              hintText: loc.marketplaceVendorNameOptionalHint,
              prefixIcon: Icon(Icons.store),
              border: OutlineInputBorder(),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.red[700], size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _error!,
                      style: TextStyle(color: Colors.red[700], fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAnalyzingStep() {
    final loc = AppLocalizations.of(context)!;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 64,
              height: 64,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
            const SizedBox(height: 32),
            Text(
              loc.marketplaceAnalyzingCatalogPage,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Text(
              loc.marketplaceDetectingLayoutSelectorsPagination,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewStep() {
    final loc = AppLocalizations.of(context)!;
    final overallConfidence = _confidence['overall'] ?? 0;
    final isHighConfidence = overallConfidence >= 0.7;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Confidence header
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isHighConfidence ? Colors.green[50] : Colors.orange[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color:
                    isHighConfidence ? Colors.green[200]! : Colors.orange[200]!,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isHighConfidence ? Icons.check_circle : Icons.warning,
                  color:
                      isHighConfidence ? Colors.green[700] : Colors.orange[700],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isHighConfidence
                            ? loc.marketplaceDetectionSuccessful
                            : loc.marketplaceDetectionNeedsReview,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isHighConfidence
                              ? Colors.green[800]
                              : Colors.orange[800],
                        ),
                      ),
                      Text(
                        loc.marketplaceConfidencePercent(
                          (overallConfidence * 100).toInt(),
                        ),
                        style: TextStyle(
                          fontSize: 13,
                          color: isHighConfidence
                              ? Colors.green[700]
                              : Colors.orange[700],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (widget.configId == null) ...[
            const SizedBox(height: 12),
            Center(
              child: OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    _currentStep = _VendorSetupStep.urlInput;
                    _analysisResult = null;
                    _sampleProducts = [];
                    _confidence = {};
                  });
                },
                icon: const Icon(Icons.refresh, size: 18),
                label: Text(loc.marketplaceReanalyze),
              ),
            ),
          ],

          // Sample products preview
          if (_sampleProducts.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text(
              loc.marketplaceSampleProductsFound(
                _analysisResult?['productCount'] ?? _sampleProducts.length,
              ),
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: _sampleProducts.take(3).map((product) {
                  final imageUrl = (product['imageUrl'] ??
                          product['image'] ??
                          product['imageSrc'])
                      ?.toString()
                      .trim();
                  return ListTile(
                    dense: true,
                    leading: (imageUrl != null && imageUrl.isNotEmpty)
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: Image.network(
                              imageUrl,
                              width: 28,
                              height: 28,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stack) =>
                                  const Icon(Icons.broken_image, size: 20),
                            ),
                          )
                        : const Icon(Icons.inventory_2, size: 20),
                    title: Text(
                      product['name']?.toString() ?? loc.commonUnknown,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: product['productNumber'] != null
                        ? Text(
                            product['productNumber'].toString(),
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          )
                        : null,
                  );
                }).toList(),
              ),
            ),
          ],

          const SizedBox(height: 20),

          // Vendor name
          TextFormField(
            controller: _vendorNameController,
            decoration: InputDecoration(
              labelText: loc.marketplaceVendorNameRequired,
              border: OutlineInputBorder(),
            ),
            validator: (v) => v?.trim().isEmpty == true
                ? loc.objectsInventoryRequiredField
                : null,
          ),
          const SizedBox(height: 16),

          // Selectors section
          Text(
            loc.marketplaceCssSelectorsTitle,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 12),
          _buildSelectorField(
            'Product Container',
            _productListSelectorController,
            _confidence['productList'] ?? 0,
          ),
          const SizedBox(height: 12),
          _buildSelectorField(
            'Product Name',
            _productNameSelectorController,
            _confidence['productName'] ?? 0,
          ),
          const SizedBox(height: 12),
          _buildSelectorField(
            'Product Image',
            _productImageSelectorController,
            _confidence['productImage'] ?? 0,
          ),
          const SizedBox(height: 12),
          _buildSelectorField(
            'Product Number/SKU',
            _productNumberSelectorController,
            _confidence['productNumber'] ?? 0,
          ),
          const SizedBox(height: 12),
          _buildSelectorField(
            'Product Link',
            _productLinkSelectorController,
            _confidence['productLink'] ?? 0,
          ),
          const SizedBox(height: 12),
          _buildSelectorField(
            'Next Page Link',
            _nextPageSelectorController,
            _confidence['nextPage'] ?? 0,
          ),

          const SizedBox(height: 16),

          // JavaScript toggle
          SwitchListTile(
            title: Text(loc.marketplaceRequiresJavascript),
            subtitle: Text(
              _usesJavaScript
                  ? loc.marketplaceUsesPuppeteer
                  : loc.marketplaceUsesCheerio,
              style: const TextStyle(fontSize: 12),
            ),
            value: _usesJavaScript,
            onChanged: (v) => setState(() => _usesJavaScript = v),
            contentPadding: EdgeInsets.zero,
          ),

          const SizedBox(height: 8),

          // Notes
          TextFormField(
            controller: _notesController,
            decoration: InputDecoration(
              labelText: loc.marketplaceNotesLabel,
              border: OutlineInputBorder(),
            ),
            maxLines: 2,
          ),

          const SizedBox(height: 20),

          // Reanalyze button
          Center(
            child: OutlinedButton.icon(
              onPressed: _reanalyzing ? null : _reanalyze,
              icon: _reanalyzing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh, size: 18),
              label: Text(_reanalyzing
                  ? loc.marketplaceAnalyzing
                  : loc.marketplaceReanalyzeSelectors),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectorField(
    String label,
    TextEditingController controller,
    double confidence,
  ) {
    final color = confidence >= 0.7
        ? Colors.green
        : confidence >= 0.4
            ? Colors.orange
            : Colors.grey;

    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        suffixIcon: confidence > 0
            ? Tooltip(
                message: '${(confidence * 100).toInt()}% confidence',
                child: Icon(
                  confidence >= 0.7
                      ? Icons.check_circle
                      : confidence >= 0.4
                          ? Icons.help
                          : Icons.help_outline,
                  color: color,
                  size: 20,
                ),
              )
            : null,
      ),
      style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
    );
  }
}

/// Dialog to create a new scrape job
class _BrandOption {
  const _BrandOption({
    required this.id,
    required this.name,
  });

  final String id;
  final String name;
}

class _DetailTemplateOption {
  const _DetailTemplateOption({
    required this.id,
    required this.name,
    required this.vendorName,
    required this.data,
  });

  final String id;
  final String name;
  final String vendorName;
  final Map<String, dynamic> data;
}

class _StagedProductOption {
  const _StagedProductOption({
    required this.id,
    required this.name,
    required this.vendorName,
    required this.vendorId,
    required this.productNumber,
    required this.sourceUrl,
    required this.imageUrl,
  });

  final String id;
  final String name;
  final String vendorName;
  final String vendorId;
  final String productNumber;
  final String sourceUrl;
  final String imageUrl;
}

class _CreateScrapeJobDialog extends StatefulWidget {
  const _CreateScrapeJobDialog();

  @override
  State<_CreateScrapeJobDialog> createState() => _CreateScrapeJobDialogState();
}

class _CreateScrapeJobDialogState extends State<_CreateScrapeJobDialog> {
  String? _selectedConfigId;
  final String _jobType = 'combined';
  bool _loading = true;
  bool _creating = false;
  bool _loadingBrands = true;
  bool _loadingBrandOwners = true;
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _configs = [];
  List<_BrandOption> _brands = [];
  List<_BrandOption> _brandOwners = [];
  String? _selectedBrandId;
  String? _selectedBrandName;
  String? _selectedBrandOwnerId;
  String? _selectedBrandOwnerName;
  Future<Map<String, String?>>? _debugInfoFuture;
  final _startPageController = TextEditingController(text: '1');
  final _endPageController = TextEditingController(text: '50');

  @override
  void initState() {
    super.initState();
    _loadConfigs();
    _loadBrands();
    _loadBrandOwners();
    _debugInfoFuture = _loadDebugInfo();
  }

  @override
  void dispose() {
    _startPageController.dispose();
    _endPageController.dispose();
    super.dispose();
  }

  Future<Map<String, String?>> _loadDebugInfo() async {
    final app = Firebase.app();
    final user = FirebaseAuth.instance.currentUser;
    String? idTokenStatus;
    String? appCheckStatus;
    String? appCheckTokenPrefix;

    if (user == null) {
      idTokenStatus = 'no-user';
    } else {
      try {
        final token = await user.getIdToken(true);
        final tokenValue = token ?? '';
        if (tokenValue.isEmpty) {
          idTokenStatus = token == null ? 'null' : 'empty';
        } else {
          idTokenStatus = 'ok';
        }
      } catch (e) {
        idTokenStatus = 'error: $e';
      }
    }

    try {
      final appCheckToken = await FirebaseAppCheck.instance.getToken(true);
      final tokenValue = appCheckToken ?? '';
      if (tokenValue.isEmpty) {
        appCheckStatus = appCheckToken == null ? 'null' : 'empty';
      } else {
        appCheckStatus = 'ok';
        appCheckTokenPrefix = tokenValue.length > 12
            ? '${tokenValue.substring(0, 12)}...'
            : tokenValue;
      }
    } catch (e) {
      appCheckStatus = 'error: $e';
    }

    return {
      'projectId': app.options.projectId,
      'appId': app.options.appId,
      'appName': app.name,
      'uid': user?.uid,
      'email': user?.email,
      'idTokenStatus': idTokenStatus,
      'appCheckStatus': appCheckStatus,
      'appCheckTokenPrefix': appCheckTokenPrefix,
    };
  }

  Future<void> _loadConfigs() async {
    final snap = await CatalogFirebaseService.instance.firestore
        .collection('scrapeVendorConfig')
        .where('isActive', isEqualTo: true)
        .orderBy('vendorName')
        .get();

    setState(() {
      _configs = snap.docs;
      _loading = false;
    });
  }

  Future<void> _loadBrands() async {
    // Direct Firestore read — matches how brand owners are loaded.
    // The getCatalogBrands Cloud Function was silently failing in the
    // web app, leaving the dropdown empty.
    try {
      final snap = await FirebaseFirestore.instance
          .collection('brand')
          .orderBy('name')
          .get();
      final brands = <_BrandOption>[];
      for (final doc in snap.docs) {
        final data = doc.data();
        final name = (data['name'] ?? data['brand'] ?? '').toString().trim();
        brands.add(_BrandOption(id: doc.id, name: name));
      }
      brands.sort((a, b) {
        final aName = a.name.toLowerCase();
        final bName = b.name.toLowerCase();
        if (aName.isEmpty && bName.isEmpty) return a.id.compareTo(b.id);
        if (aName.isEmpty) return 1;
        if (bName.isEmpty) return -1;
        return aName.compareTo(bName);
      });
      if (!mounted) return;
      setState(() {
        _brands = brands;
        _loadingBrands = false;
      });
    } catch (e) {
      debugPrint('Failed to load brands: $e');
      if (!mounted) return;
      setState(() {
        _brands = [];
        _loadingBrands = false;
      });
    }
  }

  Future<void> _loadBrandOwners() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('brandOwner')
          .orderBy('name')
          .get();
      if (!mounted) return;
      setState(() {
        _brandOwners = snap.docs.map((doc) {
          final data = doc.data();
          return _BrandOption(
            id: doc.id,
            name: (data['name'] ?? '').toString().trim(),
          );
        }).toList();
        _loadingBrandOwners = false;
      });
    } catch (e) {
      debugPrint('Failed to load brand owners: $e');
      if (!mounted) return;
      setState(() {
        _brandOwners = [];
        _loadingBrandOwners = false;
      });
    }
  }

  String _brandName(_BrandOption brand) {
    return brand.name.trim();
  }

  _BrandOption? _selectedBrandDoc() {
    final selectedId = _selectedBrandId;
    if (selectedId == null) return null;
    for (final brand in _brands) {
      if (brand.id == selectedId) return brand;
    }
    return null;
  }

  Future<void> _openBrandSelectDialog() async {
    if (_loadingBrands) return;
    FocusScope.of(context).unfocus();
    final loc = AppLocalizations.of(context)!;

    final selected = await showDialog<_BrandOption?>(
      context: context,
      builder: (dialogCtx) => DialogSelect<_BrandOption>(
        title: loc.marketplaceBrand,
        items: _brands,
        itemLabel: (brand) {
          final label = _brandName(brand);
          return label.isEmpty ? loc.marketplaceUnnamedBrand : label;
        },
        itemSearchString: (brand) {
          final label = _brandName(brand);
          return label.isEmpty ? loc.marketplaceUnnamedBrand : label;
        },
        initialSelection: _selectedBrandDoc(),
        tileType: DialogSelectTileType.radio,
        searchLabelText: loc.commonSearch,
        emptyStateText: loc.marketplaceNoBrandsYet,
        onCancel: () => Navigator.of(dialogCtx).pop(),
        onSubmit: (result) => Navigator.of(dialogCtx).pop(result.firstOrNull),
      ),
    );

    if (!mounted || selected == null) return;
    final selectedName = _brandName(selected);
    setState(() {
      _selectedBrandId = selected.id;
      _selectedBrandName = selectedName;
    });
  }

  Future<void> _create() async {
    final loc = AppLocalizations.of(context)!;
    if (_selectedConfigId == null || _creating) return;

    setState(() => _creating = true);

    // Parse start page (1-indexed for user, convert to 0-indexed pageOffset)
    final startPage = int.tryParse(_startPageController.text.trim()) ?? 1;
    final endPage = int.tryParse(_endPageController.text.trim()) ?? 50;
    final pageOffset =
        (startPage - 1).clamp(0, 10000); // pageOffset = startPage - 1
    final maxPages =
        (endPage - startPage + 1).clamp(1, 600); // Number of pages to scrape

    try {
      final callable = FirebaseFunctions.instanceFor(region: 'us-central1')
          .httpsCallable('createScrapeJob');
      await callable.call({
        'vendorConfigId': _selectedConfigId,
        'jobType': _jobType,
        if (_selectedBrandId != null) 'brandId': _selectedBrandId,
        if ((_selectedBrandName ?? '').trim().isNotEmpty)
          'brandName': _selectedBrandName,
        if (_selectedBrandOwnerId != null) 'brandOwnerId': _selectedBrandOwnerId,
        if (_jobType != 'combined' && pageOffset > 0) 'pageOffset': pageOffset,
        if (_jobType != 'combined') 'maxPages': maxPages,
      });

      if (mounted) {
        _closeDialog();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(loc.marketplaceScrapeJobCreated)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(loc.marketplaceActionFailed(e.toString()))),
        );
      }
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  void _closeDialog() {
    final rootNavigator = Navigator.of(context, rootNavigator: true);
    if (rootNavigator.canPop()) {
      rootNavigator.pop();
      return;
    }

    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return DialogAction(
      title: loc.marketplaceCreateScrapeJobTitle,
      cancelText: loc.commonCancel,
      onCancel: () => Navigator.pop(context),
      actionText:
          _creating ? loc.marketplaceCreating : loc.marketplaceCreateJob,
      onAction:
          _selectedConfigId == null || _creating || _loading || _configs.isEmpty
              ? null
              : _create,
      content: _loading
          ? const SizedBox(
              height: 100,
              child: Center(child: CircularProgressIndicator()),
            )
          : _configs.isEmpty
              ? Padding(
                  padding: EdgeInsets.all(16),
                  child:
                      Text(loc.marketplaceNoVendorConfigurationsFoundAddVendor),
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: _selectedConfigId,
                      decoration: InputDecoration(
                        labelText: loc.marketplaceVendor,
                        border: OutlineInputBorder(),
                      ),
                      items: _configs.map((doc) {
                        final data = doc.data();
                        return DropdownMenuItem(
                          value: doc.id,
                          child: Text(data['vendorName'] ?? 'Unknown'),
                        );
                      }).toList(),
                      onChanged: (v) => setState(() => _selectedConfigId = v),
                    ),
                    const SizedBox(height: 16),
                    _buildBrandSelector(loc),
                    const SizedBox(height: 16),
                    _buildBrandOwnerSelector(),
                    const SizedBox(height: 16),
                    _buildDebugPanel(),
                  ],
                ),
    );
  }

  Widget _buildBrandSelector(AppLocalizations loc) {
    final hasSelection = _selectedBrandId != null;
    final selectedName = (_selectedBrandName ?? '').trim();
    final displayValue = hasSelection
        ? (selectedName.isEmpty ? loc.marketplaceUnnamedBrand : selectedName)
        : _brands.isEmpty
            ? loc.marketplaceNoBrandsYet
            : loc.marketplaceFormValidationSelectBrand;
    final textColor = hasSelection ? null : Theme.of(context).hintColor;

    return InkWell(
      onTap: _loadingBrands ? null : _openBrandSelectDialog,
      borderRadius: BorderRadius.circular(4),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: loc.marketplaceFormBrandLabel,
          border: const OutlineInputBorder(),
          suffixIcon: _loadingBrands
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : const Icon(Icons.arrow_drop_down),
        ),
        child: Text(
          displayValue,
          style: TextStyle(color: textColor),
        ),
      ),
    );
  }

  Widget _buildBrandOwnerSelector() {
    final hasSelection = _selectedBrandOwnerId != null;
    final displayValue = hasSelection
        ? (_selectedBrandOwnerName ?? 'Selected')
        : _brandOwners.isEmpty
            ? 'No brand owners yet'
            : 'Select brand owner';
    final textColor = hasSelection ? null : Theme.of(context).hintColor;

    return InkWell(
      onTap: _loadingBrandOwners
          ? null
          : () async {
              final selected = await showDialog<_BrandOption>(
                context: context,
                builder: (ctx) => SimpleDialog(
                  title: const Text('Select Brand Owner'),
                  children: _brandOwners.map((bo) {
                    return SimpleDialogOption(
                      onPressed: () => Navigator.pop(ctx, bo),
                      child: Text(bo.name.isEmpty ? bo.id : bo.name),
                    );
                  }).toList(),
                ),
              );
              if (selected != null && mounted) {
                setState(() {
                  _selectedBrandOwnerId = selected.id;
                  _selectedBrandOwnerName = selected.name;
                });
              }
            },
      borderRadius: BorderRadius.circular(4),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'Brand Owner',
          border: const OutlineInputBorder(),
          suffixIcon: _loadingBrandOwners
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : const Icon(Icons.arrow_drop_down),
        ),
        child: Text(
          displayValue,
          style: TextStyle(color: textColor),
        ),
      ),
    );
  }

  Widget _buildDebugPanel() {
    return FutureBuilder<Map<String, String?>>(
      future: _debugInfoFuture,
      builder: (context, snapshot) {
        final data = snapshot.data;
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Debug (Auth/App Check)',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              _DebugRow(
                label: 'Project',
                value: data?['projectId'] ?? 'loading...',
              ),
              _DebugRow(label: 'App ID', value: data?['appId'] ?? 'loading...'),
              _DebugRow(
                  label: 'App Name', value: data?['appName'] ?? 'loading...'),
              _DebugRow(label: 'UID', value: data?['uid'] ?? 'loading...'),
              _DebugRow(label: 'Email', value: data?['email'] ?? 'loading...'),
              _DebugRow(
                label: 'ID Token',
                value: data?['idTokenStatus'] ?? 'loading...',
              ),
              _DebugRow(
                label: 'App Check',
                value: data?['appCheckStatus'] ?? 'loading...',
              ),
              if (data?['appCheckTokenPrefix'] != null)
                _DebugRow(
                  label: 'App Check Token',
                  value: data!['appCheckTokenPrefix']!,
                ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _debugInfoFuture = _loadDebugInfo();
                    });
                  },
                  icon: const Icon(Icons.refresh, size: 16),
                  label: Text(
                      AppLocalizations.of(context)!.marketplaceRefreshDebug),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DebugRow extends StatelessWidget {
  final String label;
  final String value;

  const _DebugRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: TextStyle(color: Colors.grey[700], fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

// ===== Site Detail Templates Tab =====

/// List of site detail templates
class _SiteDetailTemplateList extends StatefulWidget {
  const _SiteDetailTemplateList();

  @override
  State<_SiteDetailTemplateList> createState() =>
      _SiteDetailTemplateListState();
}

class _SiteDetailTemplateListState extends State<_SiteDetailTemplateList> {
  bool _loading = true;
  String? _error;
  List<_DetailTemplateOption> _templates = [];
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _loadTemplates();
    _pollTimer = Timer.periodic(
      const Duration(seconds: 6),
      (_) => _loadTemplates(silent: true),
    );
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadTemplates({bool silent = false}) async {
    if (!silent && mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final callable = FirebaseFunctions.instanceFor(region: 'us-central1')
          .httpsCallable('getSiteDetailTemplates');
      final result = await callable.call({'limit': 50});
      final payload = Map<String, dynamic>.from(result.data as Map);
      final rawTemplates = payload['templates'] as List<dynamic>? ?? const [];
      final templates = <_DetailTemplateOption>[];
      for (final raw in rawTemplates) {
        if (raw is! Map) continue;
        final data = Map<String, dynamic>.from(raw);
        final id = (data['id'] ?? '').toString().trim();
        if (id.isEmpty) continue;
        final name = (data['name'] ?? '').toString().trim();
        final vendorName = (data['vendorName'] ?? '').toString().trim();
        templates.add(
          _DetailTemplateOption(
            id: id,
            name: name,
            vendorName: vendorName,
            data: data,
          ),
        );
      }

      if (!mounted) return;
      setState(() {
        _templates = templates;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(loc.commonErrorWithDetails(_error!)),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => _loadTemplates(),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_templates.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.find_in_page, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              loc.marketplaceNoDetailTemplatesYet,
              style: TextStyle(color: Colors.grey[600], fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              loc.marketplacePressPlusCreateDetailTemplate,
              style: TextStyle(color: Colors.grey[500], fontSize: 14),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadTemplates(),
      child: ListView.builder(
        itemCount: _templates.length,
        itemBuilder: (context, index) {
          final template = _templates[index];
          return _SiteDetailTemplateTile(
              docId: template.id, data: template.data);
        },
      ),
    );
  }
}

/// Single site detail template tile
class _SiteDetailTemplateTile extends StatelessWidget {
  final String docId;
  final Map<String, dynamic> data;

  const _SiteDetailTemplateTile({required this.docId, required this.data});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final name = data['name']?.toString() ?? loc.marketplaceUntitled;
    final vendorName = data['vendorName']?.toString() ?? '';
    final selectors = _asStringDynamicMap(data['selectors']);
    final selectorCount = selectors.values
        .where((v) => v != null && v.toString().isNotEmpty)
        .length;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.find_in_page, color: Colors.green),
        ),
        title: Text(name),
        subtitle: Text(
          vendorName.isNotEmpty
              ? '$vendorName \u2022 $selectorCount selectors'
              : '$selectorCount selectors configured',
          style: TextStyle(color: Colors.grey[600], fontSize: 12),
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (action) {
            if (action == 'edit') {
              showDialog(
                context: context,
                builder: (ctx) => _SiteDetailTemplateDialog(
                  templateId: docId,
                  initialData: data,
                ),
              );
            } else if (action == 'delete') {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: Text(loc.marketplaceDeleteTemplateTitle),
                  content: Text(loc.marketplaceDeleteTemplateConfirm(name)),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: Text(loc.commonCancel),
                    ),
                    TextButton(
                      onPressed: () async {
                        final callable =
                            FirebaseFunctions.instanceFor(region: 'us-central1')
                                .httpsCallable('deleteSiteDetailTemplate');
                        await callable.call({'templateId': docId});
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                      child: Text(loc.commonDelete,
                          style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              );
            }
          },
          itemBuilder: (ctx) => [
            PopupMenuItem(
              value: 'edit',
              child: Row(
                children: [
                  Icon(Icons.edit),
                  SizedBox(width: 8),
                  Text(loc.commonEdit),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete, color: Colors.red),
                  SizedBox(width: 8),
                  Text(loc.commonDelete,
                      style: const TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ===== Site Detail Template Dialog =====

enum _TemplateSetupStep { search, analyzing, review }

/// 3-step wizard to create/edit a site detail template
class _SiteDetailTemplateDialog extends StatefulWidget {
  final String? templateId;
  final Map<String, dynamic>? initialData;

  const _SiteDetailTemplateDialog({this.templateId, this.initialData});

  @override
  State<_SiteDetailTemplateDialog> createState() =>
      _SiteDetailTemplateDialogState();
}

class _SiteDetailTemplateDialogState extends State<_SiteDetailTemplateDialog> {
  final _formKey = GlobalKey<FormState>();
  final _templateNameController = TextEditingController();

  // Selector controllers
  final _descriptionController = TextEditingController();
  final _specsTableController = TextEditingController();
  final _sdsLinksController = TextEditingController();
  final _productSheetLinksController = TextEditingController();
  final _imageLinksController = TextEditingController();

  _TemplateSetupStep _currentStep = _TemplateSetupStep.search;
  bool _saving = false;
  bool _searching = false;
  bool _selectionPrompted = false;
  bool _selectingProduct = false;
  String? _error;
  bool _usesJavaScript = false;
  Map<String, double> _confidence = {};
  Map<String, dynamic> _sampleData = {};

  // Staged products & selection
  List<_StagedProductOption> _stagedProducts = [];
  String? _selectedStagedDocId;
  String? _selectedProductUrl;
  String? _selectedVendorId;
  String? _selectedVendorName;

  @override
  void initState() {
    super.initState();
    _loadStagedProducts();
    if (widget.initialData != null) {
      _loadExisting();
    }
  }

  void _loadExisting() {
    final d = widget.initialData!;
    _templateNameController.text = d['name']?.toString() ?? '';
    _selectedVendorId = d['vendorId']?.toString();
    _selectedVendorName = d['vendorName']?.toString();
    _selectedProductUrl = d['sampleProductUrl']?.toString();
    _usesJavaScript = d['usesJavaScript'] == true;

    final s = _asStringDynamicMap(d['selectors']);
    _descriptionController.text = s['description']?.toString() ?? '';
    _specsTableController.text = s['specsTable']?.toString() ?? '';
    _sdsLinksController.text = s['sdsLinks']?.toString() ?? '';
    _productSheetLinksController.text =
        s['productSheetLinks']?.toString() ?? '';
    _imageLinksController.text = s['imageLinks']?.toString() ?? '';

    final conf = _asStringDynamicMap(d['confidence']);
    _confidence = conf.map((k, v) => MapEntry(k, (v as num?)?.toDouble() ?? 0));
    _sampleData = _asStringDynamicMap(d['sampleData']);

    _currentStep = _TemplateSetupStep.review;
  }

  @override
  void dispose() {
    _templateNameController.dispose();
    _descriptionController.dispose();
    _specsTableController.dispose();
    _sdsLinksController.dispose();
    _productSheetLinksController.dispose();
    _imageLinksController.dispose();
    super.dispose();
  }

  Future<void> _loadStagedProducts() async {
    setState(() {
      _searching = true;
      _error = null;
    });

    try {
      final snap = await CatalogFirebaseService.instance.firestore
          .collection('stagedProduct')
          .where('status', isEqualTo: 'needs_review')
          .get();

      final options = <_StagedProductOption>[];
      for (final doc in snap.docs) {
        final option = _docToStagedOption(doc);
        if (option == null) continue;
        options.add(option);
      }

      options.sort((a, b) {
        final byName = a.name.toLowerCase().compareTo(b.name.toLowerCase());
        if (byName != 0) return byName;
        return a.id.compareTo(b.id);
      });

      if (!mounted) return;
      setState(() {
        _stagedProducts = options;
        _searching = false;
      });
      _maybePromptForProductSelection();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load staged products: $e';
        _searching = false;
      });
    }
  }

  String _extractSourceUrl(Map<String, dynamic> data) {
    final direct = (data['sourceUrl'] ?? '').toString().trim();
    if (direct.isNotEmpty) return direct;
    final raw = _asStringDynamicMap(data['rawData']);
    return (raw['sourceUrl'] ?? '').toString().trim();
  }

  _StagedProductOption? _docToStagedOption(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    final norm = _asStringDynamicMap(data['normalizedData']);
    final sourceUrl = _extractSourceUrl(data);
    if (sourceUrl.isEmpty) return null;

    final name = (norm['name'] ?? '').toString().trim();
    final vendorName = (norm['vendorName'] ?? '').toString().trim();
    final vendorId = (norm['vendorId'] ?? '').toString().trim();
    final productNumber = (norm['productNumber'] ?? '').toString().trim();
    final imageUrl =
        (norm['imageUrl'] ?? data['imageUrl'] ?? '').toString().trim();

    return _StagedProductOption(
      id: doc.id,
      name: name,
      vendorName: vendorName,
      vendorId: vendorId,
      productNumber: productNumber,
      sourceUrl: sourceUrl,
      imageUrl: imageUrl,
    );
  }

  _StagedProductOption? _selectedStagedOption() {
    final selectedId = _selectedStagedDocId;
    if (selectedId == null) return null;
    for (final option in _stagedProducts) {
      if (option.id == selectedId) return option;
    }
    return null;
  }

  void _selectProduct(_StagedProductOption option) {
    setState(() {
      _selectedStagedDocId = option.id;
      _selectedProductUrl = option.sourceUrl;
      _selectedVendorId = option.vendorId.isEmpty ? null : option.vendorId;
      _selectedVendorName =
          option.vendorName.isEmpty ? null : option.vendorName;
    });
  }

  void _maybePromptForProductSelection() {
    if (_selectionPrompted || widget.initialData != null) return;
    if (_currentStep != _TemplateSetupStep.search) return;
    if (_searching) return;
    if (_stagedProducts.isEmpty) return;

    _selectionPrompted = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await _promptForProductAndAnalyze(initialLaunch: true);
    });
  }

  Future<void> _promptForProductAndAnalyze({bool initialLaunch = false}) async {
    if (_selectingProduct || _searching || !mounted) return;

    setState(() {
      _selectingProduct = true;
      _error = null;
    });

    try {
      final selected = await _openStagedProductSelectDialog();
      if (!mounted) return;

      if (selected == null) {
        if (initialLaunch && _selectedStagedDocId == null) {
          Navigator.of(context).pop();
        }
        return;
      }

      _selectProduct(selected);
      await _startAnalysis();
    } finally {
      if (mounted) {
        setState(() => _selectingProduct = false);
      }
    }
  }

  Future<_StagedProductOption?> _openStagedProductSelectDialog() async {
    final loc = AppLocalizations.of(context)!;
    return showDialog<_StagedProductOption?>(
      context: context,
      builder: (dialogCtx) => DialogSelect<_StagedProductOption>(
        title: loc.marketplaceSearchStagedProducts,
        items: _stagedProducts,
        itemLabel: (item) {
          final itemName = item.name.isEmpty ? loc.commonUnknown : item.name;
          final productNumber = item.productNumber;
          final vendorName = item.vendorName;
          final details = <String>[
            if (vendorName.isNotEmpty) vendorName,
            if (productNumber.isNotEmpty) productNumber,
          ].join(' • ');
          if (details.isEmpty) return itemName;
          return '$itemName\n$details';
        },
        itemImageUrl: (item) => item.imageUrl.isEmpty ? null : item.imageUrl,
        itemSearchString: (item) =>
            '${item.name} ${item.productNumber} ${item.vendorName} ${item.sourceUrl}',
        initialSelection: _selectedStagedOption(),
        tileType: DialogSelectTileType.radio,
        radioControlAffinity: ListTileControlAffinity.trailing,
        searchLabelText: loc.marketplaceSearchStagedProducts,
        emptyStateText: loc.marketplaceNoStagedProductsMatchSearch,
        contentHeight: 520,
        onCancel: () => Navigator.of(dialogCtx).pop(),
        onSubmit: (result) => Navigator.of(dialogCtx).pop(result.firstOrNull),
      ),
    );
  }

  Future<void> _startAnalysis() async {
    if (_selectedProductUrl == null || _selectedProductUrl!.isEmpty) {
      setState(() => _error = 'Please search and select a staged product');
      return;
    }

    setState(() {
      _currentStep = _TemplateSetupStep.analyzing;
      _error = null;
    });

    try {
      final callable = FirebaseFunctions.instanceFor(region: 'us-central1')
          .httpsCallable('analyzeDetailPage');

      final result = await callable.call({
        'detailUrl': _selectedProductUrl,
        if (_selectedVendorName != null) 'vendorName': _selectedVendorName,
      });

      final data = Map<String, dynamic>.from(result.data as Map);

      if (data['success'] != true) {
        throw Exception(data['error'] ?? 'Analysis failed');
      }

      final selectors = data['selectors'] != null
          ? Map<String, dynamic>.from(data['selectors'] as Map)
          : <String, dynamic>{};

      _descriptionController.text = selectors['description']?.toString() ?? '';
      _specsTableController.text = selectors['specsTable']?.toString() ?? '';
      _sdsLinksController.text = selectors['sdsLinks']?.toString() ?? '';
      _productSheetLinksController.text =
          selectors['productSheetLinks']?.toString() ?? '';
      _imageLinksController.text = selectors['imageLinks']?.toString() ?? '';

      final conf = data['confidence'] != null
          ? Map<String, dynamic>.from(data['confidence'] as Map)
          : <String, dynamic>{};
      _confidence =
          conf.map((k, v) => MapEntry(k, (v as num?)?.toDouble() ?? 0));

      _sampleData = data['sampleData'] != null
          ? Map<String, dynamic>.from(data['sampleData'] as Map)
          : {};
      _usesJavaScript = data['usesJavaScript'] == true;
      if (_templateNameController.text.trim().isEmpty) {
        _templateNameController.text =
            (_selectedVendorName ?? 'Detail Template').trim();
      }

      setState(() => _currentStep = _TemplateSetupStep.review);
    } catch (e) {
      setState(() {
        _currentStep = _TemplateSetupStep.search;
        _error = 'Analysis failed: ${_formatError(e)}';
      });
    }
  }

  String _formatError(Object error) {
    if (error is FirebaseFunctionsException) {
      final parts = <String>[];
      if (error.code.isNotEmpty) parts.add(error.code);
      if (error.message?.isNotEmpty == true) parts.add(error.message!);
      if (parts.isNotEmpty) return parts.join(' | ');
    }
    return error.toString().replaceAll('Exception: ', '');
  }

  Future<void> _save() async {
    final loc = AppLocalizations.of(context)!;
    if (_saving) return;
    if (_templateNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a template name')),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      final callable = FirebaseFunctions.instanceFor(region: 'us-central1')
          .httpsCallable('saveSiteDetailTemplate');

      final payload = <String, dynamic>{
        'name': _templateNameController.text.trim(),
        'selectors': {
          'description': _descriptionController.text.trim(),
          'specsTable': _specsTableController.text.trim(),
          'sdsLinks': _sdsLinksController.text.trim(),
          'productSheetLinks': _productSheetLinksController.text.trim(),
          'imageLinks': _imageLinksController.text.trim(),
        },
        'vendorId': _selectedVendorId,
        'vendorName': _selectedVendorName,
        'usesJavaScript': _usesJavaScript,
        'sampleProductUrl': _selectedProductUrl,
        'confidence': _confidence,
        'sampleData': _sampleData,
      };

      if (widget.templateId != null) {
        payload['templateId'] = widget.templateId;
      }

      await callable.call(payload);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(loc.marketplaceDetailTemplateSaved)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(loc.marketplaceActionFailed(e.toString()))),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final bool showAction = _currentStep == _TemplateSetupStep.review;
    final String actionText =
        _saving ? loc.marketplaceSaving : loc.marketplaceSaveTemplate;
    final VoidCallback? onAction = _saving ? null : _save;

    return DialogAction(
      title: widget.templateId != null
          ? loc.marketplaceEditDetailTemplate
          : loc.marketplaceNewDetailTemplate,
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 750),
        child: Form(
          key: _formKey,
          child: _buildStepContent(),
        ),
      ),
      cancelText: loc.commonCancel,
      onCancel: () => Navigator.pop(context),
      actionText: actionText,
      onAction: onAction,
      showActionButton: showAction,
      wrapContentInScrollView: false,
    );
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case _TemplateSetupStep.search:
        return _buildSearchStep();
      case _TemplateSetupStep.analyzing:
        return _buildAnalyzingStep();
      case _TemplateSetupStep.review:
        return _buildReviewStep();
    }
  }

  Widget _buildSearchStep() {
    final loc = AppLocalizations.of(context)!;
    final bool hasSelection =
        (_selectedProductUrl != null) && _selectedProductUrl!.isNotEmpty;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_searching || _selectingProduct)
              const SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(strokeWidth: 3),
              ),
            if (_searching || _selectingProduct) const SizedBox(height: 16),
            if (_searching)
              const Text(
                'Loading staged products...',
                textAlign: TextAlign.center,
              )
            else if (_selectingProduct)
              Text(
                loc.marketplaceSearchStagedProducts,
                textAlign: TextAlign.center,
              )
            else
              OutlinedButton.icon(
                onPressed: _stagedProducts.isEmpty
                    ? null
                    : () => _promptForProductAndAnalyze(),
                icon: const Icon(Icons.search),
                label: Text(loc.marketplaceSearchStagedProducts),
              ),
            if (hasSelection) ...[
              const SizedBox(height: 12),
              Text(
                loc.marketplaceSelectedVendorAndUrl(
                  _selectedVendorName ?? loc.commonUnknown,
                  _selectedProductUrl ?? '',
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: TextStyle(color: Colors.red[700], fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
            if (!_searching &&
                !_selectingProduct &&
                _stagedProducts.isEmpty) ...[
              const SizedBox(height: 12),
              Text(
                loc.marketplaceNoStagedProductsFound,
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAnalyzingStep() {
    final loc = AppLocalizations.of(context)!;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 64,
            height: 64,
            child: CircularProgressIndicator(strokeWidth: 3),
          ),
          const SizedBox(height: 32),
          Text(
            loc.marketplaceAnalyzingDetailPage,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          Text(
            loc.marketplaceDetectingDescriptionSpecsUpc,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildReviewStep() {
    final loc = AppLocalizations.of(context)!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            controller: _templateNameController,
            decoration: InputDecoration(
              labelText: loc.marketplaceTemplateNameRequired,
              hintText: loc.marketplaceTemplateNameHint,
              border: const OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 12),
          Text(loc.commonDetails,
              style: Theme.of(context).textTheme.titleSmall),
          if (_usesJavaScript) ...[
            const SizedBox(height: 6),
            Text(
              loc.marketplaceJavascriptDetectedForSite,
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ],
          const SizedBox(height: 12),
          _buildSelectorField(
            loc.marketplaceDescriptionSelector,
            _descriptionController,
            _confidence['description'] ?? 0,
          ),
          const SizedBox(height: 8),
          _buildDetailEvidenceCard(
            title: loc.commonDescription,
            extractedValue: _sampleData['description']?.toString(),
            selector: _descriptionController.text.trim(),
            confidence: _confidence['description'] ?? 0,
          ),
          const SizedBox(height: 12),
          _buildSelectorField(
            loc.marketplaceSpecsTableSelector,
            _specsTableController,
            _confidence['specsTable'] ?? 0,
          ),
          const SizedBox(height: 8),
          _buildDetailEvidenceCard(
            title: loc.marketplaceUpc,
            extractedValue: _sampleData['upc']?.toString(),
            selector: _specsTableController.text.trim(),
            confidence: _confidence['specsTable'] ?? 0,
          ),
          const SizedBox(height: 8),
          _buildDetailEvidenceCard(
            title: loc.marketplaceUnitSize,
            extractedValue: _sampleData['unitSize']?.toString(),
            selector: _specsTableController.text.trim(),
            confidence: _confidence['specsTable'] ?? 0,
          ),
          const SizedBox(height: 8),
          _buildDetailEvidenceCard(
            title: loc.marketplaceUnitOfMeasure,
            extractedValue: _sampleData['unitOfMeasure']?.toString(),
            selector: _specsTableController.text.trim(),
            confidence: _confidence['specsTable'] ?? 0,
          ),
          const SizedBox(height: 20),

          Text(loc.marketplaceSpecsSelectorHelp,
              style: TextStyle(color: Colors.grey[600], fontSize: 12)),
          const SizedBox(height: 20),

          Text(loc.marketplaceDownloadLinksTitle,
              style: Theme.of(context).textTheme.titleSmall),
          Text(
            loc.marketplaceDownloadLinksHelp,
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
          ),
          const SizedBox(height: 8),
          _buildSelectorField(loc.marketplaceSdsLinks, _sdsLinksController,
              _confidence['sdsLinks'] ?? 0),
          if ((_sampleData['sdsLinks']?.toString().trim().isNotEmpty ?? false))
            _buildSampleHint(_sampleData['sdsLinks'].toString()),
          const SizedBox(height: 12),
          _buildSelectorField(
              loc.marketplaceProductSheetLinks,
              _productSheetLinksController,
              _confidence['productSheetLinks'] ?? 0),
          if ((_sampleData['productSheetLinks']?.toString().trim().isNotEmpty ??
              false))
            _buildSampleHint(_sampleData['productSheetLinks'].toString()),
          const SizedBox(height: 12),
          _buildSelectorField(loc.marketplaceImageLinks, _imageLinksController,
              _confidence['imageLinks'] ?? 0),
          if ((_sampleData['imageLinks']?.toString().trim().isNotEmpty ??
              false))
            _buildSampleHint(_sampleData['imageLinks'].toString()),
          const SizedBox(height: 20),

          // Re-analyze button
          Center(
            child: OutlinedButton.icon(
              onPressed: () async {
                setState(() {
                  _currentStep = _TemplateSetupStep.search;
                  _sampleData = {};
                  _confidence = {};
                });
                await _promptForProductAndAnalyze();
              },
              icon: const Icon(Icons.refresh, size: 18),
              label: Text(loc.marketplaceReanalyze),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectorField(
      String label, TextEditingController controller, double confidence) {
    final loc = AppLocalizations.of(context)!;
    final color = confidence >= 0.7
        ? Colors.green
        : confidence >= 0.4
            ? Colors.orange
            : Colors.grey;

    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        suffixIcon: confidence > 0
            ? Tooltip(
                message: loc.marketplaceConfidenceTooltip(
                  (confidence * 100).toInt(),
                ),
                child: Icon(
                  confidence >= 0.7
                      ? Icons.check_circle
                      : confidence >= 0.4
                          ? Icons.help
                          : Icons.help_outline,
                  color: color,
                  size: 20,
                ),
              )
            : null,
      ),
      style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
    );
  }

  Widget _buildDetailEvidenceCard({
    required String title,
    required String? extractedValue,
    required String selector,
    required double confidence,
  }) {
    final loc = AppLocalizations.of(context)!;
    final trimmedValue = extractedValue?.trim();
    final hasValue = trimmedValue?.isNotEmpty ?? false;
    final displayedValue =
        hasValue ? trimmedValue! : loc.marketplaceNoSampleValueDetected;
    final confidenceColor = confidence >= 0.7
        ? Colors.green
        : confidence >= 0.4
            ? Colors.orange
            : Colors.grey;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 8),
              if (confidence > 0)
                Text(
                  '${(confidence * 100).toInt()}%',
                  style: TextStyle(
                    fontSize: 12,
                    color: confidenceColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            displayedValue,
            style: TextStyle(
              fontSize: 12,
              color: hasValue ? Colors.black87 : Colors.grey[600],
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          Text(
            loc.marketplaceFoundWithSelector(
              selector.isEmpty ? loc.marketplaceNotDetected : selector,
            ),
            style: TextStyle(color: Colors.grey[700], fontSize: 12),
          ),
          if ((_selectedProductUrl ?? '').isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              loc.marketplacePageWithUrl(_selectedProductUrl!),
              style: TextStyle(color: Colors.grey[700], fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSampleHint(String sampleText) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(
        sampleText,
        style: TextStyle(color: Colors.grey[600], fontSize: 12),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

// ===== Detail Jobs Tab =====

/// List of detail scrape jobs
class _DetailJobsList extends StatefulWidget {
  const _DetailJobsList();

  @override
  State<_DetailJobsList> createState() => _DetailJobsListState();
}

class _DetailJobsListState extends State<_DetailJobsList> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _jobs = [];
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _loadJobs();
    _pollTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _loadJobs(silent: true),
    );
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadJobs({bool silent = false}) async {
    if (!silent && mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final callable = FirebaseFunctions.instanceFor(region: 'us-central1')
          .httpsCallable('getDetailScrapeJobs');
      final result = await callable.call({'limit': 50});
      final payload = Map<String, dynamic>.from(result.data as Map);
      final rawJobs = payload['jobs'] as List<dynamic>? ?? const [];
      final jobs = <Map<String, dynamic>>[];
      for (final raw in rawJobs) {
        if (raw is! Map) continue;
        jobs.add(Map<String, dynamic>.from(raw));
      }

      if (!mounted) return;
      setState(() {
        _jobs = jobs;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(loc.commonErrorWithDetails(_error!)),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => _loadJobs(),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_jobs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.find_in_page, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              loc.marketplaceNoDetailExtractionJobsYet,
              style: TextStyle(color: Colors.grey[600], fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              loc.marketplaceConfigureDetailSelectorsFirst,
              style: TextStyle(color: Colors.grey[500], fontSize: 14),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadJobs(),
      child: ListView.builder(
        itemCount: _jobs.length,
        itemBuilder: (context, index) {
          final data = _jobs[index];
          final id = (data['id'] ?? '').toString();
          return _DetailJobTile(docId: id, data: data);
        },
      ),
    );
  }
}

/// Single detail job tile
class _DetailJobTile extends StatelessWidget {
  final String docId;
  final Map<String, dynamic> data;

  const _DetailJobTile({required this.docId, required this.data});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final vendorName =
        data['vendorName']?.toString() ?? loc.marketplaceUnknownVendor;
    final status = data['status']?.toString() ?? 'unknown';
    final progress = _asStringDynamicMap(data['progress']);
    final itemsTotal = progress['itemsTotal'] ?? 0;
    final itemsProcessed = progress['itemsProcessed'] ?? 0;
    final itemsSucceeded = progress['itemsSucceeded'] ?? 0;
    final itemsFailed = progress['itemsFailed'] ?? 0;

    Color statusColor;
    IconData statusIcon;
    switch (status) {
      case 'queued':
        statusColor = Colors.grey;
        statusIcon = Icons.schedule;
        break;
      case 'running':
        statusColor = Colors.blue;
        statusIcon = Icons.sync;
        break;
      case 'completed':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case 'failed':
        statusColor = Colors.red;
        statusIcon = Icons.error;
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.help_outline;
    }

    final double progressFraction =
        itemsTotal > 0 ? (itemsProcessed / itemsTotal).clamp(0.0, 1.0) : 0.0;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(statusIcon, color: statusColor, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        vendorName,
                        style: const TextStyle(
                            fontWeight: FontWeight.w500, fontSize: 15),
                      ),
                      Text(
                        loc.marketplaceDetailExtraction,
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Chip(
                  label: Text(
                    status.toUpperCase(),
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  backgroundColor: statusColor.withValues(alpha: 0.1),
                  side: BorderSide.none,
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _StatChip(
                    icon: Icons.article,
                    label: loc.marketplaceTotalLabel,
                    statValue: '$itemsTotal'),
                const SizedBox(width: 12),
                _StatChip(
                    icon: Icons.check,
                    label: loc.marketplaceOkLabel,
                    statValue: '$itemsSucceeded'),
                const SizedBox(width: 12),
                _StatChip(
                    icon: Icons.close,
                    label: loc.marketplaceFailedLabel,
                    statValue: '$itemsFailed'),
              ],
            ),
            if (status == 'running') ...[
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: progressFraction > 0 ? progressFraction : null,
                backgroundColor: Colors.grey[200],
                valueColor: AlwaysStoppedAnimation(statusColor),
              ),
              const SizedBox(height: 4),
              Text(
                loc.marketplaceItemsProcessedProgress(
                  itemsProcessed,
                  itemsTotal,
                ),
                style: TextStyle(color: Colors.grey[600], fontSize: 11),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Dialog to create a new detail extraction job
class _CreateDetailJobDialog extends StatefulWidget {
  const _CreateDetailJobDialog();

  @override
  State<_CreateDetailJobDialog> createState() => _CreateDetailJobDialogState();
}

class _CreateDetailJobDialogState extends State<_CreateDetailJobDialog> {
  static const Set<String> _retryableFunctionCodes = <String>{
    'unavailable',
    'deadline-exceeded',
    'aborted',
    'resource-exhausted',
    'internal',
  };

  String? _selectedTemplateId;
  bool _loading = true;
  bool _creating = false;
  List<_DetailTemplateOption> _templates = [];

  @override
  void initState() {
    super.initState();
    _loadTemplates();
  }

  Future<void> _loadTemplates() async {
    try {
      final result = await _callCallableWithRetry(
        functionName: 'getSiteDetailTemplates',
        payload: {'limit': 200},
        timeout: const Duration(seconds: 30),
        maxAttempts: 3,
      );
      final payload = Map<String, dynamic>.from(result.data as Map);
      final rawTemplates = payload['templates'] as List<dynamic>? ?? const [];
      final templates = <_DetailTemplateOption>[];
      for (final raw in rawTemplates) {
        if (raw is! Map) continue;
        final data = Map<String, dynamic>.from(raw);
        final id = (data['id'] ?? '').toString().trim();
        if (id.isEmpty) continue;
        final name = (data['name'] ?? '').toString().trim();
        final vendorName = (data['vendorName'] ?? '').toString().trim();
        templates.add(
          _DetailTemplateOption(
            id: id,
            name: name,
            vendorName: vendorName,
            data: data,
          ),
        );
      }
      templates
          .sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

      if (!mounted) return;
      setState(() {
        _templates = templates;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _templates = [];
        _loading = false;
      });
    }
  }

  Future<HttpsCallableResult<dynamic>> _callCallableWithRetry({
    required String functionName,
    required Map<String, dynamic> payload,
    Duration timeout = const Duration(seconds: 30),
    int maxAttempts = 3,
  }) async {
    final callable =
        FirebaseFunctions.instanceFor(region: 'us-central1').httpsCallable(
      functionName,
      options: HttpsCallableOptions(timeout: timeout),
    );
    Object? lastError;
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        return await callable.call(payload);
      } on FirebaseFunctionsException catch (e) {
        lastError = e;
        if (!_isRetryableFunctionsError(e) || attempt >= maxAttempts) rethrow;
      } on TimeoutException catch (e) {
        lastError = e;
        if (attempt >= maxAttempts) rethrow;
      }

      await Future.delayed(Duration(milliseconds: 500 * attempt));
    }

    throw lastError ?? StateError('Callable failed: $functionName');
  }

  bool _isRetryableFunctionsError(FirebaseFunctionsException error) {
    final code = error.code.toLowerCase().trim();
    if (_retryableFunctionCodes.contains(code)) return true;
    final message = (error.message ?? '').toLowerCase();
    return message.contains('no available instance') ||
        message.contains('cpu_allocation') ||
        message.contains('temporarily unavailable');
  }

  String _buildCreateDetailRequestId(String templateId) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? 'anon';
    final ts = DateTime.now().microsecondsSinceEpoch;
    return 'detail-$uid-$templateId-$ts';
  }

  String _formatFunctionsError(Object error) {
    if (error is FirebaseFunctionsException) {
      final code = error.code.trim();
      final message = (error.message ?? '').trim();
      if (code == 'unavailable' || code == 'resource-exhausted') {
        return 'Service temporarily unavailable. Please try again.';
      }
      final parts = <String>[];
      if (code.isNotEmpty) parts.add(code);
      if (message.isNotEmpty) parts.add(message);
      if (parts.isNotEmpty) return parts.join(' | ');
      return code.isNotEmpty ? code : 'Cloud Function failed';
    }
    return error.toString().replaceAll('Exception: ', '').split('\n').first;
  }

  Future<void> _create() async {
    final loc = AppLocalizations.of(context)!;
    if (_selectedTemplateId == null || _creating) return;

    setState(() => _creating = true);

    try {
      final requestId = _buildCreateDetailRequestId(_selectedTemplateId!);
      final result = await _callCallableWithRetry(
        functionName: 'createDetailScrapeJob',
        payload: {
          'templateId': _selectedTemplateId,
          'requestId': requestId,
        },
        timeout: const Duration(seconds: 45),
        maxAttempts: 3,
      );

      final data = Map<String, dynamic>.from(result.data as Map);
      final eligibleCount = data['eligibleCount'] ?? 0;

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
            loc.marketplaceDetailJobCreatedForItems(eligibleCount),
          )),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text(loc.marketplaceActionFailed(_formatFunctionsError(e))),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return DialogAction(
      title: loc.marketplaceCreateDetailExtractionJobTitle,
      cancelText: loc.commonCancel,
      onCancel: () => Navigator.pop(context),
      actionText:
          _creating ? loc.marketplaceCreating : loc.marketplaceCreateJob,
      onAction: _selectedTemplateId == null ||
              _creating ||
              _loading ||
              _templates.isEmpty
          ? null
          : _create,
      content: _loading
          ? const SizedBox(
              height: 100,
              child: Center(child: CircularProgressIndicator()),
            )
          : _templates.isEmpty
              ? Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    loc.marketplaceNoDetailTemplatesFoundCreateInDetails,
                  ),
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: _selectedTemplateId,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: loc.marketplaceDetailTemplateLabel,
                        border: OutlineInputBorder(),
                      ),
                      selectedItemBuilder: (context) {
                        return _templates.map((template) {
                          final name = template.name.isNotEmpty
                              ? template.name
                              : loc.marketplaceUntitled;
                          final vendor = template.vendorName;
                          final label =
                              vendor.isNotEmpty ? '$name ($vendor)' : name;
                          return Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList();
                      },
                      items: _templates.map((template) {
                        final name = template.name.isNotEmpty
                            ? template.name
                            : loc.marketplaceUntitled;
                        final vendor = template.vendorName;
                        final label =
                            vendor.isNotEmpty ? '$name ($vendor)' : name;
                        return DropdownMenuItem(
                          value: template.id,
                          child: Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (v) => setState(() => _selectedTemplateId = v),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue[200]!),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline,
                              color: Colors.blue[700], size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              loc.marketplaceDetailExtractionJobHelp,
                              style: TextStyle(
                                  color: Colors.blue[700], fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }
}

/// Tap-to-open read-only field used in place of a DropdownButtonFormField
/// for single-select brand / brand owner pickers. Renders like a standard
/// form field so the layout matches the surrounding inputs, but tapping
/// launches a DialogSelect (radio mode) instead of a native dropdown.
class _BrandPickerField extends StatelessWidget {
  final String label;
  final String? selectedName;
  final bool loading;
  final VoidCallback? onTap;

  const _BrandPickerField({
    required this.label,
    required this.selectedName,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final display =
        (selectedName == null || selectedName!.trim().isEmpty)
            ? (loading ? 'Loading…' : 'Select $label')
            : selectedName!.trim();
    final isPlaceholder =
        (selectedName == null || selectedName!.trim().isEmpty);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          suffixIcon:
              loading ? null : const Icon(Icons.arrow_drop_down),
        ),
        child: Text(
          display,
          style: TextStyle(
            color: isPlaceholder
                ? Theme.of(context).hintColor
                : Theme.of(context).textTheme.bodyLarge?.color,
          ),
        ),
      ),
    );
  }
}
