// lib/features/objects/screens/objectProcessDetails.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../forms/objectProcessForm.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/details_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/home_navbar_adapter.dart';
import 'package:shared_widgets/containers/container_header.dart';
import 'package:shared_widgets/containers/container_action.dart';
import 'package:shared_widgets/labels/header_info_icon_value.dart';
import 'package:shared_widgets/tabs/standard_tab.dart';
import 'package:shared_widgets/tiles/standard_tile_large.dart';
import 'package:shared_widgets/lists/standardView.dart';
import 'package:kleenops_admin/features/processes/utils/process_localization_utils.dart';
import 'package:kleenops_admin/common/utils/image_payload.dart';
import '../utils/company_object_file_images.dart';
import '../utils/object_process_file_images.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kleenops_admin/services/ai/ai_context_service.dart';
import 'package:kleenops_admin/widgets/ai/ai_screen_context.dart';
import 'package:shared_widgets/containers/canvas_top_bookend.dart';
import 'package:shared_widgets/containers/standard_canvas.dart';
import 'package:kleenops_admin/l10n/app_localizations.dart';

class ObjectProcessDetails extends StatefulWidget {
  final DocumentReference<Map<String, dynamic>> companyObjectDocRef;
  final Map<String, dynamic> process;

  const ObjectProcessDetails({
    super.key,
    required this.companyObjectDocRef,
    required this.process,
  });

  @override
  State<ObjectProcessDetails> createState() => _ObjectProcessDetailsState();

  Future<_ObjectProcessDisplayData> _buildDisplayData(
    String localeCode,
  ) async {
    final data = Map<String, dynamic>.from(process);
    final companyRef = companyObjectDocRef.parent.parent;
    var measurementSystem = 'Standard';
    if (companyRef != null) {
      final companySnap = await companyRef.get();
      final companyData = companySnap.data();
      if (companyData != null) {
        measurementSystem =
            (companyData['measurementSystem'] as String? ?? 'Standard').trim();
      }
    }
    final useMetric = measurementSystem.toLowerCase() == 'metric';

    // Resolve object-element names
    final objSnap = await companyObjectDocRef.get();
    final objData = objSnap.data() ?? <String, dynamic>{};
    final elements = (objData['elements'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>();

    // index once for fast lookup
    final Map<String, Map<String, dynamic>> elementsById = {
      for (final e in elements)
        if (e['id'] is String) e['id'] as String: e,
    };

    if (data['processElements'] is List) {
      final names = <String>[];
      for (final raw in data['processElements']) {
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

      data['objectElementNames'] =
          names.isNotEmpty ? names.join(', ') : 'Unnamed';
    } else {
      data['objectElementNames'] = 'Unnamed';
    }

    final bool floorCovering = objData['floorCovering'] == true;
    final bool wallCovering = objData['wallCovering'] == true;
    final bool ceilingCovering = objData['ceilingCovering'] == true;
    final bool hasCoverings = floorCovering || wallCovering || ceilingCovering;

    final totals = companyRef != null
        ? await _buildInventoryTotals(
            companyRef: companyRef,
            objectRef: companyObjectDocRef,
            floorCovering: floorCovering,
            wallCovering: wallCovering,
            ceilingCovering: ceilingCovering,
          )
        : const _InventoryTotals(
            totalObjects: 0.0,
            standardCoverageArea: 0.0,
            metricCoverageArea: 0.0,
          );

    final rawProcessElements =
        data['processElements'] as List<dynamic>? ?? const <dynamic>[];
    final processElements = <Map<String, dynamic>>[];
    for (final raw in rawProcessElements) {
      if (raw is Map<String, dynamic>) {
        processElements.add(raw);
      } else if (raw is String) {
        processElements.add({'elementId': raw});
      }
    }

    final perObjectQty = _sumProcessQuantity(
      processElements,
      useMetric: useMetric,
      elementsById: elementsById,
    );
    final totalQty = hasCoverings
        ? _sumProcessCoveragePercent(processElements, elementsById) *
            (useMetric
                ? totals.metricCoverageArea
                : totals.standardCoverageArea)
        : perObjectQty * totals.totalObjects;

    final unitLabel = _extractProcessUnitLabel(
      (data['objectProcessCostText'] ?? data['processCostText'])?.toString(),
    );

    final objectCache = <String, Map<String, dynamic>?>{};
    final materialRows = await _buildMaterialRows(
      data: data,
      useMetric: useMetric,
      localeCode: localeCode,
      perObjectQty: perObjectQty,
      totalQty: totalQty,
      totalObjects: totals.totalObjects,
      unitLabel: unitLabel,
      objectCache: objectCache,
    );
    final toolRows = await _buildToolRows(
      data: data,
      useMetric: useMetric,
      localeCode: localeCode,
      perObjectQty: perObjectQty,
      totalQty: totalQty,
      totalObjects: totals.totalObjects,
      unitLabel: unitLabel,
      objectCache: objectCache,
    );

    return _ObjectProcessDisplayData(
      data: data,
      materials: materialRows,
      tools: toolRows,
    );
  }

  Widget _buildCostList(
    List<_CostRow> rows, {
    required String emptyMessage,
  }) {
    if (rows.isEmpty) {
      return Text(emptyMessage);
    }

    return StandardView<_CostRow>(
      items: rows,
      itemBuilder: (row) => StandardTileLargeDart(
        imageUrl: row.imageUrl,
        firstLine: row.name,
        firstLineIcon: Icons.category_outlined,
        thirdLine: row.perObjectText,
        thirdLineIcon: Icons.attach_money,
        fourthLine: row.totalText,
        fourthLineIcon: Icons.calculate_outlined,
      ),
      groupBy: (_) => null,
      headerIcon: null,
      onSwipeLeft: null,
      onSwipeRight: null,
      disableGrouping: true,
    );
  }

  double _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  double? _asNullableDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  double _roundToTwo(double value) {
    return (value * 100).ceil() / 100;
  }

  String _formatQuantity(double value) {
    return _roundToTwo(value).toStringAsFixed(2);
  }

  String _formatCostLine({
    required double cost,
    double? minutes,
    double? quantity,
    required String unitLabel,
  }) {
    final costStr = cost.toStringAsFixed(3);
    final timePart =
        minutes != null ? ' (${minutes.toStringAsFixed(0)} min)' : '';
    if (quantity == null || quantity <= 0) {
      return '$costStr$timePart';
    }
    final qtyStr = _formatQuantity(quantity);
    final unitSuffix = unitLabel.trim().isNotEmpty ? ' $unitLabel' : '';
    return '$costStr$timePart/$qtyStr$unitSuffix';
  }

  String _extractProcessUnitLabel(String? costText) {
    if (costText == null || costText.trim().isEmpty) return '';
    final slashIndex = costText.lastIndexOf('/');
    if (slashIndex == -1) return '';
    return costText.substring(slashIndex + 1).trim();
  }

  double _sumProcessQuantity(
    List<Map<String, dynamic>> elements, {
    required bool useMetric,
    Map<String, Map<String, dynamic>>? elementsById,
  }) {
    final key = useMetric ? 'metricQuantity' : 'standardQuantity';
    var total = 0.0;
    for (final element in elements) {
      final directQty = _asNullableDouble(element[key]);
      if (directQty != null) {
        total += directQty;
        continue;
      }
      if (elementsById != null) {
        final id = element['elementId'];
        if (id is String && id.isNotEmpty) {
          final fallbackQty = _asNullableDouble(elementsById[id]?[key]);
          if (fallbackQty != null) {
            total += fallbackQty;
          }
        }
      }
    }
    return total;
  }

  double _sumProcessCoveragePercent(
    List<Map<String, dynamic>> elements,
    Map<String, Map<String, dynamic>> elementsById,
  ) {
    var total = 0.0;
    for (final element in elements) {
      final percent = _asNullableDouble(element['percent']) ??
          (() {
            final id = element['elementId'];
            if (id is String && id.isNotEmpty) {
              return _asNullableDouble(elementsById[id]?['percentObject']);
            }
            return null;
          })() ??
          1.0;
      total += percent;
    }
    return total;
  }

  double _resolveAggregateMultiplier({
    required double perObjectQty,
    required double totalQty,
    required double totalObjects,
  }) {
    if (perObjectQty > 0 && totalQty > 0) {
      return totalQty / perObjectQty;
    }
    if (totalObjects > 0) {
      return totalObjects;
    }
    return 0.0;
  }

  DocumentReference? _resolveDocRef(dynamic rawRef) {
    if (rawRef is DocumentReference) return rawRef;
    if (rawRef is String && rawRef.trim().isNotEmpty) {
      return FirebaseFirestore.instance.doc(rawRef.trim());
    }
    return null;
  }

  Future<Map<String, dynamic>?> _loadCompanyObjectData(
    dynamic rawRef,
    Map<String, Map<String, dynamic>?> cache,
  ) async {
    final ref = _resolveDocRef(rawRef);
    if (ref == null) return null;
    if (cache.containsKey(ref.path)) return cache[ref.path];
    try {
      final snap = await ref.get();
      final data = snap.data() as Map<String, dynamic>?;
      cache[ref.path] = data;
      return data;
    } catch (_) {
      cache[ref.path] = null;
      return null;
    }
  }

  Future<String> _resolveObjectImageUrl({
    required DocumentReference? objectRef,
    required Map<String, dynamic>? objectData,
  }) async {
    if (objectRef is! DocumentReference<Map<String, dynamic>>) {
      return '';
    }
    final companyRef = objectRef.parent.parent;
    if (companyRef is! DocumentReference<Map<String, dynamic>>) {
      return '';
    }
    final fileUrl = await CompanyObjectFileImages.primaryHeaderImageUrl(
      companyRef: companyRef,
      objectId: objectRef.id,
    );
    return fileUrl;
  }

  String _resolveDisplayName(
    Map<String, dynamic>? objectData,
    Map<String, dynamic> entry,
    String localeCode,
  ) {
    final resolved = ProcessLocalizationUtils.resolveLocalizedText(
      objectData?['localName'] ??
          objectData?['name'] ??
          entry['name'] ??
          entry['materialName'] ??
          entry['toolName'],
      localeCode: localeCode,
      fallbackLocaleCode: ProcessLocalizationUtils.defaultLocaleCode,
    ).trim();
    if (resolved.isNotEmpty) return resolved;
    final fallback = objectData?['localName']?.toString().trim() ??
        objectData?['name']?.toString().trim() ??
        entry['name']?.toString().trim() ??
        entry['materialName']?.toString().trim() ??
        entry['toolName']?.toString().trim() ??
        '';
    return fallback.isNotEmpty ? fallback : 'Unnamed';
  }

  Future<List<_CostRow>> _buildMaterialRows({
    required Map<String, dynamic> data,
    required bool useMetric,
    required String localeCode,
    required double perObjectQty,
    required double totalQty,
    required double totalObjects,
    required String unitLabel,
    required Map<String, Map<String, dynamic>?> objectCache,
  }) async {
    final raw = data['materialUsage'] ?? data['materialStats'];
    final entries = (raw is List ? raw : const <dynamic>[])
        .whereType<Map<String, dynamic>>();
    if (entries.isEmpty) return const [];

    final multiplier = _resolveAggregateMultiplier(
      perObjectQty: perObjectQty,
      totalQty: totalQty,
      totalObjects: totalObjects,
    );

    final futures = entries.map((entry) async {
      final rawRef = entry['materialId'] ?? entry['objectId'] ?? entry['id'];
      final objectRef = _resolveDocRef(rawRef);
      final objectData = await _loadCompanyObjectData(rawRef, objectCache);
      final name = _resolveDisplayName(objectData, entry, localeCode);
      final imageUrl = await _resolveObjectImageUrl(
        objectRef: objectRef,
        objectData: objectData,
      );

      final objectStandardCost =
          _asNullableDouble(entry['objectStandardMaterialCost']);
      final objectMetricCost =
          _asNullableDouble(entry['objectMetricMaterialCost']);
      final fallbackStandard =
          _asNullableDouble(entry['standardMaterialCost']) ??
              _asNullableDouble(entry['materialCost']);
      final fallbackMetric = _asNullableDouble(entry['metricMaterialCost']);

      final perObjectCost = useMetric
          ? objectMetricCost ??
              objectStandardCost ??
              fallbackMetric ??
              fallbackStandard ??
              0.0
          : objectStandardCost ??
              objectMetricCost ??
              fallbackStandard ??
              fallbackMetric ??
              0.0;

      final perObjectText = _formatCostLine(
        cost: perObjectCost,
        quantity: perObjectQty,
        unitLabel: unitLabel,
      );
      final totalCost = perObjectCost * multiplier;
      final totalText = _formatCostLine(
        cost: totalCost,
        quantity: totalQty,
        unitLabel: unitLabel,
      );

      return _CostRow(
        imageUrl: imageUrl,
        name: name,
        perObjectText: perObjectText,
        totalText: totalText,
      );
    }).toList();

    final rows = await Future.wait(futures);
    rows.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return rows;
  }

  Future<List<_CostRow>> _buildToolRows({
    required Map<String, dynamic> data,
    required bool useMetric,
    required String localeCode,
    required double perObjectQty,
    required double totalQty,
    required double totalObjects,
    required String unitLabel,
    required Map<String, Map<String, dynamic>?> objectCache,
  }) async {
    final raw = data['toolUsage'] ?? data['toolStats'];
    final entries = (raw is List ? raw : const <dynamic>[])
        .whereType<Map<String, dynamic>>();
    if (entries.isEmpty) return const [];

    final multiplier = _resolveAggregateMultiplier(
      perObjectQty: perObjectQty,
      totalQty: totalQty,
      totalObjects: totalObjects,
    );

    final futures = entries.map((entry) async {
      final rawRef = entry['toolId'] ?? entry['tool'];
      final objectRef = _resolveDocRef(rawRef);
      final objectData = await _loadCompanyObjectData(rawRef, objectCache);
      final name = _resolveDisplayName(objectData, entry, localeCode);
      final imageUrl = await _resolveObjectImageUrl(
        objectRef: objectRef,
        objectData: objectData,
      );

      final objectStandardCost =
          _asNullableDouble(entry['objectStandardToolCost']) ??
              _asNullableDouble(entry['objectToolUsageCost']);
      final objectMetricCost = _asNullableDouble(entry['objectMetricToolCost']);
      final perObjectCost = useMetric
          ? objectMetricCost ?? objectStandardCost ?? 0.0
          : objectStandardCost ?? objectMetricCost ?? 0.0;

      final objectStandardMinutes =
          _asNullableDouble(entry['objectStandardToolTime']) ??
              _asNullableDouble(entry['objectToolUsageTime']);
      final objectMetricMinutes =
          _asNullableDouble(entry['objectMetricToolTime']);
      final perObjectMinutes = useMetric
          ? objectMetricMinutes ?? objectStandardMinutes
          : objectStandardMinutes ?? objectMetricMinutes;

      final perObjectText = _formatCostLine(
        cost: perObjectCost,
        minutes: perObjectMinutes,
        quantity: perObjectQty,
        unitLabel: unitLabel,
      );
      final totalCost = perObjectCost * multiplier;
      final totalMinutes =
          perObjectMinutes != null ? perObjectMinutes * multiplier : null;
      final totalText = _formatCostLine(
        cost: totalCost,
        minutes: totalMinutes,
        quantity: totalQty,
        unitLabel: unitLabel,
      );

      return _CostRow(
        imageUrl: imageUrl,
        name: name,
        perObjectText: perObjectText,
        totalText: totalText,
      );
    }).toList();

    final rows = await Future.wait(futures);
    rows.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return rows;
  }

  double _sumInventoryQuantity(
    Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    var total = 0.0;
    for (final doc in docs) {
      final qty = doc.data()['quantity'];
      if (qty is num) {
        total += qty.toDouble();
      }
    }
    return total;
  }

  Future<_InventoryTotals> _buildInventoryTotals({
    required DocumentReference<Map<String, dynamic>> companyRef,
    required DocumentReference<Map<String, dynamic>> objectRef,
    required bool floorCovering,
    required bool wallCovering,
    required bool ceilingCovering,
  }) async {
    final inventorySnap = await companyRef
        .collection('objectInventory')
        .where('companyObjectId', isEqualTo: objectRef)
        .get();
    final inventoryDocs = inventorySnap.docs;
    final totalObjects = _sumInventoryQuantity(inventoryDocs);
    final needsCoverage = floorCovering || wallCovering || ceilingCovering;
    if (!needsCoverage || inventoryDocs.isEmpty) {
      return _InventoryTotals(
        totalObjects: totalObjects,
        standardCoverageArea: 0.0,
        metricCoverageArea: 0.0,
      );
    }

    final locationRefs = <String, DocumentReference<Map<String, dynamic>>>{};
    for (final doc in inventoryDocs) {
      final data = doc.data();
      final rawRef = data['locationId'];
      if (rawRef is DocumentReference<Map<String, dynamic>>) {
        locationRefs[rawRef.path] = rawRef;
      } else if (rawRef is DocumentReference) {
        locationRefs[rawRef.path] = rawRef.withConverter<Map<String, dynamic>>(
          fromFirestore: (s, _) => s.data() ?? <String, dynamic>{},
          toFirestore: (m, _) => m,
        );
      } else if (rawRef is String && rawRef.trim().isNotEmpty) {
        final ref = companyRef.collection('location').doc(rawRef.trim());
        locationRefs[ref.path] = ref;
      }
    }

    final locationAreas = <String, _LocationAreas>{};
    if (locationRefs.isNotEmpty) {
      final locationSnaps =
          await Future.wait(locationRefs.values.map((ref) => ref.get()));
      for (final snap in locationSnaps) {
        if (!snap.exists) continue;
        final data = snap.data() ?? <String, dynamic>{};
        final standardFloor = _asDouble(data['standardFloorArea']) ??
            _asDouble(data['standardArea']) ??
            0.0;
        final metricFloor = _asDouble(data['metricFloorArea']) ??
            _asDouble(data['metricArea']) ??
            0.0;
        final standardWall = _asDouble(data['standardWallArea']) ?? 0.0;
        final metricWall = _asDouble(data['metricWallArea']) ?? 0.0;

        locationAreas[snap.reference.path] = _LocationAreas(
          standardFloor: standardFloor,
          metricFloor: metricFloor,
          standardWall: standardWall,
          metricWall: metricWall,
        );
      }
    }

    double standardCoverage = 0.0;
    double metricCoverage = 0.0;
    final bool floorCalc = floorCovering || ceilingCovering;

    for (final doc in inventoryDocs) {
      final data = doc.data();
      final pct = _asDouble(data['percentLocation']) ?? 1.0;
      final locRef = data['locationId'];
      String? locPath;
      if (locRef is DocumentReference) {
        locPath = locRef.path;
      } else if (locRef is String && locRef.trim().isNotEmpty) {
        locPath = companyRef.collection('location').doc(locRef.trim()).path;
      }
      final locAreas = locPath == null ? null : locationAreas[locPath];

      if (floorCalc) {
        final invStdFloor = _asNullableDouble(data['standardFloorArea']);
        final invMetFloor = _asNullableDouble(data['metricFloorArea']);
        if (invStdFloor != null || invMetFloor != null) {
          standardCoverage += invStdFloor ?? 0.0;
          metricCoverage += invMetFloor ?? 0.0;
        } else if (locAreas != null) {
          standardCoverage += locAreas.standardFloor * pct;
          metricCoverage += locAreas.metricFloor * pct;
        }
      }

      if (wallCovering) {
        final invStdWall = _asNullableDouble(data['standardWallArea']);
        final invMetWall = _asNullableDouble(data['metricWallArea']);
        if (invStdWall != null || invMetWall != null) {
          standardCoverage += invStdWall ?? 0.0;
          metricCoverage += invMetWall ?? 0.0;
        } else if (locAreas != null) {
          standardCoverage += locAreas.standardWall * pct;
          metricCoverage += locAreas.metricWall * pct;
        }
      }
    }

    return _InventoryTotals(
      totalObjects: totalObjects,
      standardCoverageArea: standardCoverage,
      metricCoverageArea: metricCoverage,
    );
  }
}

class _ObjectProcessDetailsState extends State<ObjectProcessDetails>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_handleTabSelection);
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabSelection);
    _tabController.dispose();
    super.dispose();
  }

  void _handleTabSelection() {
    if (!_tabController.indexIsChanging) {
      setState(() {});
    }
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

  Widget _buildTabsSection({required Widget detailsContent}) {
    final loc = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        StandardTabBar(
          controller: _tabController,
          isScrollable: false,
          labelStyle: theme.textTheme.titleMedium,
          tabs: [
            Tab(text: loc.commonDetails),
            Tab(text: loc.commonCharts),
            Tab(text: loc.commonRecords),
          ],
        ),
        _buildCurrentTabBody(detailsContent: detailsContent),
      ],
    );
  }

  Widget _buildCurrentTabBody({required Widget detailsContent}) {
    switch (_tabController.index) {
      case 0:
        return detailsContent;
      case 1:
        return _buildPlaceholder(AppLocalizations.of(context)!.commonCharts);
      case 2:
      default:
        return _buildPlaceholder(AppLocalizations.of(context)!.commonRecords);
    }
  }

  Widget _buildPlaceholder(String label) {
    final loc = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Text(loc.commonPlaceholder(label)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final bool hideChrome = false;
    final objectId = widget.companyObjectDocRef.id;
    final docId = widget.process['id']?.toString() ?? '';
    final localeCode = Localizations.localeOf(context).languageCode;
    final baseAiContext = AiContextPresets.objectProcessDetails(
      objectId: objectId,
      processId: docId.isNotEmpty ? docId : objectId,
      label: docId.isNotEmpty ? docId : loc.nav_processes,
    );

    Widget buildBottomBar({VoidCallback? onAiPressed}) {
      if (hideChrome) return const SizedBox.shrink();
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DetailsAppBar(
            title: loc.objectProcessDetailsTitle,
            onAiPressed: onAiPressed,
          ),
          const HomeNavBarAdapter(highlightSelected: false),
        ],
      );
    }

    return Scaffold(
      appBar: null,
      bottomNavigationBar: Consumer(
        builder: (context, ref, _) {
          final controller = ref.read(aiCanvasControllerProvider);
          return buildBottomBar(onAiPressed: controller.toggle);
        },
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.edit),
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ObjectProcessForm(
                companyId: widget.companyObjectDocRef.parent.parent!,
                objectId: widget.companyObjectDocRef.id,
                docId: docId,
              ),
            ),
          );
        },
      ),
      body: AiScreenContext(
        context: baseAiContext,
        child: _wrapCanvas(
          FutureBuilder<_ObjectProcessDisplayData>(
            future: widget._buildDisplayData(localeCode),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snap.hasData || snap.data!.data.isEmpty) {
                return Center(
                    child: Text(loc.objectProcessDetailsNoDetailsAvailable));
              }
              final displayData = snap.data!;
              final data = displayData.data;
              final statement = ProcessLocalizationUtils.resolveLocalizedText(
                data['objectProcessName'] ??
                    data['name'] ??
                    data['processName'],
                localeCode: localeCode,
                fallbackLocaleCode: ProcessLocalizationUtils.defaultLocaleCode,
              );
              final instructions =
                  ProcessLocalizationUtils.resolveLocalizedText(
                data['objectProcessDescription'] ?? data['description'],
                localeCode: localeCode,
                fallbackLocaleCode: ProcessLocalizationUtils.defaultLocaleCode,
              );
              final processName = ProcessLocalizationUtils.resolveLocalizedText(
                data['processName'] ?? data['name'],
                localeCode: localeCode,
                fallbackLocaleCode: ProcessLocalizationUtils.defaultLocaleCode,
              );

              final detailsContent = Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 12),
                  ContainerActionWidget(
                    title: loc.commonDetails,
                    content: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        HeaderInfoIconValue(
                          header: loc.nav_processes,
                          value: processName.isNotEmpty
                              ? processName
                              : loc.commonUnnamed,
                          icon: Icons.route_outlined,
                        ),
                        const SizedBox(height: 8),
                        HeaderInfoIconValue(
                          header: loc.objectsDetailsSectionElements,
                          value:
                              data['objectElementNames'] ?? loc.commonUnnamed,
                          icon: Icons.insert_link,
                        ),
                      ],
                    ),
                    actionText: '',
                  ),
                  ContainerActionWidget(
                    title: loc.processesDetailsHeaderMaterials,
                    content: widget._buildCostList(
                      displayData.materials,
                      emptyMessage: loc.objectProcessDetailsNoMaterialsFound,
                    ),
                    actionText: '',
                  ),
                  ContainerActionWidget(
                    title: loc.processesDetailsHeaderTools,
                    content: widget._buildCostList(
                      displayData.tools,
                      emptyMessage: loc.objectProcessDetailsNoToolsFound,
                    ),
                    actionText: '',
                  ),
                ],
              );

              final bottomPadding =
                  hideChrome ? 16.0 : kBottomNavigationBarHeight + 16.0;

              return SingleChildScrollView(
                padding: EdgeInsets.only(
                  bottom: bottomPadding + MediaQuery.of(context).padding.bottom,
                ),
                child: hideChrome
                    ? _buildCurrentTabBody(detailsContent: detailsContent)
                    : FutureBuilder<List<Map<String, dynamic>>>(
                        future: ObjectProcessFileImages.headerImageEntries(
                          companyRef: widget.companyObjectDocRef.parent.parent!
                              .withConverter<Map<String, dynamic>>(
                            fromFirestore: (snap, _) =>
                                snap.data() ?? <String, dynamic>{},
                            toFirestore: (data, _) => data,
                          ),
                          processRef: widget.companyObjectDocRef.parent.parent!
                              .collection('objectProcess')
                              .doc(docId),
                        ),
                        builder: (context, imageSnap) {
                          final fileImages =
                              imageSnap.data ?? const <Map<String, dynamic>>[];
                          final headerImages = fileImages;
                          final headerImageUrl =
                              primaryImageUrl(headerImages) ?? '';

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              ContainerHeader(
                                image: headerImageUrl,
                                images: headerImages,
                                showImage: headerImageUrl.isNotEmpty,
                                titleHeader:
                                    loc.objectProcessDetailsStatementHeader,
                                title: statement,
                                descriptionHeader:
                                    loc.objectProcessDetailsInstructionsHeader,
                                description: instructions,
                                textIcon: Icons.content_paste,
                                descriptionIcon: Icons.info_outline,
                              ),
                              _buildTabsSection(
                                detailsContent: detailsContent,
                              ),
                            ],
                          );
                        },
                      ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ObjectProcessDisplayData {
  final Map<String, dynamic> data;
  final List<_CostRow> materials;
  final List<_CostRow> tools;

  const _ObjectProcessDisplayData({
    required this.data,
    required this.materials,
    required this.tools,
  });
}

class _CostRow {
  final String imageUrl;
  final String name;
  final String perObjectText;
  final String totalText;

  const _CostRow({
    required this.imageUrl,
    required this.name,
    required this.perObjectText,
    required this.totalText,
  });
}

class _LocationAreas {
  final double standardFloor;
  final double metricFloor;
  final double standardWall;
  final double metricWall;

  const _LocationAreas({
    required this.standardFloor,
    required this.metricFloor,
    required this.standardWall,
    required this.metricWall,
  });
}

class _InventoryTotals {
  final double totalObjects;
  final double standardCoverageArea;
  final double metricCoverageArea;

  const _InventoryTotals({
    required this.totalObjects,
    required this.standardCoverageArea,
    required this.metricCoverageArea,
  });
}
