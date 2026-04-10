// lib/features/objects/screens/objects_objects.dart
//
// Admin-side mirror of the regular CleanOps objects_objects.dart screen.
// Queries `companyObject` under the company resolved by `companyIdProvider`,
// groups by category and subgroups by subcategory, with the same search +
// filter + add-FAB layout.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_widgets/dialogs/dialog_action.dart';
import 'package:shared_widgets/lists/standardView.dart';
import 'package:shared_widgets/search/search_field_action.dart';
import 'package:shared_widgets/tiles/standard_tile_large.dart';

import '../../auth/providers/auth_provider.dart';
import '../forms/objects_inventory_form.dart';
import '../utils/company_object_file_images.dart';

class ObjectsObjectsContent extends ConsumerStatefulWidget {
  const ObjectsObjectsContent({super.key});

  @override
  ConsumerState<ObjectsObjectsContent> createState() =>
      ObjectsObjectsContentState();
}

class ObjectsObjectsContentState
    extends ConsumerState<ObjectsObjectsContent> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  final ValueNotifier<bool> _fabVisibleNotifier = ValueNotifier<bool>(true);
  Set<String> _selectedCategoryIds = {};
  final Map<String, String> _categoryNames = {};
  final Map<String, String> _subcategoryNamesByPath = {};
  String? _loadedCompanyPath;

  // Cache: objectId -> primary header image url.
  final Map<String, String> _imageUrlCache = {};

  @override
  void dispose() {
    _searchController.dispose();
    _fabVisibleNotifier.dispose();
    super.dispose();
  }

  Future<void> _preloadCategoryNames(
    DocumentReference<Map<String, dynamic>> companyRef,
  ) async {
    if (_loadedCompanyPath == companyRef.path) return;
    _loadedCompanyPath = companyRef.path;

    final catSnap = await FirebaseFirestore.instance
        .collection('objectCategory')
        .limit(200)
        .get();
    final catMap = <String, String>{
      for (final d in catSnap.docs)
        d.id: ((d.data()['name'] as String?) ?? 'Unnamed').toString(),
    };

    final subSnap =
        await companyRef.collection('objectSubcategory').limit(200).get();
    final subMap = <String, String>{};
    for (final doc in subSnap.docs) {
      final raw = (doc.data()['name'] as String?)?.trim();
      subMap[doc.reference.path] =
          (raw == null || raw.isEmpty) ? 'Unnamed' : raw;
    }

    if (!mounted) return;
    setState(() {
      _categoryNames
        ..clear()
        ..addAll(catMap);
      _subcategoryNamesByPath
        ..clear()
        ..addAll(subMap);
    });
  }

  String _subcategoryLabel(DocumentReference? ref) {
    if (ref == null) return 'Uncategorized';
    final byPath = _subcategoryNamesByPath[ref.path];
    if (byPath != null && byPath.trim().isNotEmpty) return byPath;
    return ref.id.isNotEmpty ? ref.id : 'Uncategorized';
  }

  double? _toNumber(Object? value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  String _formatQuantity(num value) {
    if (value.isNaN || value.isInfinite) return '0';
    final rounded = value.toDouble();
    if ((rounded - rounded.round()).abs() < 1e-6) {
      return rounded.round().toString();
    }
    return rounded.toStringAsFixed(2);
  }

  String _formatBuildingList(Object? raw) {
    final unique = <String>{};
    if (raw is Iterable) {
      for (final item in raw) {
        if (item is String && item.trim().isNotEmpty) {
          unique.add(item.trim());
        }
      }
    } else if (raw is String && raw.trim().isNotEmpty) {
      unique.add(raw.trim());
    }
    if (unique.isEmpty) return '';
    final sorted = unique.toList()..sort();
    return sorted.join(', ');
  }

  void refreshCategoryLabels() {
    final cached = _loadedCompanyPath;
    if (cached == null) return;
    _loadedCompanyPath = null;
    // The next build will repopulate via _preloadCategoryNames.
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final companyRefAsync = ref.watch(companyIdProvider);

    return companyRefAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Error: $err')),
      data: (companyRef) {
        if (companyRef == null) {
          return const Center(
            child: Text('No company linked. Complete onboarding to continue.'),
          );
        }
        _preloadCategoryNames(companyRef);

        final objectsStream = companyRef
            .collection('companyObject')
            .orderBy('objectCategoryId')
            .orderBy('localName')
            .limit(500)
            .snapshots();

        final searchField = SearchFieldAction(
          controller: _searchController,
          labelText: 'Search objects',
          onChanged: (val) => setState(() => _searchQuery = val),
          actionIcon: const Icon(Icons.filter_list),
          actionTooltip: 'Filter by category',
          onAction: _openFilterDialog,
        );

        final listView = NotificationListener<ScrollNotification>(
          onNotification: (sn) {
            if (sn is ScrollUpdateNotification && sn.scrollDelta != null) {
              _fabVisibleNotifier.value = sn.scrollDelta! < 0;
            }
            return false;
          },
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: objectsStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }

              final docs = snapshot.data?.docs ?? [];
              if (docs.isEmpty) {
                return const Center(child: Text('No objects found.'));
              }

              var filtered = docs.where((doc) {
                final name = (doc.data()['localName'] ?? '')
                    .toString()
                    .toLowerCase();
                return name.contains(_searchQuery.toLowerCase());
              });

              if (_selectedCategoryIds.isNotEmpty) {
                filtered = filtered.where((doc) {
                  final ref =
                      doc.data()['objectCategoryId'] as DocumentReference?;
                  return ref != null &&
                      _selectedCategoryIds.contains(ref.id);
                });
              }

              final items = filtered.map((doc) {
                final d = doc.data();
                return {
                  'docId': doc.id,
                  'objectCategoryId': d['objectCategoryId'],
                  'objectSubcategoryId': d['objectSubcategoryId'],
                  'localName': (d['localName'] ?? '').toString(),
                  'inventoryTotalQuantity': d['inventoryTotalQuantity'],
                  'inventoryBuildingAbbreviations':
                      d['inventoryBuildingAbbreviations'],
                };
              }).toList();

              if (items.isEmpty) {
                return const Center(child: Text('No objects match.'));
              }

              return StandardView<Map<String, dynamic>>(
                items: items,
                groupBy: (item) {
                  final ref =
                      item['objectCategoryId'] as DocumentReference?;
                  return _categoryNames[ref?.id] ?? 'Unknown';
                },
                subgroupBy: (item) {
                  final ref =
                      item['objectSubcategoryId'] as DocumentReference?;
                  return _subcategoryLabel(ref);
                },
                groupCollapsible: true,
                initialGroupExpanded: true,
                subgroupCollapsible: true,
                initialSubgroupExpanded: false,
                headerIcon: null,
                subgroupHeaderIcon: null,
                disableGrouping: false,
                onTap: (item) {
                  FocusScope.of(context).unfocus();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ObjectsInventoryForm(
                        companyId: companyRef,
                        objectId: item['docId'] as String,
                      ),
                    ),
                  );
                },
                itemBuilder: (item) {
                  final qty = _toNumber(item['inventoryTotalQuantity']) ?? 0;
                  final qtyLine = 'Qty: ${_formatQuantity(qty)}';
                  final buildingLine = _formatBuildingList(
                    item['inventoryBuildingAbbreviations'],
                  );
                  final docId = item['docId'] as String;
                  return FutureBuilder<String>(
                    future: _imageUrlCache.containsKey(docId)
                        ? Future.value(_imageUrlCache[docId])
                        : CompanyObjectFileImages.primaryHeaderImageUrl(
                            companyRef: companyRef,
                            objectId: docId,
                          ).then((url) {
                            _imageUrlCache[docId] = url;
                            return url;
                          }),
                    builder: (context, imageSnap) {
                      return StandardTileLargeDart(
                        imageUrl: imageSnap.data ?? '',
                        firstLine: item['localName'] as String,
                        firstLineIcon: Icons.category_outlined,
                        secondLine: qtyLine,
                        secondLineIcon: Icons.shelves,
                        thirdLine:
                            buildingLine.isNotEmpty ? buildingLine : null,
                        thirdLineIcon: buildingLine.isNotEmpty
                            ? Icons.location_city_outlined
                            : null,
                      );
                    },
                  );
                },
              );
            },
          ),
        );

        return Stack(
          fit: StackFit.expand,
          children: [
            Column(
              children: [
                searchField,
                Expanded(child: listView),
              ],
            ),
            Positioned(
              right: 16,
              bottom: 16,
              child: ValueListenableBuilder<bool>(
                valueListenable: _fabVisibleNotifier,
                builder: (c, isVisible, child) => AnimatedOpacity(
                  duration: const Duration(milliseconds: 300),
                  opacity: isVisible ? 1 : 0,
                  child: child,
                ),
                child: FloatingActionButton(
                  heroTag: null,
                  onPressed: () {
                    // No add-from-scratch flow exists in admin yet — open the
                    // inventory form for an empty placeholder objectId.
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ObjectsInventoryForm(
                          companyId: companyRef,
                          objectId: '',
                        ),
                      ),
                    );
                  },
                  child: const Icon(Icons.add),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _openFilterDialog() {
    final newSelected = Set<String>.from(_selectedCategoryIds);
    showDialog(
      context: context,
      builder: (ctx) => DialogAction(
        title: 'Filter by category',
        content: StatefulBuilder(
          builder: (ctx2, setDialogState) {
            if (_categoryNames.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }
            final sorted = _categoryNames.entries.toList()
              ..sort((a, b) =>
                  a.value.toLowerCase().compareTo(b.value.toLowerCase()));
            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: sorted.map((e) {
                  final isSelected = newSelected.contains(e.key);
                  return CheckboxListTile(
                    dense: true,
                    title: Text(e.value),
                    value: isSelected,
                    onChanged: (checked) {
                      setDialogState(() {
                        if (checked == true) {
                          newSelected.add(e.key);
                        } else {
                          newSelected.remove(e.key);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
            );
          },
        ),
        cancelText: 'Cancel',
        onCancel: () => Navigator.of(ctx).pop(),
        actionText: 'Apply',
        onAction: () {
          setState(() => _selectedCategoryIds = newSelected);
          Navigator.of(ctx).pop();
        },
      ),
    );
  }
}
