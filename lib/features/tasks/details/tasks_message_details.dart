import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/details_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/home_navbar_adapter.dart';
import 'package:kleenops_admin/services/ai/ai_context_service.dart';
import 'package:kleenops_admin/widgets/ai/ai_screen_context.dart';
import 'package:shared_widgets/containers/container_action.dart';
import 'package:shared_widgets/containers/container_header.dart';
import 'package:shared_widgets/containers/canvas_top_bookend.dart';
import 'package:shared_widgets/containers/standard_canvas.dart';
import 'package:shared_widgets/drawers/menu_drawer.dart';
import 'package:kleenops_admin/theme/palette.dart';
import 'package:kleenops_admin/common/utils/snackbar_service.dart';

class TasksMessageDetails extends StatefulWidget {
  const TasksMessageDetails({
    super.key,
    required this.docRef,
    required this.memberRef,
  });

  final DocumentReference<Map<String, dynamic>> docRef;
  final DocumentReference<Map<String, dynamic>> memberRef;

  @override
  State<TasksMessageDetails> createState() => _TasksMessageDetailsState();
}

class _TasksMessageDetailsState extends State<TasksMessageDetails> {
  bool _processingAck = false;

  late final Future<DocumentSnapshot<Map<String, dynamic>>> _docFuture =
      widget.docRef.get();
  Future<_MessageMedia>? _mediaFuture;
  String? _mediaFutureKey;

  Future<_MessageMedia> _ensureMediaFuture() {
    final key = widget.docRef.path;
    if (_mediaFutureKey == key && _mediaFuture != null) return _mediaFuture!;
    _mediaFutureKey = key;
    _mediaFuture = _loadMedia(widget.docRef);
    return _mediaFuture!;
  }

  Future<_MessageMedia> _loadMedia(
    DocumentReference<Map<String, dynamic>> timelineRef,
  ) async {
    try {
      // Admin uses TOP-LEVEL `file` collection.
      final snap = await FirebaseFirestore.instance
          .collection('file')
          .where('timelineId', isEqualTo: timelineRef)
          .get();
      if (snap.docs.isEmpty) {
        return const _MessageMedia();
      }

      String imageUrl = '';
      String videoUrl = '';
      final ordered = snap.docs
          .map((doc) => doc.data())
          .toList(growable: false)
        ..sort((a, b) => _entryOrder(a).compareTo(_entryOrder(b)));

      for (final entry in ordered) {
        final type = (entry['fileType'] ?? entry['mediaType'] ?? '')
            .toString()
            .toLowerCase();
        final url = _stringFromData(entry, const [
          'downloadUrl',
          'url',
          'fileUrl',
          'imageUrl',
          'videoUrl',
        ]);
        if (url == null || url.isEmpty) continue;
        if (imageUrl.isEmpty && type.contains('image')) {
          imageUrl = url;
          continue;
        }
        if (videoUrl.isEmpty && type.contains('video')) {
          videoUrl = url;
        }
      }

      return _MessageMedia(imageUrl: imageUrl, videoUrl: videoUrl);
    } catch (_) {
      return const _MessageMedia();
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

  Future<void> _acknowledgeMessage() async {
    if (_processingAck) return;
    setState(() => _processingAck = true);

    try {
      await widget.docRef.update({
        'acknowledgedMemberIds': FieldValue.arrayUnion([widget.memberRef]),
        'acknowledgedAt.${widget.memberRef.id}': FieldValue.serverTimestamp(),
        'opened': true,
      });

      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _processingAck = false);
      SnackbarService.instance.showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 5),
          content: Text('Failed to acknowledge message: $e'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const bool hideChrome = false;
    final baseAiContext = AiContextPresets.detailScreen(
      key: 'tasksMessageDetails',
      sectionKey: 'tasks',
      entityId: widget.docRef.id,
      label: widget.docRef.id,
      entityPath: widget.docRef.path,
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
            title: 'Message Board',
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
                  child: Text('Error loading message: ${snapshot.error}'),
                );
              }

              if (!snapshot.hasData || !(snapshot.data?.exists ?? false)) {
                return const Center(child: Text('Message not found.'));
              }

              final data = snapshot.data!.data() ?? <String, dynamic>{};

              String? stringField(dynamic value) {
                if (value is String) {
                  final trimmed = value.trim();
                  if (trimmed.isNotEmpty) return trimmed;
                }
                return null;
              }

              final title = stringField(data['title']) ??
                  stringField(data['name']) ??
                  'Message';
              final description = stringField(data['message']) ??
                  stringField(data['body']) ??
                  stringField(data['description']) ??
                  '';
              final mediaFuture = _ensureMediaFuture();

              final ackPaths = <String>{};
              final rawAck = data['acknowledgedMemberIds'];
              if (rawAck is Iterable) {
                for (final item in rawAck) {
                  if (item is DocumentReference) {
                    ackPaths.add(item.path);
                  } else if (item is String) {
                    ackPaths.add(item);
                  }
                }
              }
              final alreadyAcknowledged =
                  ackPaths.contains(widget.memberRef.path);

              // Degraded: admin has no ImagePanel/VideoPanel widgets — fall
              // back to plain links.
              Widget buildMediaSection(_MessageMedia media) {
                final imageUrl = media.imageUrl.trim();
                final videoUrl = media.videoUrl.trim();
                final mediaSections = <Widget>[];
                void addMediaSection(String label, Widget child) {
                  mediaSections.add(
                    Row(
                      children: [
                        Text(
                          label,
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(fontSize: 16),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.info,
                          size: 16,
                          color: AppPaletteScope.of(context).primary2,
                        ),
                      ],
                    ),
                  );
                  mediaSections.add(const SizedBox(height: 4));
                  mediaSections.add(child);
                  mediaSections.add(const SizedBox(height: 16));
                }

                if (imageUrl.isNotEmpty) {
                  addMediaSection(
                    'Image',
                    Image.network(imageUrl, fit: BoxFit.contain),
                  );
                }
                if (videoUrl.isNotEmpty) {
                  addMediaSection(
                    'Video',
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: SelectableText(videoUrl),
                    ),
                  );
                }

                if (mediaSections.isNotEmpty) {
                  mediaSections.removeLast();
                }

                if (mediaSections.isEmpty) return const SizedBox.shrink();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: mediaSections,
                );
              }

              const bottomPadding = 16.0;

              return SingleChildScrollView(
                padding: EdgeInsets.only(bottom: bottomPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ContainerHeader(
                      showImage: false,
                      titleHeader: 'Name',
                      title: title,
                      descriptionHeader: 'Description',
                      description: description.isEmpty
                          ? 'No description provided.'
                          : description,
                    ),
                    FutureBuilder<_MessageMedia>(
                      future: mediaFuture,
                      builder: (context, mediaSnap) {
                        final media = mediaSnap.data ?? const _MessageMedia();
                        final content = buildMediaSection(media);
                        if (content is SizedBox) {
                          return const SizedBox.shrink();
                        }
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SizedBox(height: 16),
                            ContainerActionWidget(
                              title: null,
                              actionText: '',
                              content: content,
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: ElevatedButton(
                        onPressed: alreadyAcknowledged || _processingAck
                            ? null
                            : _acknowledgeMessage,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppPaletteScope.of(context).primary2,
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(52),
                          textStyle: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        child: _processingAck
                            ? const SizedBox(
                                height: 24,
                                width: 24,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Text(alreadyAcknowledged
                                ? 'Acknowledged'
                                : 'Acknowledge'),
                      ),
                    ),
                    const SizedBox(height: 32),
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

class _MessageMedia {
  const _MessageMedia({
    this.imageUrl = '',
    this.videoUrl = '',
  });

  final String imageUrl;
  final String videoUrl;
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

int _entryOrder(Map<String, dynamic> data) {
  final raw = data['order'];
  if (raw is int) return raw;
  if (raw is num) return raw.toInt();
  return 0;
}
