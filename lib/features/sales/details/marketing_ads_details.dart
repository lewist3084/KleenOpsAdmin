import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kleenops_admin/app/routes.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/details_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/home_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/home_navbar_adapter.dart';
import 'package:kleenops_admin/services/storage_service.dart';
import 'package:shared_widgets/containers/container_action.dart';
import 'package:shared_widgets/containers/container_header.dart';
import 'package:kleenops_admin/widgets/viewers/image_viewer.dart';
import 'package:shared_widgets/containers/canvas_top_bookend.dart';
import 'package:shared_widgets/containers/standard_canvas.dart';
import 'package:shared_widgets/drawers/menu_drawer.dart';

class MarketingAdsDetailsScreen extends StatelessWidget {
  final DocumentReference<Map<String, dynamic>> docRef;
  const MarketingAdsDetailsScreen({super.key, required this.docRef});

  DocumentReference<Map<String, dynamic>> get _companyRef =>
      docRef.parent.parent!;

  String _normalizeFileType(Map<String, dynamic> data, String url) {
    final fileType = (data['fileType'] ?? data['mediaType'] ?? '')
        .toString()
        .toLowerCase();
    if (fileType.isNotEmpty) return fileType;
    final ext = p.extension(url).toLowerCase();
    if (ext == '.pdf') return 'document';
    if (const ['.jpg', '.jpeg', '.png', '.gif', '.bmp', '.webp']
        .contains(ext)) {
      return 'image';
    }
    return 'document';
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

  Future<void> _addImage(BuildContext context) async {
    final storage = StorageService();
    final file = await storage.pickAndCompressImage(ImageSource.gallery);
    if (file == null) return;
    final path =
        'company/${_companyRef.id}/marketingMaterial/images/${DateTime.now().millisecondsSinceEpoch}.jpg';
    final url = await storage.uploadFile(file, path);
    await _addFileEntry(
      url: url,
      fileType: 'image',
      name: 'Marketing Image',
    );
  }

  Future<void> _addDocument(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles();
    if (result == null || result.files.isEmpty) return;
    final filePath = result.files.single.path;
    if (filePath == null) return;
    final storage = StorageService();
    final file = File(filePath);
    final fileName = result.files.single.name;
    final path =
        'company/${_companyRef.id}/marketingMaterial/docs/${DateTime.now().millisecondsSinceEpoch}-$fileName';
    final url = await storage.uploadFile(file, path);
    await _addFileEntry(
      url: url,
      fileType: 'document',
      name: 'Marketing Document',
    );
  }

  Future<void> _removeImage(_MarketingMediaEntry entry) async {
    await entry.ref.delete();
    final storage = StorageService();
    final path = storage.extractPathFromUrl(entry.url);
    if (path.isNotEmpty) {
      try {
        await storage.deleteFile(path);
      } catch (_) {}
    }
  }

  Future<void> _removeDocument(_MarketingMediaEntry entry) async {
    await entry.ref.delete();
    final storage = StorageService();
    final path = storage.extractPathFromUrl(entry.url);
    if (path.isNotEmpty) {
      try {
        await storage.deleteFile(path);
      } catch (_) {}
    }
  }

  Future<void> _openDocument(BuildContext context, String url) async {
    try {
      final filename = p.basename(url);
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$filename');
      final bytes = await http.readBytes(Uri.parse(url));
      await file.writeAsBytes(bytes, flush: true);
      await OpenFilex.open(file.path);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Cannot open document: $e')),
        );
      }
    }
  }

  Future<int> _nextOrder() async {
    final snap = await FirebaseFirestore.instance
        .collection('file')
        .where('marketingMaterialRef', isEqualTo: docRef)
        .get();
    if (snap.docs.isEmpty) return 0;
    var maxOrder = 0;
    for (final doc in snap.docs) {
      final raw = doc.data()['order'];
      if (raw is int && raw > maxOrder) maxOrder = raw;
      if (raw is num && raw.toInt() > maxOrder) {
        maxOrder = raw.toInt();
      }
    }
    return maxOrder + 1;
  }

  Future<void> _addFileEntry({
    required String url,
    required String fileType,
    required String name,
  }) async {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return;
    final order = await _nextOrder();
    final fileCollection = FirebaseFirestore.instance.collection('file');
    final doc = fileCollection.doc();
    final storagePath = StorageService().extractPathFromUrl(trimmed).trim();
    final payload = <String, dynamic>{
      'firestorePath': doc.path,
      'downloadUrl': trimmed,
      'fileUrl': trimmed,
      'name': name,
      'mediaType': fileType,
      'fileType': fileType,
      'marketingMaterialRef': docRef,
      'marketingMediaRole': fileType,
      'order': order,
      'isMaster': order == 0,
      'createdAt': FieldValue.serverTimestamp(),
    };
    if (storagePath.isNotEmpty) payload['storagePath'] = storagePath;
    await doc.set(payload);
  }

  Future<_MarketingMedia> _loadMedia() async {
    final snap = await FirebaseFirestore.instance
        .collection('file')
        .where('marketingMaterialRef', isEqualTo: docRef)
        .get();
    if (snap.docs.isEmpty) {
      return const _MarketingMedia(images: [], documents: []);
    }

    final images = <_MarketingMediaEntry>[];
    final documents = <_MarketingMediaEntry>[];
    for (final doc in snap.docs) {
      final data = doc.data();
      final url = (data['downloadUrl'] ?? data['fileUrl'] ?? data['url'])
          .toString()
          .trim();
      if (url.isEmpty) continue;
      final type = _normalizeFileType(data, url);
      final orderRaw = data['order'];
      final order = orderRaw is num ? orderRaw.toInt() : 0;
      final entry = _MarketingMediaEntry(
        url: url,
        ref: doc.reference,
        order: order,
      );
      if (type == 'image') {
        images.add(entry);
      } else {
        documents.add(entry);
      }
    }

    images.sort((a, b) => a.order.compareTo(b.order));
    documents.sort((a, b) => a.order.compareTo(b.order));
    return _MarketingMedia(images: images, documents: documents);
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
            title: 'Material Details',
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
            stream: docRef.snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }
              if (!snapshot.hasData || !snapshot.data!.exists) {
                return const Center(child: CircularProgressIndicator());
              }
              final data = snapshot.data!.data()!;
              final name = data['name'] as String? ?? '';
              final desc = data['description'] as String? ?? '';
              final bottomPadding =
                  (hideChrome ? 16.0 : kBottomNavigationBarHeight + 16.0) +
                      MediaQuery.of(context).padding.bottom;

              return FutureBuilder<_MarketingMedia>(
                future: _loadMedia(),
                builder: (context, mediaSnap) {
                  final media = mediaSnap.data ??
                      const _MarketingMedia(images: [], documents: []);
                  final images = media.images;
                  final documents = media.documents;
                  return SingleChildScrollView(
                    padding: EdgeInsets.only(bottom: bottomPadding),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ContainerHeader(
                          showImage: false,
                          image: null,
                          titleHeader: 'Name',
                          title: name,
                          descriptionHeader: 'Description',
                          description: desc,
                        ),
                        ContainerActionWidget(
                          title: 'Images',
                          actionText: 'Add',
                          onAction: () => _addImage(context),
                          content: images.isEmpty
                              ? const Center(child: Text('No images'))
                              : SizedBox(
                                  height: 160,
                                  child: ListView.builder(
                                    scrollDirection: Axis.horizontal,
                                    itemCount: images.length,
                                    itemBuilder: (context, index) {
                                      final entry = images[index];
                                      return Padding(
                                        padding: const EdgeInsets.all(4.0),
                                        child: Dismissible(
                                          key: ValueKey(entry.url),
                                          direction: DismissDirection.up,
                                          onDismissed: (_) =>
                                              _removeImage(entry),
                                          child: GestureDetector(
                                            onTap: () {
                                              Navigator.of(context).push(
                                                MaterialPageRoute(
                                                  builder: (_) => ImageViewer(
                                                    imageUrl: entry.url,
                                                  ),
                                                ),
                                              );
                                            },
                                            child: Image.network(
                                              entry.url,
                                              width: 150,
                                              fit: BoxFit.cover,
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                        ),
                        ContainerActionWidget(
                          title: 'Documents',
                          actionText: 'Add',
                          onAction: () => _addDocument(context),
                          content: documents.isEmpty
                              ? const Center(child: Text('No documents'))
                              : ListView.builder(
                                  shrinkWrap: true,
                                  physics:
                                      const NeverScrollableScrollPhysics(),
                                  itemCount: documents.length,
                                  itemBuilder: (context, index) {
                                    final entry = documents[index];
                                    final name = p.basename(entry.url);
                                    return Dismissible(
                                      key: ValueKey(entry.url),
                                      direction:
                                          DismissDirection.startToEnd,
                                      onDismissed: (_) =>
                                          _removeDocument(entry),
                                      child: ListTile(
                                        leading: const Icon(
                                            Icons.insert_drive_file),
                                        title: Text(name),
                                        onTap: () =>
                                            _openDocument(context, entry.url),
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
    );
  }
}

class _MarketingMedia {
  final List<_MarketingMediaEntry> images;
  final List<_MarketingMediaEntry> documents;

  const _MarketingMedia({
    required this.images,
    required this.documents,
  });

  bool get hasAny => images.isNotEmpty || documents.isNotEmpty;
}

class _MarketingMediaEntry {
  final String url;
  final DocumentReference<Map<String, dynamic>> ref;
  final int order;

  const _MarketingMediaEntry({
    required this.url,
    required this.ref,
    required this.order,
  });
}

