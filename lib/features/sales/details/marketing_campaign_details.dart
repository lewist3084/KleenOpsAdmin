import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kleenops_admin/app/routes.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/details_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/home_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/home_navbar_adapter.dart';
import 'package:shared_widgets/containers/container_header.dart';
import 'package:shared_widgets/containers/container_action.dart';
import 'package:shared_widgets/tiles/standard_tile_large.dart';
import 'package:shared_widgets/search/search_field_action.dart';
import 'package:shared_widgets/dialogs/dialog_action.dart';
import 'package:kleenops_admin/services/ai_text_adapter.dart';
import 'package:shared_widgets/containers/canvas_top_bookend.dart';
import 'package:shared_widgets/containers/standard_canvas.dart';
import 'package:shared_widgets/drawers/menu_drawer.dart';

class MarketingCampaignDetailsScreen extends StatefulWidget {
  final DocumentReference<Map<String, dynamic>> companyRef;
  final String docId;
  const MarketingCampaignDetailsScreen({
    super.key,
    required this.companyRef,
    required this.docId,
  });

  @override
  State<MarketingCampaignDetailsScreen> createState() =>
      _MarketingCampaignDetailsScreenState();
}

class _MarketingCampaignDetailsScreenState
    extends State<MarketingCampaignDetailsScreen> {
  late final DocumentReference<Map<String, dynamic>> _docRef;

  @override
  void initState() {
    super.initState();
    _docRef = FirebaseFirestore.instance.collection('campaign').doc(widget.docId);
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

  Future<void> _showAddDialog() async {
    final nameCtl = TextEditingController();
    final descCtl = TextEditingController();
    DocumentReference<Map<String, dynamic>>? channelRef;
    DocumentReference<Map<String, dynamic>>? materialRef;
    DocumentReference<Map<String, dynamic>>? dataRef;

    final channelDocs = await FirebaseFirestore.instance
        .collection('channel')
        .orderBy('name')
        .get();
    final materialDocs = await FirebaseFirestore.instance
        .collection('marketingMaterial')
        .orderBy('name')
        .get();
    final dataDocs = await FirebaseFirestore.instance
        .collection('marketingData')
        .orderBy('name')
        .get();

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setDState) => DialogAction(
          title: 'New Element',
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AITextField(
                  controller: nameCtl,
                  labelText: 'Name',
                  minLines: 1,
                  maxLines: 1,
                ),
                const SizedBox(height: 16),
                AITextField(
                  controller: descCtl,
                  labelText: 'Description',
                  minLines: 3,
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                SearchAddSelectDropdown<
                    DocumentReference<Map<String, dynamic>>>(
                  label: 'Channel',
                  items: channelDocs.docs.map((d) => d.reference).toList(),
                  itemLabel: (ref) =>
                      channelDocs.docs
                          .firstWhere((e) => e.reference == ref)
                          .data()['name'] ??
                      'Unnamed',
                  onChanged: (val) => setDState(() => channelRef = val),
                ),
                const SizedBox(height: 16),
                SearchAddSelectDropdown<
                    DocumentReference<Map<String, dynamic>>>(
                  label: 'Ads',
                  items: materialDocs.docs.map((d) => d.reference).toList(),
                  itemLabel: (ref) =>
                      materialDocs.docs
                          .firstWhere((e) => e.reference == ref)
                          .data()['name'] ??
                      'Unnamed',
                  onChanged: (val) => setDState(() => materialRef = val),
                ),
                const SizedBox(height: 16),
                SearchAddSelectDropdown<
                    DocumentReference<Map<String, dynamic>>>(
                  label: 'Marketing Data',
                  items: dataDocs.docs.map((d) => d.reference).toList(),
                  itemLabel: (ref) =>
                      dataDocs.docs
                          .firstWhere((e) => e.reference == ref)
                          .data()['name'] ??
                      'Unnamed',
                  onChanged: (val) => setDState(() => dataRef = val),
                ),
              ],
            ),
          ),
          cancelText: 'Cancel',
          actionText: 'Save',
          onCancel: () => Navigator.of(ctx2).pop(),
          onAction: () async {
            final name = nameCtl.text.trim();
            final desc = descCtl.text.trim();
            if (name.isEmpty) return;
            final elementId =
                FirebaseFirestore.instance.collection('dummy').doc().id;
            await _docRef.update({
              'elements': FieldValue.arrayUnion([
                {
                  'id': elementId,
                  'name': name,
                  'description': desc,
                  if (channelRef != null) 'channelId': channelRef,
                  if (materialRef != null) 'marketingMaterialId': materialRef,
                  if (dataRef != null) 'marketingDataId': dataRef,
                }
              ])
            });
            if (mounted) Navigator.of(ctx2).pop();
          },
        ),
      ),
    );

    nameCtl.dispose();
    descCtl.dispose();
  }

  Future<void> _showEditCampaignDialog({
    required String currentName,
    required String currentDesc,
  }) async {
    final nameCtl = TextEditingController(text: currentName);
    final descCtl = TextEditingController(text: currentDesc);

    await showDialog(
      context: context,
      builder: (ctx) => DialogAction(
        title: 'Edit Campaign',
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtl,
              decoration: const InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descCtl,
              decoration: const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        cancelText: 'Cancel',
        actionText: 'Save',
        onCancel: () => Navigator.of(ctx).pop(),
        onAction: () async {
          final name = nameCtl.text.trim();
          final desc = descCtl.text.trim();
          if (name.isEmpty) return;
          await _docRef.update({'name': name, 'description': desc});
          if (mounted) Navigator.of(ctx).pop();
        },
      ),
    );

    nameCtl.dispose();
    descCtl.dispose();
  }

  Future<Map<String, String>> _resolveNames(
      DocumentReference<Map<String, dynamic>>? channel,
      DocumentReference<Map<String, dynamic>>? material,
      DocumentReference<Map<String, dynamic>>? data) async {
    String c = '';
    String m = '';
    String d = '';
    if (channel != null) {
      final snap = await channel.get();
      c = snap.data()?['name'] ?? '';
    }
    if (material != null) {
      final snap = await material.get();
      m = snap.data()?['name'] ?? '';
    }
    if (data != null) {
      final snap = await data.get();
      d = snap.data()?['name'] ?? '';
    }
    return {'c': c, 'm': m, 'd': d};
  }

  @override
  Widget build(BuildContext context) {
    final bool hideChrome = false;

    Widget buildBottomBar({
      VoidCallback? onAiPressed,
      MenuDrawerSections? menuSections,
    }) {
      if (hideChrome) return const SizedBox.shrink();
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DetailsAppBar(
            title: 'Campaign Details',
            onAiPressed: onAiPressed,
            menuSections: menuSections,
          ),
          const HomeNavBarAdapter(highlightSelected: false),
        ],
      );
    }

    return Scaffold(
      appBar: null,
      bottomNavigationBar: hideChrome
          ? null
          : Consumer(
              builder: (context, ref, _) {
                final menuSections = MenuDrawerSections(
                  actions: [
                    ContentMenuItem(
                      icon: Icons.home_outlined,
                      label: 'Sales Home',
                      onTap: () => context.push(AppRoutePaths.salesHome),
                    ),
                    ContentMenuItem(
                      icon: Icons.sell_outlined,
                      label: 'Sales',
                      onTap: () => context.push(AppRoutePaths.salesSales),
                    ),
                    ContentMenuItem(
                      icon: Icons.campaign_outlined,
                      label: 'Marketing',
                      onTap: () => context.push(AppRoutePaths.salesMarketing),
                    ),
                    ContentMenuItem(
                      icon: Icons.bar_chart_outlined,
                      label: 'Stats',
                      onTap: () => context.push(AppRoutePaths.salesStats),
                    ),
                  ],
                );
                return buildBottomBar(
                  menuSections: menuSections,
                );
              },
            ),
      body: _wrapCanvas(
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: _docRef.snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || !snapshot.data!.exists) {
                return const Center(child: Text('Document not found.'));
              }
              final data = snapshot.data!.data()!;
              final name = data['name'] as String? ?? '';
              final desc = data['description'] as String? ?? '';
              final elements = (data['elements'] as List<dynamic>? ?? [])
                  .whereType<Map<String, dynamic>>()
                  .toList();
              final bottomPadding =
                  (hideChrome ? 16.0 : kBottomNavigationBarHeight + 16.0) +
                      MediaQuery.of(context).padding.bottom;

              return Stack(
                children: [
                  SingleChildScrollView(
                    padding: EdgeInsets.only(bottom: bottomPadding),
                    child: Column(
                      children: [
                        ContainerHeader(
                          titleHeader: 'Campaign',
                          title: name,
                          descriptionHeader: 'Description',
                          description: desc,
                          textIcon: Icons.campaign_outlined,
                          descriptionIcon: Icons.info_outline,
                        ),
                        ContainerActionWidget(
                          title: 'Elements',
                          actionText: 'Add',
                          onAction: _showAddDialog,
                          content: ListView.builder(
                            itemCount: elements.length,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemBuilder: (context, index) {
                              final el = elements[index];
                              final channelRef = el['channelId']
                                  as DocumentReference<Map<String, dynamic>>?;
                              final materialRef = el['marketingMaterialId']
                                  as DocumentReference<Map<String, dynamic>>?;
                              final dataRef = el['marketingDataId']
                                  as DocumentReference<Map<String, dynamic>>?;
                              return FutureBuilder<Map<String, String>>(
                                future: _resolveNames(
                                    channelRef, materialRef, dataRef),
                                builder: (context, nameSnap) {
                                  final cName = nameSnap.data?['c'] ?? '';
                                  final mName = nameSnap.data?['m'] ?? '';
                                  final dName = nameSnap.data?['d'] ?? '';
                                  return StandardTileLargeDart(
                                    imageUrl: '',
                                    showImage: false,
                                    firstLine: el['name'] ?? '',
                                    secondLine: cName,
                                    secondLineIcon: Icons.public,
                                    thirdLine: mName,
                                    thirdLineIcon: Icons.campaign_outlined,
                                    fourthLine: dName,
                                    fourthLineIcon: Icons.description_outlined,
                                  );
                                },
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    right: 16,
                    bottom: 16,
                    child: FloatingActionButton(
                      heroTag: null,
                      child: const Icon(Icons.edit),
                      onPressed: () => _showEditCampaignDialog(
                        currentName: name,
                        currentDesc: desc,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
    );
  }
}
