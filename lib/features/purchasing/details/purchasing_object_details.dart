// lib/features/purchasing/details/purchasing_object_details.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../objects/details/object_process_details.dart';
import '../../objects/forms/object_element_form.dart';
import '../../objects/details/object_element_details.dart';
import '../../objects/forms/object_process_form.dart';
import '../../objects/forms/objects_inventory_form.dart';

import 'package:shared_widgets/utils/image_payload.dart';
import 'package:shared_widgets/search/search_field_action.dart';
import 'package:shared_widgets/containers/container_action.dart';
import 'package:shared_widgets/containers/container_header.dart';
import 'package:shared_widgets/labels/header_info_icon_value.dart';
import 'package:kleenops_admin/widgets/tiles/icon_text_icon_text.dart';
import 'package:shared_widgets/tiles/standard_tile_large.dart';
import 'package:kleenops_admin/widgets/viewers/image_viewer.dart';
import 'package:kleenops_admin/widgets/viewers/live_barcode_scanner_page.dart';
import 'package:shared_widgets/dialogs/dialog_action.dart';
import 'package:kleenops_admin/features/auth/providers/auth_provider.dart';
import 'package:shared_widgets/utils/process_localization_utils.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/details_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/home_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/home_navbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/drawers/appbar_logout_adapter.dart';
import '../../objects/utils/company_object_file_images.dart';
import '../../objects/utils/object_element_file_images.dart';
import '../../objects/utils/object_process_file_images.dart';
import 'package:shared_widgets/utils/location_display_utils.dart';
import 'package:shared_widgets/containers/canvas_top_bookend.dart';
import 'package:shared_widgets/containers/standard_canvas.dart';
import 'package:shared_widgets/drawers/menu_drawer.dart';

class PurchasingObjectDetails extends ConsumerStatefulWidget {
  final String docId;

  const PurchasingObjectDetails({
    super.key,
    required this.docId,
  });

  @override
  ConsumerState<PurchasingObjectDetails> createState() =>
      _PurchasingObjectDetailsState();
}

class _PurchasingObjectDetailsState
    extends ConsumerState<PurchasingObjectDetails> {
  late final ScrollController _scrollController;
  final ValueNotifier<bool> _fabVisibleNotifier = ValueNotifier<bool>(true);

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _fabVisibleNotifier.dispose();
    super.dispose();
  }

  Widget _wrapCanvas(Widget child) {
    return StandardCanvas(
      child: SafeArea(
        top: true,
        bottom: false,
        child: Stack(
          children: [
            Positioned.fill(child: child),
            const Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: CanvasTopBookend(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimatedFab(
    DocumentReference<Map<String, dynamic>> companyRef,
  ) {
    return ValueListenableBuilder<bool>(
      valueListenable: _fabVisibleNotifier,
      builder: (context, isVisible, child) => AnimatedOpacity(
        duration: const Duration(milliseconds: 300),
        opacity: isVisible ? 1.0 : 0.0,
        child: child,
      ),
      child: FloatingActionButton(
        heroTag: 'editObject',
        child: const Icon(Icons.edit),
        onPressed: () => _editBasicInfo(companyRef),
      ),
    );
  }

  Future<void> _editBasicInfo(
    DocumentReference<Map<String, dynamic>> companyRef,
  ) async {
    final docRef = FirebaseFirestore.instance.collection('companyObject').doc(widget.docId);
    final snap = await docRef.get();
    if (!snap.exists) return;
    final data = snap.data() ?? {};

    final nameCtl = TextEditingController(text: data['localName'] ?? '');
    final descCtl = TextEditingController(text: data['description'] ?? '');
    final priceCtl = TextEditingController(
      text: data['currentPrice'] != null ? data['currentPrice'].toString() : '',
    );
    DocumentReference<Map<String, dynamic>>? vendorRef =
        data['currentVendorId'] as DocumentReference<Map<String, dynamic>>?;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setD) => DialogAction(
          title: 'Edit Object',
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtl,
                decoration: const InputDecoration(labelText: 'Local Name'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descCtl,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
              const SizedBox(height: 16),
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('companyCompany')
                    .orderBy('name')
                    .snapshots(),
                builder: (context, snap) {
                  if (!snap.hasData) {
                    return const SizedBox(
                      height: 60,
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  final docs = snap.data!.docs;
                  final items = docs.map((d) => d.reference).toList();
                  return SearchAddSelectDropdown<
                      DocumentReference<Map<String, dynamic>>>(
                    label: 'Vendor',
                    items: items,
                    initialValue: vendorRef,
                    itemLabel: (ref) {
                      final matches = docs.where((e) => e.reference == ref);
                      if (matches.isNotEmpty) {
                        final d = matches.first;
                        return (d.data()['name'] ?? 'Unnamed Vendor') as String;
                      }
                      return 'Unknown Vendor';
                    },
                    onChanged: (val) => setD(() => vendorRef = val),
                  );
                },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: priceCtl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Current Price'),
              ),
            ],
          ),
          cancelText: 'Cancel',
          onCancel: () => Navigator.of(ctx2).pop(),
          actionText: 'Save',
          onAction: () async {
            final price = double.tryParse(priceCtl.text.trim());
            await docRef.update({
              'localName': nameCtl.text.trim(),
              'description': descCtl.text.trim(),
              'currentVendorId': vendorRef,
              if (price != null) 'currentPrice': price,
            });
            Navigator.of(ctx2).pop();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool hideChrome = false;

    Widget buildBottomBar({VoidCallback? onAiPressed}) {
      if (hideChrome) return const SizedBox.shrink();
      final menuSections = MenuDrawerSections(
      );
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DetailsAppBar(
            title: 'Object Details',
            onAiPressed: onAiPressed,
            menuSections: menuSections,
          ),
          const HomeNavBarAdapter(highlightSelected: false),
        ],
      );
    }

    final companyRef = ref.watch(companyIdProvider).maybeWhen(
          data: (r) => r,
          orElse: () => null,
        );

    if (companyRef == null) {
      return Scaffold(
        appBar: null,
        bottomNavigationBar: hideChrome
            ? null
            : buildBottomBar(),
        body: const Center(
          child: Text('Error: No company ID found or still loading.'),
        ),
      );
    }

    final docRef = FirebaseFirestore.instance.collection('companyObject').doc(widget.docId);

    return Scaffold(
      appBar: null,
      bottomNavigationBar: hideChrome
          ? null
          : buildBottomBar(),
      body: _wrapCanvas(
          NotificationListener<ScrollNotification>(
            onNotification: (scrollInfo) {
              if (scrollInfo is ScrollUpdateNotification &&
                  scrollInfo.scrollDelta != null) {
                if (scrollInfo.scrollDelta! > 0 && _fabVisibleNotifier.value) {
                  _fabVisibleNotifier.value = false;
                } else if (scrollInfo.scrollDelta! < 0 &&
                    !_fabVisibleNotifier.value) {
                  _fabVisibleNotifier.value = true;
                }
              }
              return false;
            },
            child: _PurchasingObjectDetailsBody(
              companyId: companyRef,
              docId: widget.docId,
              scrollController: _scrollController,
            ),
          ),
        ),
      floatingActionButton: _buildAnimatedFab(companyRef),
    );
  }
}

class _PurchasingObjectDetailsBody extends StatefulWidget {
  final DocumentReference<Map<String, dynamic>> companyId;
  final String docId;
  final ScrollController scrollController;

  const _PurchasingObjectDetailsBody({
    super.key,
    required this.companyId,
    required this.docId,
    required this.scrollController,
  });

  @override
  State<_PurchasingObjectDetailsBody> createState() =>
      _PurchasingObjectDetailsBodyState();
}

class _PurchasingObjectDetailsBodyState
    extends State<_PurchasingObjectDetailsBody> {
  bool _inventoryExpanded = false;

  @override
  Widget build(BuildContext context) {
    final companyId = widget.companyId;
    final docId = widget.docId;
    final scrollController = widget.scrollController;
    final docRef =
        widget.companyId.collection('companyObject').doc(widget.docId);
    final bool hideChrome = false;
    final bottomPadding = hideChrome ? 16.0 : kBottomNavigationBarHeight + 16.0;

    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: companyId.get(),
      builder: (context, companySnapshot) {
        if (companySnapshot.hasError) {
          return Center(
            child: Text("Error loading company data: ${companySnapshot.error}"),
          );
        }
        if (!companySnapshot.hasData || !companySnapshot.data!.exists) {
          return const Center(child: CircularProgressIndicator());
        }

        final companyData = companySnapshot.data!.data()!;
        final String measurementSystem =
            companyData['measurementSystem'] ?? "Standard";

        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: docRef.snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }
            if (!snapshot.hasData || !snapshot.data!.exists) {
              return const Center(child: CircularProgressIndicator());
            }

            final data = snapshot.data!.data()!;
            final String localName = data['localName'] ?? '';
            final String description = data['description'] ?? '';

            final DocumentReference<Map<String, dynamic>>? currentVendorRef =
                data['currentVendorId'] != null
                    ? data['currentVendorId']
                        as DocumentReference<Map<String, dynamic>>
                    : null;

            final bool hasCoverings = (data['floorCovering'] ?? false) ||
                (data['wallCovering'] ?? false) ||
                (data['ceilingCovering'] ?? false);

            final objectCategoryRef = data['objectCategoryId']
                as DocumentReference<Map<String, dynamic>>?;
            final String objectCategoryId = objectCategoryRef?.id ?? '';
            final bool showObjectElements =
                (objectCategoryId == 'YMhF1bZtFyvaYlZyKwWU');

            return SingleChildScrollView(
              controller: scrollController,
              padding: EdgeInsets.only(
                bottom: bottomPadding + MediaQuery.of(context).padding.bottom,
              ),
              child: Column(
                children: [
                  FutureBuilder<String>(
                    future: CompanyObjectFileImages.primaryHeaderImageUrl(
                      companyRef: companyId,
                      objectId: docId,
                    ),
                    builder: (context, imageSnap) {
                      final imageUrl = imageSnap.data ?? '';
                      if (currentVendorRef != null) {
                        return FutureBuilder<
                            DocumentSnapshot<Map<String, dynamic>>>(
                          future: currentVendorRef.get(),
                          builder: (context, vendorSnapshot) {
                            String vendorName = "N/A";
                            if (vendorSnapshot.hasData &&
                                vendorSnapshot.data != null &&
                                vendorSnapshot.data!.exists) {
                              final vendorData = vendorSnapshot.data!.data();
                              vendorName =
                                  vendorData?['name'] ?? "Unnamed Vendor";
                            }
                            return _buildHeaderField(
                              context,
                              imageUrl: imageUrl,
                              localName: localName,
                              description: description,
                              vendorName: vendorName,
                              data: data,
                            );
                          },
                        );
                      }
                      return _buildHeaderField(
                        context,
                        imageUrl: imageUrl,
                        localName: localName,
                        description: description,
                        vendorName: "N/A",
                        data: data,
                      );
                    },
                  ),

                  // ---------------------------------------------------------
                  //  Object Elements
                  // ---------------------------------------------------------
                  if (showObjectElements)
                    ContainerActionWidget(
                      title: "Object Elements",
                      actionText: "Add",
                      onAction: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ObjectElementForm(
                              extraData: {
                                'companyObjectDocRef': docRef,
                                'docId': docId,
                              },
                            ),
                          ),
                        );
                      },
                      content:
                          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: companyId
                            .collection('objectInventory')
                            .where('companyObjectId', isEqualTo: docRef)
                            .snapshots(),
                        builder: (context, invSnapshot) {
                          double totalObjects = 0.0;
                          if (invSnapshot.hasData) {
                            for (final d in invSnapshot.data!.docs) {
                              final q = d.data()['quantity'];
                              if (q is num) totalObjects += q.toDouble();
                            }
                          }

                          return ListView.builder(
                            itemCount:
                                (data['elements'] as List<dynamic>? ?? [])
                                    .length,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemBuilder: (context, index) {
                              final localeCode =
                                  Localizations.localeOf(context).languageCode;
                              final item =
                                  (data['elements'] as List<dynamic>)[index]
                                      as Map<String, dynamic>;
                              final materialRef = item['elementMaterialId']
                                  as DocumentReference<Map<String, dynamic>>?;
                              final scalarRef = item['scalarId']
                                  as DocumentReference<Map<String, dynamic>>?;
                              final resolvedName =
                                  ProcessLocalizationUtils.resolveLocalizedText(
                                item['name'],
                                localeCode: localeCode,
                                fallbackLocaleCode:
                                    ProcessLocalizationUtils.defaultLocaleCode,
                              );
                              final String name = resolvedName.isNotEmpty
                                  ? resolvedName
                                  : 'Element';
                              const String fallbackImageUrl = '';
                              final elementId = item['id'] as String?;
                              final elementRef = elementId != null
                                  ? companyId
                                      .collection('objectElement')
                                      .doc(elementId)
                                  : null;

                              Widget buildTile(String thirdLine,
                                  {String? fourthLine}) {
                                final imageFuture = elementRef != null
                                    ? ObjectElementFileImages
                                        .primaryHeaderImageUrl(
                                        companyRef: companyId,
                                        elementRef: elementRef,
                                      )
                                    : Future.value(fallbackImageUrl);
                                return FutureBuilder<String>(
                                  future: imageFuture,
                                  builder: (context, imageSnap) {
                                    final fileImageUrl =
                                        (imageSnap.data ?? '').trim();
                                    final imageUrl = fileImageUrl;
                                    return FutureBuilder<String>(
                                      future: _getMaterialName(
                                        localeCode: localeCode,
                                        materialRef: materialRef,
                                        materialNameField:
                                            item['elementMaterialName'],
                                      ),
                                      builder: (context, matSnap) {
                                        final materialName =
                                            matSnap.data ?? 'N/A';
                                        return StandardTileLargeDart(
                                          imageUrl: imageUrl,
                                          firstLine: name,
                                          firstLineIcon:
                                              Icons.group_work_outlined,
                                          secondLine: materialName,
                                          secondLineIcon: Icons.hub,
                                          thirdLine: thirdLine,
                                          thirdLineIcon: Icons.straighten,
                                          fourthLine: fourthLine,
                                          fourthLineIcon: Icons.calculate,
                                        );
                                      },
                                    );
                                  },
                                );
                              }

                              Widget content;
                              if (hasCoverings) {
                                final double percentVal =
                                    (item['percentObject'] == null)
                                        ? 0.0
                                        : double.tryParse(item['percentObject']
                                                .toString()) ??
                                            0.0;
                                final String percentStr =
                                    '${(percentVal * 100).toStringAsFixed(0)}%';
                                content = buildTile(percentStr);
                              } else {
                                double qty = 0.0;
                                if (measurementSystem == "Standard") {
                                  if (item['standardQuantity'] != null) {
                                    qty = double.tryParse(
                                            item['standardQuantity']
                                                .toString()) ??
                                        0.0;
                                  }
                                } else {
                                  if (item['metricQuantity'] != null) {
                                    qty = double.tryParse(item['metricQuantity']
                                            .toString()) ??
                                        0.0;
                                  }
                                }
                                double roundedQty = (qty * 100).ceil() / 100;
                                String qtyStr = roundedQty.toStringAsFixed(2);
                                double totalArea = roundedQty * totalObjects;
                                double roundedTotal =
                                    (totalArea * 100).ceil() / 100;
                                String totalStr =
                                    roundedTotal.toStringAsFixed(2);
                                if (scalarRef == null) {
                                  content =
                                      buildTile(qtyStr, fourthLine: totalStr);
                                } else {
                                  content = FutureBuilder<
                                      DocumentSnapshot<Map<String, dynamic>>>(
                                    future: scalarRef.get(),
                                    builder: (context, scalarSnapshot) {
                                      String extraDesc = qtyStr;
                                      String fourthLine = totalStr;
                                      if (scalarSnapshot.connectionState ==
                                              ConnectionState.done &&
                                          scalarSnapshot.hasData &&
                                          scalarSnapshot.data!.exists) {
                                        final scalarData =
                                            scalarSnapshot.data!.data();
                                        String unit = measurementSystem ==
                                                "Standard"
                                            ? (scalarData?['standardUnit'] ??
                                                '')
                                            : (scalarData?['metricUnit'] ?? '');
                                        extraDesc = "$qtyStr $unit";
                                        fourthLine = "$totalStr $unit";
                                      }
                                      return buildTile(extraDesc,
                                          fourthLine: fourthLine);
                                    },
                                  );
                                }
                              }

                              return Dismissible(
                                key: ValueKey(item['id'] ?? index),
                                direction: DismissDirection.startToEnd,
                                onDismissed: (_) async {
                                  final deletedData =
                                      Map<String, dynamic>.from(item);
                                  final elementId =
                                      deletedData['id'] as String?;

                                  if (elementId != null) {
                                    await companyId
                                        .collection('objectElement')
                                        .doc(elementId)
                                        .delete();
                                  }

                                  await docRef.update({
                                    'elements':
                                        FieldValue.arrayRemove([deletedData])
                                  });
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: const Text('Element deleted.'),
                                      duration: const Duration(seconds: 5),
                                      action: SnackBarAction(
                                        label: 'UNDO',
                                        onPressed: () async {
                                          if (elementId != null) {
                                            await companyId
                                                .collection('objectElement')
                                                .doc(elementId)
                                                .set(deletedData);
                                          }
                                          await docRef.update({
                                            'elements': FieldValue.arrayUnion(
                                              [deletedData],
                                            )
                                          });
                                        },
                                      ),
                                    ),
                                  );
                                },
                                child: InkWell(
                                  onTap: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => ObjectElementDetails(
                                          companyObjectDocRef: docRef,
                                          element: item,
                                        ),
                                      ),
                                    );
                                  },
                                  child: content,
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),

                  // ---------------------------------------------------------
                  //  Object Processes
                  // ---------------------------------------------------------
                  ContainerActionWidget(
                    title: "Object Processes",
                    actionText: "Add",
                    onAction: () async {
                      final imageUrl =
                          await CompanyObjectFileImages.primaryHeaderImageUrl(
                        companyRef: companyId,
                        objectId: docId,
                      );
                      final encodedImageUrl = Uri.encodeComponent(imageUrl);
                      if (!mounted) return;
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ObjectProcessForm(
                            companyId: companyId,
                            objectId: docId,
                            initialImageUrl: encodedImageUrl,
                          ),
                        ),
                      );
                    },
                    content: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: companyId
                          .collection('objectProcess')
                          .where('companyObjectId', isEqualTo: docRef)
                          .snapshots(),
                      builder: (context, processSnapshot) {
                        if (processSnapshot.hasError) {
                          return const Center(
                              child: Text('Failed to load processes.'));
                        }
                        if (processSnapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }
                        final processDocs = processSnapshot.data?.docs ??
                            const <QueryDocumentSnapshot<
                                Map<String, dynamic>>>[];
                        if (processDocs.isEmpty) {
                          return const Center(child: Text('No data found.'));
                        }
                        return ListView.builder(
                          itemCount: processDocs.length,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemBuilder: (context, index) {
                            final processDoc = processDocs[index];
                            final item = processDoc.data();
                            final localeCode =
                                Localizations.localeOf(context).languageCode;
                            final resolvedObjectProcessName =
                                ProcessLocalizationUtils.resolveLocalizedText(
                              item['objectProcessName'] ??
                                  item['name'] ??
                                  item['processName'],
                              localeCode: localeCode,
                              fallbackLocaleCode:
                                  ProcessLocalizationUtils.defaultLocaleCode,
                            ).trim();
                            final objectProcessName =
                                resolvedObjectProcessName.isNotEmpty
                                    ? resolvedObjectProcessName
                                    : (item['objectProcessName'] ??
                                            item['name'] ??
                                            item['processName'] ??
                                            'No Statement')
                                        .toString();
                            final resolvedProcessName =
                                ProcessLocalizationUtils.resolveLocalizedText(
                              item['processName'] ?? item['name'],
                              localeCode: localeCode,
                              fallbackLocaleCode:
                                  ProcessLocalizationUtils.defaultLocaleCode,
                            ).trim();
                            final processName = resolvedProcessName.isNotEmpty
                                ? resolvedProcessName
                                : (item['processName'] ?? item['name'] ?? '')
                                    .toString();
                            final objectElementsIds = item['processElements'];
                            return FutureBuilder<String>(
                              future:
                                  ObjectProcessFileImages.primaryHeaderImageUrl(
                                companyRef: companyId,
                                processRef: processDoc.reference,
                              ),
                              builder: (context, imageSnap) {
                                final fileImageUrl =
                                    (imageSnap.data ?? '').trim();
                                final processImageUrl = fileImageUrl;
                                return FutureBuilder<List<String>>(
                                  future: _fetchElementNames(
                                    objectElementsIds,
                                    Localizations.localeOf(context)
                                        .languageCode,
                                  ),
                                  builder: (context, snapshot) {
                                    String elementNames = '';
                                    if (snapshot.hasData) {
                                      elementNames = snapshot.data!.join(', ');
                                    }
                                    return Dismissible(
                                      key: ValueKey(processDoc.id),
                                      direction: DismissDirection.startToEnd,
                                      onDismissed: (_) async {
                                        final deletedData = processDoc.data();
                                        await processDoc.reference.delete();
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content:
                                                const Text('Process deleted.'),
                                            duration:
                                                const Duration(seconds: 5),
                                            action: SnackBarAction(
                                              label: 'UNDO',
                                              onPressed: () async {
                                                await processDoc.reference
                                                    .set(deletedData);
                                              },
                                            ),
                                          ),
                                        );
                                      },
                                      child: InkWell(
                                        onTap: () {
                                          Navigator.of(context).push(
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  ObjectProcessDetails(
                                                companyObjectDocRef: docRef,
                                                process: {
                                                  ...item,
                                                  'id': processDoc.id,
                                                },
                                              ),
                                            ),
                                          );
                                        },
                                        child: StandardTileLargeDart(
                                          imageUrl: processImageUrl,
                                          firstLine: objectProcessName,
                                          firstLineIcon: Icons.content_paste,
                                          secondLine: processName,
                                          secondLineIcon: Icons.alt_route,
                                          thirdLine: elementNames,
                                          thirdLineIcon:
                                              Icons.group_work_outlined,
                                          fourthLine:
                                              item['objectProcessCostText'] ??
                                                  '',
                                          fourthLineIcon: Icons.attach_money,
                                        ),
                                      ),
                                    );
                                  },
                                );
                              },
                            );
                          },
                        );
                      },
                    ),
                  ),

                  // ---------------------------------------------------------
                  //  Object Inventory
                  // ---------------------------------------------------------
                  Builder(builder: (context) {
                    final invBaseQuery = companyId
                        .collection('objectInventory')
                        .where('companyObjectId', isEqualTo: docRef)
                        .orderBy(
                          hasCoverings ? 'percentLocation' : 'quantity',
                          descending: true,
                        );

                    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: invBaseQuery.snapshots(),
                      builder: (context, invSnap) {
                        if (!invSnap.hasData) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }

                        final allDocs = invSnap.data!.docs;
                        final total = allDocs.length;
                        final docs = _inventoryExpanded
                            ? allDocs
                            : allDocs.take(5).toList();

                        return FutureBuilder<List<_InventoryItem>>(
                          future: _loadInventoryItems(docs, hasCoverings),
                          builder: (context, itemSnap) {
                            if (!itemSnap.hasData) {
                              return const Center(
                                  child: CircularProgressIndicator());
                            }

                            final items = itemSnap.data!;

                            return ContainerActionWidget(
                              title: 'Object Inventory',
                              headerActionText: total > 5
                                  ? (_inventoryExpanded
                                      ? 'Show Less'
                                      : 'Show All ($total)')
                                  : '',
                              onHeaderAction: total > 5
                                  ? () => setState(() =>
                                      _inventoryExpanded = !_inventoryExpanded)
                                  : null,
                              actionText: 'Add',
                              onAction: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => ObjectsInventoryForm(
                                      companyId: companyId,
                                      objectId: docId,
                                    ),
                                  ),
                                );
                              },
                              content: ListView.separated(
                                shrinkWrap: true,
                                physics: const ClampingScrollPhysics(),
                                itemCount: items.length,
                                separatorBuilder: (_, __) => Divider(
                                  height: 1,
                                  thickness: 1,
                                  color: Colors.grey[300],
                                ),
                                itemBuilder: (context, idx) {
                                  final item = items[idx];
                                  final locRef = item.locRef;
                                  return IconTextIconTextTile(
                                    leftIcon: Icons.inventory_2_outlined,
                                    leftText: item.displayValue,
                                    rightIcon: Icons.location_on_outlined,
                                    rightText: item.locationName,
                                    actionIcon: Icons.location_on,
                                    compact: true,
                                    actionIconAction: () async {
                                      if (locRef == null) return;
                                      final locSnap = await locRef.get();
                                      final locData = locSnap.data() ?? {};
                                      final floorRef = locRef.parent.parent;
                                      String imageUrl;
                                      double floorImgWidth;
                                      double floorImgHeight;
                                      if (floorRef != null) {
                                        final floorSnap = await floorRef.get();
                                        if (floorSnap.exists) {
                                          final floorData = floorSnap.data();
                                          final variants =
                                              floorData?['floorPlanVariants'];
                                          imageUrl = imageUrlForRole(
                                                variants,
                                                roles: const [
                                                  kImageRolePreview,
                                                  kImageRoleAnalysis,
                                                ],
                                              ) ??
                                              'https://via.placeholder.com/600x800';
                                          floorImgWidth =
                                              (floorData?['imageWidth'] as num?)
                                                      ?.toDouble() ??
                                                  600.0;
                                          floorImgHeight =
                                              (floorData?['imageHeight']
                                                          as num?)
                                                      ?.toDouble() ??
                                                  800.0;
                                        } else {
                                          imageUrl =
                                              'https://via.placeholder.com/600x800';
                                          floorImgWidth = 600.0;
                                          floorImgHeight = 800.0;
                                        }
                                      } else {
                                        imageUrl =
                                            'https://via.placeholder.com/600x800';
                                        floorImgWidth = 600.0;
                                        floorImgHeight = 800.0;
                                      }
                                      final double pinXAbsolute =
                                          (locData['xy']?['x'] as num?)
                                                  ?.toDouble() ??
                                              0.0;
                                      final double pinYAbsolute =
                                          (locData['xy']?['y'] as num?)
                                                  ?.toDouble() ??
                                              0.0;
                                      if (!context.mounted) return;
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (context) => ImageViewer(
                                            imageUrl: imageUrl,
                                            floorImgWidth: floorImgWidth,
                                            floorImgHeight: floorImgHeight,
                                            pinXAbsolute: pinXAbsolute,
                                            pinYAbsolute: pinYAbsolute,
                                          ),
                                        ),
                                      );
                                    },
                                  );
                                },
                              ),
                            );
                          },
                        );
                      },
                    );
                  }),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildHeaderField(
    BuildContext context, {
    required String imageUrl,
    required String localName,
    required String description,
    required String vendorName,
    required Map<String, dynamic> data,
  }) {
    final objectCategoryRef =
        data['objectCategoryId'] as DocumentReference<Map<String, dynamic>>?;
    final String objectCategoryId = objectCategoryRef?.id ?? '';
    final bool showOperatingService =
        (objectCategoryId == 'pMxwXJnP7dpT7EHhUdij' ||
            objectCategoryId == 'pbWjQsoE9vOQVQPnq1GP');
    final bool showTco = !(objectCategoryId == '8218hipYAHzhDmHr4YVv' ||
        objectCategoryId == 'u8HhVZPiFEYLlTp7zZ25');

    String fieldHeader3 = '';
    String field3 = '';
    IconData? fieldIcon3;
    if (showOperatingService) {
      fieldHeader3 = 'Operating Cost (hr)';
      if (data['operatingCost'] != null) {
        final costHrs = (data['operatingCost'] as num) * 60;
        field3 = costHrs.toString();
      } else {
        field3 = 'N/A';
      }
      fieldIcon3 = Icons.attach_money;
    }

    String fieldHeader4 = '';
    String field4 = '';
    IconData? fieldIcon4;
    if (showOperatingService) {
      fieldHeader4 = 'Service Life (hrs)';
      if (data['serviceLife'] != null) {
        final lifeHrs = (data['serviceLife'] as num) / 60;
        field4 = lifeHrs.toString();
      } else {
        field4 = 'N/A';
      }
      fieldIcon4 = Icons.hourglass_empty;
    }

    String fieldHeader5 = '';
    String field5 = '';
    IconData? fieldIcon5;
    if (showTco) {
      fieldHeader5 = 'Total Cost of Ownership';
      if (data['totalCostofOwnership'] != null) {
        final tcoVal =
            (data['totalCostofOwnership'] as num).toDouble().toStringAsFixed(2);
        field5 = tcoVal;
      } else {
        field5 = 'N/A';
      }
      fieldIcon5 = Icons.attach_money;
    }

    // IDs (barcode, etc.)
    final String? barcode = data['objectBarcode'];
    final String? serialNumber = data['objectSerialNumber'];
    final String? assetTag = data['objectAssetTag'];

    final bool hasBarcode = barcode != null && barcode.trim().isNotEmpty;
    final bool hasSerialNumber =
        serialNumber != null && serialNumber.trim().isNotEmpty;
    final bool hasAssetTag = assetTag != null && assetTag.trim().isNotEmpty;
    final bool showIdContainer = hasBarcode || hasSerialNumber || hasAssetTag;

    return Column(
      children: [
        ContainerHeader(
          image: imageUrl,
          showImage: imageUrl.trim().isNotEmpty,
          titleHeader: 'Local Name',
          title: localName,
          descriptionHeader: 'Description',
          description: description,
          textIcon: Icons.category_outlined,
          descriptionIcon: Icons.info_outlined,
        ),
        if (showIdContainer)
          ContainerActionWidget(
            title: '',
            actionText: '',
            onAction: null,
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (hasBarcode) ...[
                  HeaderInfoIconValue(
                    header: 'Barcode',
                    value: barcode,
                    icon: Icons.qr_code,
                  ),
                  if (hasSerialNumber || hasAssetTag)
                    const SizedBox(height: 12),
                ],
                if (hasSerialNumber) ...[
                  HeaderInfoIconValue(
                    header: 'Serial Number',
                    value: serialNumber,
                    icon: Icons.numbers,
                  ),
                  if (hasAssetTag) const SizedBox(height: 12),
                ],
                if (hasAssetTag)
                  HeaderInfoIconValue(
                    header: 'Asset Tag',
                    value: assetTag,
                    icon: Icons.sell,
                  ),
              ],
            ),
          ),
        ContainerActionWidget(
          title: '',
          actionText: '',
          onAction: null,
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              HeaderInfoIconValue(
                header: 'Current Vendor',
                value: vendorName,
                icon: Icons.store_outlined,
              ),
              const SizedBox(height: 12),
              HeaderInfoIconValue(
                header: 'Current Price',
                value: data['currentPrice'] != null
                    ? data['currentPrice'].toString()
                    : 'N/A',
                icon: Icons.attach_money,
              ),
              if (showOperatingService) ...[
                const SizedBox(height: 12),
                HeaderInfoIconValue(
                  header: fieldHeader3,
                  value: field3,
                  icon: fieldIcon3 ?? Icons.info_outline,
                ),
                const SizedBox(height: 12),
                HeaderInfoIconValue(
                  header: fieldHeader4,
                  value: field4,
                  icon: fieldIcon4 ?? Icons.info_outline,
                ),
              ],
              if (showTco) ...[
                const SizedBox(height: 12),
                HeaderInfoIconValue(
                  header: fieldHeader5,
                  value: field5,
                  icon: fieldIcon5 ?? Icons.info_outline,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _editBarcode(
    DocumentReference<Map<String, dynamic>> docRef,
    String currentValue,
  ) async {
    final controller = TextEditingController(text: currentValue);
    await showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (dialogCtx2, setState) {
          Future<void> scan() async {
            final result = await Navigator.of(dialogCtx2).push<String>(
              MaterialPageRoute(builder: (_) => const LiveBarcodeScannerPage()),
            );
            if (result != null && result.isNotEmpty) {
              setState(() => controller.text = result);
            }
          }

          return DialogAction(
            title: 'Barcode',
            content: TextField(
              controller: controller,
              decoration: InputDecoration(
                labelText: 'Barcode',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.qr_code_scanner),
                  onPressed: scan,
                ),
              ),
            ),
            cancelText: 'Cancel',
            onCancel: () => Navigator.of(dialogCtx2).pop(),
            actionText: 'Save',
            onAction: () async {
              await docRef.update({'objectBarcode': controller.text.trim()});
              Navigator.of(dialogCtx2).pop();
            },
          );
        },
      ),
    );
  }

  Future<void> _editSerialNumber(
    DocumentReference<Map<String, dynamic>> docRef,
    String currentValue,
  ) async {
    final controller = TextEditingController(text: currentValue);
    await showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (dialogCtx2, setState) {
          Future<void> scan() async {
            final result = await Navigator.of(dialogCtx2).push<String>(
              MaterialPageRoute(builder: (_) => const LiveBarcodeScannerPage()),
            );
            if (result != null && result.isNotEmpty) {
              setState(() => controller.text = result);
            }
          }

          return DialogAction(
            title: 'Serial Number',
            content: TextField(
              controller: controller,
              decoration: InputDecoration(
                labelText: 'Serial Number',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.qr_code_scanner),
                  onPressed: scan,
                ),
              ),
            ),
            cancelText: 'Cancel',
            onCancel: () => Navigator.of(dialogCtx2).pop(),
            actionText: 'Save',
            onAction: () async {
              await docRef
                  .update({'objectSerialNumber': controller.text.trim()});
              Navigator.of(dialogCtx2).pop();
            },
          );
        },
      ),
    );
  }

  Future<void> _editAssetTag(
    DocumentReference<Map<String, dynamic>> docRef,
    String currentValue,
  ) async {
    final controller = TextEditingController(text: currentValue);
    await showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (dialogCtx2, setState) {
          Future<void> scan() async {
            final result = await Navigator.of(dialogCtx2).push<String>(
              MaterialPageRoute(builder: (_) => const LiveBarcodeScannerPage()),
            );
            if (result != null && result.isNotEmpty) {
              setState(() => controller.text = result);
            }
          }

          return DialogAction(
            title: 'Asset Tag',
            content: TextField(
              controller: controller,
              decoration: InputDecoration(
                labelText: 'Asset Tag',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.qr_code_scanner),
                  onPressed: scan,
                ),
              ),
            ),
            cancelText: 'Cancel',
            onCancel: () => Navigator.of(dialogCtx2).pop(),
            actionText: 'Save',
            onAction: () async {
              await docRef.update({'objectAssetTag': controller.text.trim()});
              Navigator.of(dialogCtx2).pop();
            },
          );
        },
      ),
    );
  }

  Future<List<String>> _fetchElementNames(
    List<dynamic>? rawIds,
    String localeCode,
  ) async {
    if (rawIds == null || rawIds.isEmpty) return [];

    final docRef =
        widget.companyId.collection('companyObject').doc(widget.docId);
    final snap = await docRef.get();
    final List<Map<String, dynamic>> allElements =
        (snap.data()?['elements'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .toList();

    final Map<String, Map<String, dynamic>> elementsById = {
      for (final e in allElements)
        if (e['id'] is String) e['id'] as String: e,
    };

    final names = <String>[];
    for (final raw in rawIds) {
      final String? id = raw is Map<String, dynamic>
          ? raw['elementId'] as String?
          : raw is String
              ? raw
              : null;
      if (id == null) continue;

      final resolvedName = ProcessLocalizationUtils.resolveLocalizedText(
        elementsById[id]?['name'],
        localeCode: localeCode,
        fallbackLocaleCode: ProcessLocalizationUtils.defaultLocaleCode,
      );
      if (resolvedName.isNotEmpty) names.add(resolvedName);
    }
    return names;
  }

  Future<String> _getMaterialName({
    required String localeCode,
    DocumentReference<Map<String, dynamic>>? materialRef,
    dynamic materialNameField,
  }) async {
    final resolvedFromElement = ProcessLocalizationUtils.resolveLocalizedText(
      materialNameField,
      localeCode: localeCode,
      fallbackLocaleCode: ProcessLocalizationUtils.defaultLocaleCode,
    );
    if (resolvedFromElement.isNotEmpty) return resolvedFromElement;
    if (materialRef == null) return 'N/A';
    try {
      final snap = await materialRef.get();
      if (!snap.exists) return 'N/A';
      final data = snap.data();
      final resolved = ProcessLocalizationUtils.resolveLocalizedText(
        data?['name'],
        localeCode: localeCode,
        fallbackLocaleCode: ProcessLocalizationUtils.defaultLocaleCode,
      );
      return resolved.isNotEmpty ? resolved : 'Unnamed Material';
    } catch (_) {
      return 'N/A';
    }
  }

  Future<List<_InventoryItem>> _loadInventoryItems(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    bool hasCoverings,
  ) async {
    final localeCode = ProcessLocalizationUtils.normalizeLocaleCode(
      (Localizations.maybeLocaleOf(context)?.toString() ??
              ProcessLocalizationUtils.defaultLocaleCode)
          .toString(),
    );
    final futures = docs.map((d) async {
      final data = d.data();
      final rawLocRef = data['locationId'];
      DocumentReference<Map<String, dynamic>>? locRef;
      if (rawLocRef is DocumentReference<Map<String, dynamic>>) {
        locRef = rawLocRef;
      } else if (rawLocRef is DocumentReference) {
        locRef = rawLocRef.withConverter<Map<String, dynamic>>(
          fromFirestore: (s, _) => s.data() ?? <String, dynamic>{},
          toFirestore: (m, _) => m,
        );
      }
      Map<String, dynamic>? locData;
      String name = LocationDisplayUtils.resolveConcatenatedNameFromData(
          data, localeCode);
      if (name.isEmpty && locRef != null) {
        final snap = await locRef.get();
        if (snap.exists) {
          locData = snap.data();
          name = LocationDisplayUtils.resolveConcatenatedNameFromData(
            locData ?? const <String, dynamic>{},
            localeCode,
          );
        }
      }

      String display;
      if (hasCoverings) {
        final percent = data['percentLocation'];
        if (percent != null) {
          display = '${((percent as num) * 100).toStringAsFixed(0)}%';
        } else {
          display = '0%';
        }
      } else {
        display = data['quantity']?.toString() ?? '0';
      }

      return _InventoryItem(
        locRef: locRef,
        locData: locData,
        locationName: name,
        displayValue: display,
      );
    });

    final items = await Future.wait(futures);
    items.sort((a, b) => a.locationName.compareTo(b.locationName));
    return items;
  }
}

class _InventoryItem {
  final DocumentReference<Map<String, dynamic>>? locRef;
  final Map<String, dynamic>? locData;
  final String locationName;
  final String displayValue;

  _InventoryItem({
    required this.locRef,
    required this.locData,
    required this.locationName,
    required this.displayValue,
  });
}
