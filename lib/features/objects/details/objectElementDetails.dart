//  objectElementDetails.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_widgets/containers/container_header.dart';
import 'package:shared_widgets/containers/container_action.dart';
import 'package:shared_widgets/labels/header_info_icon_value.dart';
import '../forms/objectElementForm.dart';
import 'package:kleenops_admin/features/auth/providers/auth_provider.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/details_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/home_navbar_adapter.dart';
import 'package:kleenops_admin/common/utils/image_payload.dart';
import 'package:kleenops_admin/features/processes/utils/process_localization_utils.dart';
import 'package:shared_widgets/tabs/standard_tab.dart';
import 'package:kleenops_admin/services/ai/ai_context_service.dart';
import 'package:kleenops_admin/widgets/ai/ai_screen_context.dart';
import 'package:shared_widgets/containers/canvas_top_bookend.dart';
import 'package:shared_widgets/containers/standard_canvas.dart';
import 'package:kleenops_admin/features/objects/utils/object_element_file_images.dart';
import 'package:kleenops_admin/l10n/app_localizations.dart';

class ObjectElementDetails extends ConsumerStatefulWidget {
  final DocumentReference companyObjectDocRef;
  final Map<String, dynamic> element;

  const ObjectElementDetails({
    super.key,
    required this.companyObjectDocRef,
    required this.element,
  });

  @override
  ConsumerState<ObjectElementDetails> createState() =>
      _ObjectElementDetailsState();
}

class _ObjectElementDetailsState extends ConsumerState<ObjectElementDetails>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final ValueNotifier<int> _tabIndex;
  late Map<String, dynamic> _elementData;
  late String _elementId;
  Future<List<Map<String, dynamic>>>? _fileImagesFuture;

  @override
  void initState() {
    super.initState();
    _elementData = Map<String, dynamic>.from(widget.element);
    _elementId = _resolveElementId(_elementData);
    if (_elementId.isNotEmpty) {
      _elementData['id'] ??= _elementId;
    }
    _fileImagesFuture = _loadElementFileImages();
    _tabController = TabController(length: 3, vsync: this);
    _tabIndex = ValueNotifier<int>(_tabController.index);
    _tabController.addListener(_handleTabSelection);
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabSelection);
    _tabController.dispose();
    _tabIndex.dispose();
    super.dispose();
  }

  void _handleTabSelection() {
    if (!_tabController.indexIsChanging) {
      final nextIndex = _tabController.index;
      if (_tabIndex.value != nextIndex) {
        _tabIndex.value = nextIndex;
      }
    }
  }

  String _resolveElementId(Map<String, dynamic> element) {
    final rawId = element['id'] ?? element['elementId'];
    return rawId?.toString() ?? '';
  }

  Future<void> _refreshElementData() async {
    final elementId = _elementId;
    if (elementId.isEmpty) return;
    final companyPath = widget.companyObjectDocRef.parent.parent?.path;
    if (companyPath == null) return;
    final companyRef = FirebaseFirestore.instance.doc(companyPath);
    final elementDoc = companyRef.collection('objectElement').doc(elementId);
    final snap = await elementDoc.get();
    if (!mounted || !snap.exists) return;
    final data = snap.data();
    if (data == null) return;
    setState(() {
      _elementData = {...data, 'id': elementId};
      _fileImagesFuture = _loadElementFileImages();
    });
  }

  Future<List<Map<String, dynamic>>> _loadElementFileImages() async {
    final elementId = _elementId;
    if (elementId.isEmpty) return const <Map<String, dynamic>>[];
    final companyPath = widget.companyObjectDocRef.parent.parent?.path;
    if (companyPath == null) return const <Map<String, dynamic>>[];
    final companyRef = FirebaseFirestore.instance
        .doc(companyPath)
        .withConverter<Map<String, dynamic>>(
          fromFirestore: (snap, _) => snap.data() ?? <String, dynamic>{},
          toFirestore: (data, _) => data,
        );
    final elementRef = companyRef.collection('objectElement').doc(elementId);
    return ObjectElementFileImages.headerImageEntries(
      companyRef: companyRef,
      elementRef: elementRef,
    );
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

  Widget _buildTabsSection({
    required Widget detailsTab,
    required bool showTabBar,
  }) {
    final loc = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showTabBar)
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
        ValueListenableBuilder<int>(
          valueListenable: _tabIndex,
          builder: (context, tabIndex, child) => _buildCurrentTabBody(
            tabIndex: tabIndex,
            detailsTab: detailsTab,
          ),
        ),
      ],
    );
  }

  Widget _buildCurrentTabBody({
    required int tabIndex,
    required Widget detailsTab,
  }) {
    switch (tabIndex) {
      case 0:
        return detailsTab;
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
    final elementId = _elementId;
    final baseAiContext = AiContextPresets.objectElementDetails(
      objectId: objectId,
      elementId: elementId.isNotEmpty ? elementId : objectId,
      label: elementId.isNotEmpty
          ? elementId
          : loc.objectElementDetailsElementLabel,
    );
    final bottomPadding = hideChrome ? 16.0 : kBottomNavigationBarHeight + 16.0;

    Widget buildBottomBar({VoidCallback? onAiPressed}) {
      if (hideChrome) return const SizedBox.shrink();
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DetailsAppBar(
            title: loc.objectElementDetailsTitle,
            onAiPressed: onAiPressed,
          ),
          const HomeNavBarAdapter(highlightSelected: false),
        ],
      );
    }

    // Retrieve the user's document reference from your provider.
    final userDocRef = ref.watch(userDocRefProvider);

    final elementData = _elementData;

    final localeCode = Localizations.localeOf(context).languageCode;
    final resolvedName = ProcessLocalizationUtils.resolveLocalizedText(
      elementData['name'],
      localeCode: localeCode,
      fallbackLocaleCode: ProcessLocalizationUtils.defaultLocaleCode,
    );
    final name = resolvedName.isNotEmpty
        ? resolvedName
        : loc.objectElementDetailsUnnamedElement;
    final materialRef = elementData['elementMaterialId'] as DocumentReference?;
    final scalarRef = elementData['scalarId'] as DocumentReference?;

    // Obtain the company's document reference from provider
    // (cast it to DocumentReference<Map<String, dynamic>> for type safety).
    final companyRef = ref.watch(companyIdProvider).maybeWhen(
          data: (refValue) => refValue,
          orElse: () => null,
        );

    // This helper will fetch:
    //  1) Whether the parent object has coverage
    //  2) The parent's measurementSystem
    //  3) The material name
    //  4) If coverage is active => percent coverage
    //     else => measurement unit + quantity
    Future<Map<String, String>> getDisplayData() async {
      // 1) Check if parent object has coverage
      bool hasCoverage = false;
      String measurementSystem = 'Standard';

      final parentSnap = await widget.companyObjectDocRef.get();
      if (parentSnap.exists) {
        final parentData = parentSnap.data() as Map<String, dynamic>?;
        if (parentData != null) {
          hasCoverage = (parentData['floorCovering'] == true) ||
              (parentData['wallCovering'] == true) ||
              (parentData['ceilingCovering'] == true);
          final ms = parentData['measurementSystem'] as String?;
          if (ms != null && ms.isNotEmpty) {
            measurementSystem = ms;
          }
        }
      }

      // 2) Material name
      String materialName = loc.objectElementDetailsUnknownMaterial;
      final materialFromElement = ProcessLocalizationUtils.resolveLocalizedText(
        elementData['elementMaterialName'],
        localeCode: localeCode,
        fallbackLocaleCode: ProcessLocalizationUtils.defaultLocaleCode,
      );
      if (materialFromElement.isNotEmpty) {
        materialName = materialFromElement;
      } else if (materialRef != null) {
        final materialSnap = await materialRef.get();
        if (materialSnap.exists) {
          final mData = materialSnap.data() as Map<String, dynamic>?;
          final resolvedMaterial =
              ProcessLocalizationUtils.resolveLocalizedText(
            mData?['name'],
            localeCode: localeCode,
            fallbackLocaleCode: ProcessLocalizationUtils.defaultLocaleCode,
          );
          materialName = resolvedMaterial.isNotEmpty
              ? resolvedMaterial
              : loc.objectElementDetailsUnnamedMaterial;
        }
      }

      // 3) If coverage is active => build percent coverage
      //    Otherwise => build measurement info
      String fieldHeader2 = '';
      String field2 = '';

      if (hasCoverage) {
        // coverage scenario
        fieldHeader2 = loc.objectElementDetailsPercentOfObject;
        final percentObj = elementData['percentObject'];
        double percentVal = 0.0;
        if (percentObj != null) {
          percentVal = double.tryParse(percentObj.toString()) ?? 0.0;
        }
        final percentDisplay = (percentVal * 100).toStringAsFixed(0);
        field2 = '$percentDisplay%';
      } else {
        // measurement scenario
        // fetch scalar to get the correct unit, etc.
        String measurementValue = '';
        String measurementUnit = loc.objectElementDetailsDefaultStandardUnit;

        if (scalarRef != null && companyRef != null) {
          final scalarSnap = await scalarRef.get();
          if (scalarSnap.exists) {
            final scalarData = scalarSnap.data() as Map<String, dynamic>?;
            if (measurementSystem == 'Standard') {
              measurementUnit = scalarData?['standardUnit'] ??
                  loc.objectElementDetailsDefaultStandardUnit;
              double qty = 0.0;
              if (elementData['standardQuantity'] != null) {
                qty = double.tryParse(
                        elementData['standardQuantity'].toString()) ??
                    0.0;
              }
              double roundedQty = (qty * 100).ceil() / 100;
              measurementValue = roundedQty.toStringAsFixed(2);
            } else {
              measurementUnit = scalarData?['metricUnit'] ?? 'm²';
              double qty = 0.0;
              if (elementData['metricQuantity'] != null) {
                qty =
                    double.tryParse(elementData['metricQuantity'].toString()) ??
                        0.0;
              }
              double roundedQty = (qty * 100).ceil() / 100;
              measurementValue = roundedQty.toStringAsFixed(2);
            }
          }
        }
        fieldHeader2 =
            loc.objectElementDetailsMeasurementWithUnit(measurementUnit);
        field2 = measurementValue;
      }

      return {
        'materialName': materialName,
        'fieldHeader2': fieldHeader2,
        'field2': field2,
        'measurementSystem': measurementSystem,
      };
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
        onPressed: () async {
          final rawPercentObject = elementData['percentObject'];
          final normalizedPercentObject = rawPercentObject is num
              ? rawPercentObject.toDouble()
              : (rawPercentObject != null
                  ? double.tryParse(rawPercentObject.toString())
                  : null);

          final existingItem = {
            ...elementData,
            if (normalizedPercentObject != null)
              'percentObject': normalizedPercentObject,
          };

          final didSave = await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ObjectElementForm(
                extraData: {
                  'companyObjectDocRef': widget.companyObjectDocRef,
                  'existingItem': existingItem,
                  'userDocRef': userDocRef,
                },
              ),
            ),
          );
          if (!mounted) return;
          if (didSave == true) {
            await _refreshElementData();
          }
        },
      ),
      body: AiScreenContext(
        context: baseAiContext,
        child: _wrapCanvas(
          FutureBuilder<Map<String, String>>(
            future: getDisplayData(),
            builder: (context, combinedSnapshot) {
              if (!combinedSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final displayData = combinedSnapshot.data!;
              final materialName = displayData['materialName'] ?? 'N/A';
              final secondaryHeader = displayData['fieldHeader2'] ?? '';
              final secondaryValue = displayData['field2'] ?? '';
              final detailRows = <Widget>[
                HeaderInfoIconValue(
                  header: loc.objectElementDetailsMaterialHeader,
                  value: materialName,
                  icon: Icons.hub_outlined,
                ),
              ];

              if (secondaryHeader.trim().isNotEmpty ||
                  secondaryValue.trim().isNotEmpty) {
                detailRows.add(
                  const SizedBox(height: 12),
                );
                detailRows.add(
                  HeaderInfoIconValue(
                    header: secondaryHeader,
                    value: secondaryValue,
                    icon: Icons.straighten_sharp,
                  ),
                );
              }

              // Physical dimensions (L × W × H)
              final dimensionParts = <String>[];
              final useMetric =
                  (displayData['measurementSystem'] ?? 'Standard') == 'Metric';
              final lKey = useMetric ? 'lengthMeters' : 'lengthFeet';
              final wKey = useMetric ? 'widthMeters' : 'widthFeet';
              final hKey = useMetric ? 'heightMeters' : 'heightFeet';
              final dimUnit = useMetric ? 'm' : 'ft';
              final lVal = elementData[lKey];
              final wVal = elementData[wKey];
              final hVal = elementData[hKey];
              if (lVal is num) {
                dimensionParts.add(lVal.toStringAsFixed(1));
              }
              if (wVal is num) {
                dimensionParts.add(wVal.toStringAsFixed(1));
              }
              if (hVal is num) {
                dimensionParts.add(hVal.toStringAsFixed(1));
              }
              if (dimensionParts.isNotEmpty) {
                detailRows.add(const SizedBox(height: 12));
                detailRows.add(
                  HeaderInfoIconValue(
                    header: loc.objectElementDetailsDimensionsHeader,
                    value:
                        '${dimensionParts.join(' \u00d7 ')} $dimUnit',
                    icon: Icons.open_in_full,
                  ),
                );
              }

              final detailsTab = Padding(
                padding: const EdgeInsets.only(top: 12),
                child: ContainerActionWidget(
                  title: loc.commonDetails,
                  content: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: detailRows,
                  ),
                  actionText: '',
                ),
              );

              return FutureBuilder<List<Map<String, dynamic>>>(
                future: _fileImagesFuture ??
                    Future.value(const <Map<String, dynamic>>[]),
                builder: (context, imageSnapshot) {
                  final fileImages =
                      imageSnapshot.data ?? const <Map<String, dynamic>>[];
                  final resolvedImageUrl = primaryImageUrl(fileImages) ?? '';
                  final headerImages = fileImages;

                  return SingleChildScrollView(
                    padding: EdgeInsets.only(
                      bottom: (hideChrome
                              ? 16.0
                              : kBottomNavigationBarHeight + 16.0) +
                          MediaQuery.of(context).padding.bottom,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (!hideChrome)
                          ContainerHeader(
                            image: resolvedImageUrl.isNotEmpty
                                ? resolvedImageUrl
                                : null,
                            images: headerImages,
                            showImage: resolvedImageUrl.isNotEmpty,
                            titleHeader: loc.objectElementDetailsNameHeader,
                            title: name,
                            descriptionHeader: '',
                            description: '',
                            textIcon: Icons.architecture_outlined,
                          ),
                        _buildTabsSection(
                          detailsTab: detailsTab,
                          showTabBar: !hideChrome,
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}
