// marketplace_staging_review.dart

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:shared_widgets/search/search_control_strip.dart';
import 'package:shared_widgets/services/catalog_firebase_service.dart';
import 'package:kleenops_admin/features/catalog/details/marketplace_staging_review_details.dart';
import 'package:shared_widgets/dialogs/dialog_action.dart';
import 'package:shared_widgets/tiles/standard_tile_large.dart';
import 'package:shared_widgets/buttons/cancel_save.dart';
import 'package:shared_widgets/tabs/standard_tab.dart';
import 'package:shared_widgets/lists/standardView.dart';
import 'package:kleenops_admin/l10n/app_localizations.dart';

/// Displays staged products that need review before being added to the catalog.
class StagingReviewScreen extends ConsumerStatefulWidget {
  const StagingReviewScreen({super.key});

  @override
  ConsumerState<StagingReviewScreen> createState() =>
      _StagingReviewScreenState();
}

class _StagingReviewScreenState extends ConsumerState<StagingReviewScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  bool _bulkApproving = false;
  final Set<String> _excludedDocIds = {};
  bool _saving = false;
  List<String> _currentNeedsReviewDocIds = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _bulkApprove() async {
    final loc = AppLocalizations.of(context)!;
    if (_bulkApproving) return;
    setState(() => _bulkApproving = true);

    try {
      final callable = FirebaseFunctions.instanceFor(region: 'us-central1')
          .httpsCallable('bulkApproveStaged');
      final result = await callable.call({'autoApproveOnly': true});
      final data = result.data as Map<String, dynamic>?;

      if (mounted) {
        final processed = data?['processed'] ?? 0;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(loc.marketplaceApprovedItems(processed))),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(loc.marketplaceBulkApproveFailed(e.toString()))),
        );
      }
    } finally {
      if (mounted) setState(() => _bulkApproving = false);
    }
  }

  Future<void> _saveNeedsReview(List<String> docIds) async {
    final loc = AppLocalizations.of(context)!;
    if (_saving) return;

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => DialogAction(
        title: loc.marketplaceSaveChangesTitle,
        content: Text(loc.marketplaceApproveItemCount(docIds.length)),
        cancelText: loc.commonCancel,
        onCancel: () => Navigator.pop(ctx, false),
        actionText: loc.commonSave,
        onAction: () => Navigator.pop(ctx, true),
      ),
    );

    if (confirmed != true) return;

    setState(() => _saving = true);

    try {
      for (final docId in docIds) {
        final callable = FirebaseFunctions.instanceFor(region: 'us-central1')
            .httpsCallable('approveStagedProduct');
        await callable.call({'stagedId': docId});
      }

      if (mounted) {
        setState(() => _excludedDocIds.clear());
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(loc.marketplaceApprovedItems(docIds.length))),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(loc.marketplaceSaveFailed(e.toString()))),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _toggleExcluded(String docId) {
    setState(() {
      if (_excludedDocIds.contains(docId)) {
        _excludedDocIds.remove(docId);
      } else {
        _excludedDocIds.add(docId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final isNeedsReview = _tabController.index == 0;

    return Scaffold(
      appBar: null,
      body: Column(
        children: [
          Container(
            color: Colors.white,
            child: StandardTabBar(
              controller: _tabController,
              isScrollable: false,
              dividerColor: Colors.grey[300],
              indicatorColor: Theme.of(context).primaryColor,
              indicatorWeight: 3.0,
              labelColor: Colors.black,
              unselectedLabelColor: Colors.grey[600],
              tabs: [
                Tab(text: loc.marketplaceNeedsReviewTab),
                Tab(text: loc.marketplaceAutoApprovedTab),
                Tab(text: loc.marketplaceProcessedTab),
              ],
            ),
          ),
          SearchControlStrip(
            controller: _searchController,
            hintText: loc.marketplaceSearchStagedItems,
            onChanged: (val) => setState(() => searchQuery = val),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _StagedProductList(
                  status: 'needs_review',
                  searchQuery: searchQuery,
                  showActions: true,
                  useNewDesign: true,
                  excludedDocIds: _excludedDocIds,
                  onToggleExcluded: _toggleExcluded,
                  onDocIdsChanged: (docIds) {
                    _currentNeedsReviewDocIds = docIds;
                  },
                ),
                _StagedProductList(
                  status: 'auto_approved',
                  searchQuery: searchQuery,
                  showActions: true,
                  onBulkApprove: _bulkApprove,
                  bulkApproving: _bulkApproving,
                ),
                _StagedProductList(
                  status: 'approved',
                  searchQuery: searchQuery,
                  showActions: false,
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: isNeedsReview
          ? CancelSave(
              onCancel: () {
                setState(() => _excludedDocIds.clear());
              },
              onSave: () {
                _handleSaveFromBottomNav();
              },
            )
          : null,
    );
  }

  void _handleSaveFromBottomNav() {
    final loc = AppLocalizations.of(context)!;
    final docsToSave = _currentNeedsReviewDocIds
        .where((id) => !_excludedDocIds.contains(id))
        .toList();

    if (docsToSave.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.marketplaceNoItemsToSave)),
      );
      return;
    }

    _saveNeedsReview(docsToSave);
  }
}

class _StagedProductList extends StatefulWidget {
  final String status;
  final String searchQuery;
  final bool showActions;
  final VoidCallback? onBulkApprove;
  final bool bulkApproving;
  final bool useNewDesign;
  final Set<String>? excludedDocIds;
  final void Function(String docId)? onToggleExcluded;
  final void Function(List<String> docIds)? onDocIdsChanged;

  const _StagedProductList({
    required this.status,
    required this.searchQuery,
    this.showActions = false,
    this.onBulkApprove,
    this.bulkApproving = false,
    this.useNewDesign = false,
    this.excludedDocIds,
    this.onToggleExcluded,
    this.onDocIdsChanged,
  });

  @override
  State<_StagedProductList> createState() => _StagedProductListState();
}

class _StagedProductListState extends State<_StagedProductList> {
  List<String> _previousDocIds = [];
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> _allLoadedDocs = [];
  bool _initialLoadDone = false;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void didUpdateWidget(_StagedProductList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.status != widget.status) {
      _resetAndReload();
    }
  }

  void _resetAndReload() {
    setState(() {
      _allLoadedDocs.clear();
      _initialLoadDone = false;
    });
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    final query = CatalogFirebaseService.instance.firestore
        .collection('stagedProduct')
        .where('status', isEqualTo: widget.status);

    try {
      final snapshot = await query.get();
      if (!mounted) return;
      setState(() {
        _allLoadedDocs
          ..clear()
          ..addAll(snapshot.docs);
        _initialLoadDone = true;
      });
      _notifyDocIds();
    } catch (e) {
      if (!mounted) return;
      setState(() => _initialLoadDone = true);
    }
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> get _allDocs {
    final docs = List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(
      _allLoadedDocs,
    );
    docs.sort((a, b) {
      final aNormalized =
          a.data()['normalizedData'] as Map<String, dynamic>? ?? {};
      final bNormalized =
          b.data()['normalizedData'] as Map<String, dynamic>? ?? {};
      final aName = (aNormalized['name'] ?? '').toString().trim().toLowerCase();
      final bName = (bNormalized['name'] ?? '').toString().trim().toLowerCase();
      return aName.compareTo(bName);
    });
    return docs;
  }

  void _notifyDocIds() {
    final filteredDocs = _getFilteredDocs();
    final newDocIds = filteredDocs.map((doc) => doc.id).toList();
    if (widget.onDocIdsChanged != null &&
        !listEquals(newDocIds, _previousDocIds)) {
      _previousDocIds = newDocIds;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onDocIdsChanged!(newDocIds);
      });
    }
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _getFilteredDocs() {
    final searchLower = widget.searchQuery.toLowerCase();
    return _allDocs.where((doc) {
      final data = doc.data();
      final normalized = data['normalizedData'] as Map<String, dynamic>? ?? {};
      final name = (normalized['name'] ?? '').toString().toLowerCase();
      final productNumber =
          (normalized['productNumber'] ?? '').toString().toLowerCase();
      return name.contains(searchLower) || productNumber.contains(searchLower);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    if (!_initialLoadDone) {
      return const Center(child: CircularProgressIndicator());
    }

    final filteredDocs = _getFilteredDocs();
    if (filteredDocs.isEmpty) {
      final isSearching = widget.searchQuery.isNotEmpty;
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSearching
                  ? Icons.search_off
                  : widget.status == 'needs_review'
                      ? Icons.check_circle_outline
                      : Icons.inbox_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              isSearching
                  ? loc.marketplaceNoItemsMatch(widget.searchQuery)
                  : widget.status == 'needs_review'
                      ? loc.marketplaceNoItemsNeedReview
                      : loc.marketplaceNoItemsInCategory,
              style: TextStyle(color: Colors.grey[600], fontSize: 16),
            ),
          ],
        ),
      );
    }

    if (widget.useNewDesign) {
      return Column(
        children: [
          Expanded(
            child: StandardView<QueryDocumentSnapshot<Map<String, dynamic>>>(
              items: filteredDocs,
              groupBy: (_) => '',
              disableGrouping: true,
              showDividersInFlat: true,
              enableReorder: false,
              itemBuilder: (doc) {
                final data = doc.data();
                final normalized =
                    data['normalizedData'] as Map<String, dynamic>? ?? {};
                final rawData = data['rawData'] as Map<String, dynamic>? ?? {};
                final name = normalized['name']?.toString() ?? loc.commonUnnamed;
                final imageUrl = normalized['imageUrl']?.toString() ??
                    rawData['imageUrl']?.toString() ??
                    '';
                final isExcluded =
                    widget.excludedDocIds?.contains(doc.id) ?? false;

                // Show the two fields the reviewer cares about most in the
                // list: suggested category + suggested usage (scalar).
                final suggestedCategory =
                    (data['suggestedCategoryKey'] ?? '').toString();
                final suggestedScalar =
                    (data['suggestedScalarKey'] ?? '').toString();

                return InkWell(
                  onTap: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => MarketplaceStagingReviewDetailsScreen(
                          docId: doc.id,
                          initialData: data,
                        ),
                      ),
                    );
                  },
                  child: StandardTileLargeDart(
                    imageUrl: imageUrl,
                    firstLine: name,
                    secondLine: suggestedCategory.isNotEmpty
                        ? suggestedCategory
                        : 'No category',
                    secondLineIcon: suggestedCategory.isNotEmpty
                        ? Icons.category_outlined
                        : Icons.help_outline,
                    thirdLine: suggestedScalar.isNotEmpty
                        ? 'Usage: $suggestedScalar'
                        : 'Usage: Not set',
                    thirdLineIcon: Icons.straighten,
                    trailingIcon1: Icons.close,
                    trailingAction1: () =>
                        widget.onToggleExcluded?.call(doc.id),
                    showImage: true,
                    showBorder: isExcluded,
                    borderColor: Colors.red,
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Center(
              child: Text(
                widget.searchQuery.isNotEmpty
                    ? loc.marketplaceItemsFound(filteredDocs.length)
                    : loc.marketplaceItemsTotal(filteredDocs.length),
                style: TextStyle(color: Colors.grey[600]),
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        if (widget.onBulkApprove != null && filteredDocs.isNotEmpty)
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: ElevatedButton.icon(
              onPressed: widget.bulkApproving ? null : widget.onBulkApprove,
              icon: widget.bulkApproving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check_circle),
              label: Text(loc.marketplaceApproveAllItems(filteredDocs.length)),
            ),
          ),
        Expanded(
          child: ListView.builder(
            itemCount: filteredDocs.length,
            itemBuilder: (context, index) {
              final doc = filteredDocs[index];
              return _StagedProductTile(
                docId: doc.id,
                data: doc.data(),
                showActions: widget.showActions,
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Center(
            child: Text(
              widget.searchQuery.isNotEmpty
                  ? loc.marketplaceItemsFound(filteredDocs.length)
                  : loc.marketplaceItemsTotal(filteredDocs.length),
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
        ),
      ],
    );
  }
}

class _StagedProductTile extends StatefulWidget {
  final String docId;
  final Map<String, dynamic> data;
  final bool showActions;

  const _StagedProductTile({
    required this.docId,
    required this.data,
    this.showActions = false,
  });

  @override
  State<_StagedProductTile> createState() => _StagedProductTileState();
}

class _StagedProductTileState extends State<_StagedProductTile> {
  bool _processing = false;

  Map<String, dynamic> get _normalized =>
      widget.data['normalizedData'] as Map<String, dynamic>? ?? {};

  Map<String, dynamic> get _matchResults =>
      widget.data['matchResults'] as Map<String, dynamic>? ?? {};

  String get _status => widget.data['status']?.toString() ?? 'pending';

  Future<void> _approve() async {
    final loc = AppLocalizations.of(context)!;
    if (_processing) return;
    setState(() => _processing = true);

    try {
      final callable = FirebaseFunctions.instanceFor(region: 'us-central1')
          .httpsCallable('approveStagedProduct');
      await callable.call({'stagedId': widget.docId});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(loc.marketplaceApproved)),
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

  Future<void> _reject() async {
    final loc = AppLocalizations.of(context)!;
    if (_processing) return;

    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => _RejectReasonDialog(),
    );

    if (reason == null) return;

    setState(() => _processing = true);
    try {
      final callable = FirebaseFunctions.instanceFor(region: 'us-central1')
          .httpsCallable('rejectStagedProduct');
      await callable.call({'stagedId': widget.docId, 'reason': reason});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(loc.marketplaceRejected)),
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

  Future<void> _viewDetails() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MarketplaceStagingReviewDetailsScreen(
          docId: widget.docId,
          initialData: widget.data,
        ),
      ),
    );
  }

  Color _getStatusColor() {
    switch (_status) {
      case 'auto_approved':
        return Colors.green;
      case 'needs_review':
        return Colors.orange;
      case 'approved':
        return Colors.blue;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon() {
    switch (_status) {
      case 'auto_approved':
        return Icons.auto_awesome;
      case 'needs_review':
        return Icons.pending_actions;
      case 'approved':
        return Icons.check_circle;
      case 'rejected':
        return Icons.cancel;
      default:
        return Icons.help_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final name = _normalized['name']?.toString() ?? loc.commonUnnamed;
    final productNumber = _normalized['productNumber']?.toString() ?? '';
    final brandName = _normalized['brandName']?.toString() ?? '';
    final hasMatch = _matchResults['exactMatch'] != null;
    final matchStrategy = _matchResults['matchStrategy']?.toString() ?? 'none';
    final matchScore =
        ((_matchResults['matchScore'] as num?)?.toDouble() ?? 0) * 100;
    final isNew = _matchResults['isNewProduct'] == true;

    final secondLine = productNumber.isNotEmpty
        ? productNumber
        : brandName.isNotEmpty
            ? brandName
            : '';

    String thirdLine;
    if (hasMatch) {
      thirdLine = loc.marketplaceMatchWithScore(
        matchStrategy,
        matchScore.toStringAsFixed(0),
      );
    } else if (isNew) {
      thirdLine = loc.marketplaceNewProduct;
    } else {
      thirdLine = loc.marketplaceNoMatchFound;
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: InkWell(
        onTap: _viewDetails,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Status indicator
              Container(
                width: 40,
                height: 40,
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
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 15,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (secondLine.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        secondLine,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(
                          hasMatch ? Icons.link : Icons.add_circle_outline,
                          size: 14,
                          color: hasMatch ? Colors.green : Colors.orange,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          thirdLine,
                          style: TextStyle(
                            color: hasMatch
                                ? Colors.green[700]
                                : Colors.orange[700],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Actions
              if (widget.showActions && !_processing) ...[
                IconButton(
                  icon: const Icon(Icons.check_circle_outline,
                      color: Colors.green),
                  onPressed: _approve,
                  tooltip: loc.marketplaceApprove,
                ),
                IconButton(
                  icon: const Icon(Icons.cancel_outlined, color: Colors.red),
                  onPressed: _reject,
                  tooltip: loc.marketplaceReject,
                ),
              ],
              if (_processing)
                const SizedBox(
                  width: 48,
                  height: 48,
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}

class _RejectReasonDialog extends StatefulWidget {
  @override
  State<_RejectReasonDialog> createState() => _RejectReasonDialogState();
}

class _RejectReasonDialogState extends State<_RejectReasonDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(loc.marketplaceRejectItemTitle),
      content: TextField(
        controller: _controller,
        decoration: InputDecoration(
          labelText: loc.marketplaceReasonOptional,
          border: OutlineInputBorder(),
        ),
        maxLines: 3,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(loc.commonCancel),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(
            context,
            _controller.text.isEmpty
                ? loc.marketplaceRejectedByReviewer
                : _controller.text,
          ),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          child: Text(loc.marketplaceReject),
        ),
      ],
    );
  }
}
