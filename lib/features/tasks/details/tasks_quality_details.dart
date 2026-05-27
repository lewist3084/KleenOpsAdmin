// tasks_quality_details.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/details_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/home_navbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/forms/cancel_save_adapter.dart';
import 'package:kleenops_admin/services/ai_text_adapter.dart';
import 'package:shared_widgets/services/firestore_service.dart';
import 'package:kleenops_admin/services/ai/ai_context_service.dart';
import 'package:kleenops_admin/widgets/ai/ai_screen_context.dart';
import 'package:shared_widgets/containers/container_action.dart';
import 'package:shared_widgets/containers/container_header.dart';
import 'package:shared_widgets/containers/canvas_top_bookend.dart';
import 'package:shared_widgets/containers/standard_canvas.dart';
import 'package:shared_widgets/drawers/menu_drawer.dart';
import 'package:kleenops_admin/theme/palette.dart';
import 'package:shared_widgets/viewers/file_carousel_viewer.dart';
import 'package:kleenops_admin/common/utils/snackbar_service.dart';

class TasksQualityDetails extends ConsumerStatefulWidget {
  final DocumentReference<Map<String, dynamic>> companyId;
  final String docId;

  const TasksQualityDetails({
    super.key,
    required this.companyId,
    required this.docId,
  });

  @override
  ConsumerState<TasksQualityDetails> createState() =>
      _TasksQualityDetailsState();
}

class _TasksQualityDetailsState extends ConsumerState<TasksQualityDetails> {
  Future<DocumentSnapshot<Map<String, dynamic>>>? _docFuture;
  Future<List<FileCarouselItem>>? _mediaFuture;
  String? _cachedKey;

  bool? _employeeAgrees;
  final TextEditingController _responseController = TextEditingController();

  @override
  void dispose() {
    _responseController.dispose();
    super.dispose();
  }

  void _ensureFutures(DocumentReference<Map<String, dynamic>> timelineDocRef) {
    final key = timelineDocRef.path;
    if (_cachedKey == key && _docFuture != null) return;
    _cachedKey = key;
    _docFuture = timelineDocRef.get();
    _mediaFuture = null;
  }

  Future<List<FileCarouselItem>> _ensureMediaFuture(
    DocumentReference<Map<String, dynamic>> timelineDocRef,
  ) {
    if (_mediaFuture != null) return _mediaFuture!;
    _mediaFuture = _loadMediaItems(timelineDocRef);
    return _mediaFuture!;
  }

  static const List<String> _imageExtensions = <String>[
    'jpg',
    'jpeg',
    'png',
    'gif',
    'bmp',
    'webp',
  ];
  static const List<String> _videoExtensions = <String>[
    'mp4',
    'mov',
    'avi',
    'mkv',
    'wmv',
    'webm',
  ];

  bool _loading = false;

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

  void _onAgreeChoice(bool agrees) {
    setState(() => _employeeAgrees = agrees);
  }

  Future<void> _saveResponse() async {
    if (_loading) return;

    if (_employeeAgrees == null) {
      SnackbarService.instance.showSnackBar(
        const SnackBar(
          duration: Duration(seconds: 5),
          content: Text('Please select Agree or Disagree.'),
        ),
      );
      return;
    }

    final disagrees = _employeeAgrees == false;
    final explanation = _responseController.text.trim();
    if (disagrees && explanation.isEmpty) {
      SnackbarService.instance.showSnackBar(
        const SnackBar(
          duration: Duration(seconds: 5),
          content: Text('Please add information about why you disagree.'),
        ),
      );
      return;
    }

    setState(() => _loading = true);

    // Admin: TOP-LEVEL `timeline` collection.
    final timelineDocRef =
        FirebaseFirestore.instance.collection('timeline').doc(widget.docId);

    try {
      final data = <String, dynamic>{
        'employeeAgrees': _employeeAgrees,
        'acknowledged': FieldValue.serverTimestamp(),
        'opened': true,
        'reviewed': true,
        'reviewedAt': FieldValue.serverTimestamp(),
        if (disagrees) 'employeeResponse': explanation,
      };

      await FirestoreService().saveDocument(
        collectionRef: timelineDocRef.parent,
        data: data,
        docId: widget.docId,
      );

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      SnackbarService.instance.showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 5),
          content: Text('Failed to save response: $e'),
        ),
      );
    }
  }

  Widget _buildResponseSection(BuildContext context, Map<String, dynamic> data) {
    final primary2 = AppPaletteScope.of(context).primary2;
    final hasAgreeFlag = data['employeeAgrees'] != null;
    final responded = hasAgreeFlag || data['acknowledged'] != null;

    if (responded) {
      final agreed = data['employeeAgrees'] == true;
      final response = (data['employeeResponse'] as String?)?.trim() ?? '';
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 16),
          ContainerActionWidget(
            title: 'Your Response',
            actionText: '',
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasAgreeFlag
                      ? (agreed
                          ? 'You agreed with this quality report.'
                          : 'You disagreed with this quality report.')
                      : 'You acknowledged this quality report.',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                if (response.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(response),
                ],
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        ContainerActionWidget(
          title: 'Do you agree with this report?',
          actionText: '',
          content: CancelSaveBar(
            cancelLabel: 'Disagree',
            saveLabel: 'Agree',
            showBorder: false,
            showTopBorder: false,
            onCancel: () => _onAgreeChoice(false),
            onSave: () async => _onAgreeChoice(true),
          ),
        ),
        if (_employeeAgrees != null)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: ContainerActionWidget(
              actionText: '',
              padding: const EdgeInsets.all(16),
              content: _employeeAgrees == true
                  ? const Text(
                      'Press Save to confirm you agree with this report.',
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Add information about why you disagree:',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 12),
                        AITextField(
                          labelText: 'Additional information',
                          controller: _responseController,
                          onChanged: (_) {},
                        ),
                      ],
                    ),
            ),
          ),
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: ElevatedButton(
            onPressed: (_loading || _employeeAgrees == null)
                ? null
                : _saveResponse,
            style: ElevatedButton.styleFrom(
              backgroundColor: primary2,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(52),
              textStyle: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            child: _loading
                ? const SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  String? _stringFromData(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key];
      if (value is String) {
        final trimmed = value.trim();
        if (trimmed.isNotEmpty) return trimmed;
      }
    }
    return null;
  }

  int? _intFromData(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key];
      if (value is int) return value;
      if (value is num) return value.toInt();
    }
    return null;
  }

  String _extensionFromUrl(String url) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return '';
    final path = Uri.tryParse(trimmed)?.path ?? trimmed;
    final dotIdx = path.lastIndexOf('.');
    final slashIdx = path.lastIndexOf('/');
    if (dotIdx < 0 || dotIdx < slashIdx) return '';
    return path.substring(dotIdx + 1).toLowerCase();
  }

  String? _thumbnailFromData(Map<String, dynamic> data) {
    return _stringFromData(data, const [
      'thumbnailUrl',
      'videoThumbnail',
      'thumbUrl',
      'thumbnail',
    ]);
  }

  String? _titleFromData(Map<String, dynamic> data, String url) {
    final candidate = _stringFromData(data, const [
      'name',
      'sourceFileName',
      'fileName',
      'title',
    ]);
    if (candidate != null && candidate.isNotEmpty) return candidate;
    final path = Uri.tryParse(url)?.path ?? url;
    final slashIdx = path.lastIndexOf('/');
    final base = slashIdx < 0 ? path : path.substring(slashIdx + 1);
    return base.isNotEmpty ? base : null;
  }

  String _resolveFileType(Map<String, dynamic> data, String url) {
    final fileType = (data['fileType'] ?? '').toString().toLowerCase();
    if (fileType.isNotEmpty) {
      if (fileType == 'document') {
        final ext = _extensionFromUrl(url);
        return ext == 'pdf' ? 'pdf' : 'document';
      }
      return fileType;
    }
    final mediaType = (data['mediaType'] ?? '').toString().toLowerCase();
    if (mediaType == 'image') return 'image';
    if (mediaType == 'video') return 'video';
    if (mediaType == 'document') {
      final ext = _extensionFromUrl(url);
      return ext == 'pdf' ? 'pdf' : 'document';
    }
    final ext = _extensionFromUrl(url);
    if (_imageExtensions.contains(ext)) return 'image';
    if (_videoExtensions.contains(ext)) return 'video';
    if (ext == 'pdf') return 'pdf';
    return 'document';
  }

  FileCarouselItem? _carouselItemForFile({
    required String url,
    required String fileType,
    String? thumbnailUrl,
    String? title,
  }) {
    switch (fileType) {
      case 'video':
        return FileCarouselItem.video(
          videoUrl: url,
          thumbnailUrl: thumbnailUrl,
        );
      case 'pdf':
        return FileCarouselItem.pdf(
          pdfUrl: url,
          thumbnailUrl: thumbnailUrl,
          title: title,
        );
      case 'document':
        return FileCarouselItem.document(
          fileUrl: url,
          thumbnailUrl: thumbnailUrl,
          title: title,
        );
      case 'image':
      default:
        return FileCarouselItem.image(imageUrl: url);
    }
  }

  List<FileCarouselItem> _fileDocsToItems(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final ordered = <_OrderedMediaItem>[];
    var fallbackOrder = 0;
    for (final doc in docs) {
      final data = doc.data();
      final url = _stringFromData(data, const [
        'downloadUrl',
        'url',
        'fileUrl',
        'videoUrl',
        'imageUrl',
      ]);
      if (url == null || url.isEmpty) continue;
      final fileType = _resolveFileType(data, url);
      final thumb = _thumbnailFromData(data);
      final title = _titleFromData(data, url);
      final item = _carouselItemForFile(
        url: url,
        fileType: fileType,
        thumbnailUrl: thumb,
        title: title,
      );
      if (item == null) continue;
      final order = _intFromData(data, const ['order']) ?? fallbackOrder;
      ordered.add(_OrderedMediaItem(order: order, item: item));
      fallbackOrder += 1;
    }

    ordered.sort((a, b) => a.order.compareTo(b.order));
    return ordered.map((entry) => entry.item).toList();
  }

  Future<List<FileCarouselItem>> _loadMediaItems(
    DocumentReference<Map<String, dynamic>> qualityRef,
  ) async {
    try {
      // Admin uses TOP-LEVEL `file` collection.
      final snap = await FirebaseFirestore.instance
          .collection('file')
          .where('qualityId', isEqualTo: qualityRef)
          .get();
      final items = _fileDocsToItems(snap.docs);
      if (items.isNotEmpty) return items;
    } catch (_) {}
    return const <FileCarouselItem>[];
  }

  @override
  Widget build(BuildContext context) {
    const bool hideChrome = false;
    final timelineDocRef =
        FirebaseFirestore.instance.collection('timeline').doc(widget.docId);
    _ensureFutures(timelineDocRef);
    final baseAiContext = AiContextPresets.detailScreen(
      key: 'tasksQualityDetails',
      sectionKey: 'tasks',
      entityId: widget.docId,
      label: widget.docId,
      entityPath: timelineDocRef.path,
    );

    Widget buildBottomBar({
      VoidCallback? onAiPressed,
      MenuDrawerSections? menuSections,
    }) {
      if (hideChrome) return const SizedBox.shrink();
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DetailsAppBar(
            title: 'Acknowledge Quality',
            onAiPressed: onAiPressed,
            menuSections: menuSections,
          ),
          const HomeNavBarAdapter(highlightSelected: false),
        ],
      );
    }

    return Scaffold(
      appBar: null,
      body: AiScreenContext(
        context: baseAiContext,
        child: _wrapCanvas(
          FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            future: _docFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(
                  child: Text('Error loading issue: ${snapshot.error}'),
                );
              }

              if (!snapshot.hasData || !(snapshot.data?.exists ?? false)) {
                return const Center(child: Text('Quality issue not found.'));
              }

              final data = snapshot.data!.data() ?? <String, dynamic>{};
              final issueName = [
                data['name'] as String?,
                data['title'] as String?,
              ].map((value) => value?.trim()).firstWhere(
                    (value) => value != null && value.isNotEmpty,
                    orElse: () => 'Quality Issue',
                  )!;
              final description = (data['description'] as String?)?.trim() ?? '';
              final mediaFuture = _ensureMediaFuture(timelineDocRef);

              final bottomPadding =
                  (hideChrome ? 16.0 : kBottomNavigationBarHeight + 16.0) +
                      MediaQuery.of(context).padding.bottom;

              return SingleChildScrollView(
                padding: EdgeInsets.only(bottom: bottomPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ContainerHeader(
                      showImage: false,
                      titleHeader: 'Name',
                      title: issueName,
                      descriptionHeader: 'Description',
                      description: description.isEmpty
                          ? 'No description provided.'
                          : description,
                    ),
                    FutureBuilder<List<FileCarouselItem>>(
                      future: mediaFuture,
                      builder: (context, mediaSnap) {
                        if (mediaSnap.connectionState ==
                            ConnectionState.waiting) {
                          return const Padding(
                            padding: EdgeInsets.only(top: 16),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }
                        final items =
                            mediaSnap.data ?? const <FileCarouselItem>[];
                        if (items.isEmpty) {
                          return const SizedBox.shrink();
                        }
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SizedBox(height: 16),
                            ContainerActionWidget(
                              title: 'Attachments',
                              actionText: '',
                              content: FileCarouselViewer(
                                mediaItems: items,
                                showMediaTypeIcon: true,
                                usePageView: true,
                                mediaBottomSpacing: 0,
                                // Document tap not supported (admin lacks
                                // http+path packages for tmp download).
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    _buildResponseSection(context, data),
                  ],
                ),
              );
            },
          ),
        ),
      ),
      bottomNavigationBar: hideChrome
          ? null
          : Consumer(
              builder: (context, ref, _) {
                final controller = ref.read(aiCanvasControllerProvider);
                final menuSections = const MenuDrawerSections();
                return buildBottomBar(
                  onAiPressed: controller.toggle,
                  menuSections: menuSections,
                );
              },
            ),
    );
  }
}

class _OrderedMediaItem {
  const _OrderedMediaItem({
    required this.order,
    required this.item,
  });

  final int order;
  final FileCarouselItem item;
}
