import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/details_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/home_navbar_adapter.dart';
import 'package:kleenops_admin/services/ai/ai_context_service.dart';
import 'package:kleenops_admin/widgets/ai/ai_screen_context.dart';
import 'package:path/path.dart' as p;
import 'package:shared_widgets/containers/container_action.dart';
import 'package:shared_widgets/containers/container_header.dart';
import 'package:shared_widgets/containers/canvas_top_bookend.dart';
import 'package:shared_widgets/containers/standard_canvas.dart';
import 'package:shared_widgets/labels/header_info_icon_value.dart';
import 'package:shared_widgets/viewers/file_carousel_viewer.dart';

class QualityInspectionDetailsScreen extends StatefulWidget {
  final DocumentReference<Map<String, dynamic>> docRef;

  const QualityInspectionDetailsScreen({
    super.key,
    required this.docRef,
  });

  @override
  State<QualityInspectionDetailsScreen> createState() =>
      _QualityInspectionDetailsScreenState();
}

class _QualityInspectionDetailsScreenState
    extends State<QualityInspectionDetailsScreen> {
  Stream<DocumentSnapshot<Map<String, dynamic>>>? _inspectionStream;

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
    final ext = p.extension(path).toLowerCase();
    if (ext.isEmpty) return '';
    return ext.startsWith('.') ? ext.substring(1) : ext;
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
    final base = p.basename(path);
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

  Future<List<FileCarouselItem>> _loadMediaItems() async {
    try {
      final companyRef = widget.docRef.parent.parent;
      if (companyRef == null) return const <FileCarouselItem>[];
      final snap = await companyRef
          .collection('file')
          .where('qualityId', isEqualTo: widget.docRef)
          .get();
      final items = _fileDocsToItems(snap.docs);
      if (items.isNotEmpty) return items;
    } catch (_) {}
    return const <FileCarouselItem>[];
  }

  Future<_InspectionDetails> _loadDetails(Map<String, dynamic> data) async {
    final companyRef = widget.docRef.parent.parent;
    String contributors = '';
    String taskName = '';
    String processName = '';
    String objectName = '';

    // Get contributors - quality reports store memberId (subject) and createdBy (creator)
    final names = <String>[];

    // Get the subject member name (memberId)
    final memberRef = data['memberId'] as DocumentReference<Map<String, dynamic>>?;
    if (memberRef != null) {
      try {
        final snap = await memberRef.get();
        final memberData = snap.data();
        final name = memberData?['name'] ??
            memberData?['displayName'] ??
            '${memberData?['firstName'] ?? ''} ${memberData?['lastName'] ?? ''}'.trim();
        if (name is String && name.trim().isNotEmpty) {
          names.add(name.trim());
        }
      } catch (_) {}
    }

    // Get the creator name (createdBy/createdByMemberId) if different from subject
    final createdByRef = (data['createdBy'] ?? data['createdByMemberId'])
        as DocumentReference<Map<String, dynamic>>?;
    if (createdByRef != null && createdByRef.id != memberRef?.id) {
      try {
        final snap = await createdByRef.get();
        final memberData = snap.data();
        final name = memberData?['name'] ??
            memberData?['displayName'] ??
            '${memberData?['firstName'] ?? ''} ${memberData?['lastName'] ?? ''}'.trim();
        if (name is String && name.trim().isNotEmpty) {
          names.add(name.trim());
        }
      } catch (_) {}
    }

    contributors = names.join(', ');

    // Fallback to contributor fields if still empty
    if (contributors.isEmpty) {
      final contributorsList = data['contributors'];
      if (contributorsList is Map<String, dynamic> && contributorsList.isNotEmpty) {
        // Contributors stored as a map with member IDs as keys
        for (final entry in contributorsList.entries) {
          if (entry.value is Map<String, dynamic>) {
            final name = entry.value['name'] ?? entry.value['displayName'] ?? '';
            if (name is String && name.trim().isNotEmpty) {
              names.add(name.trim());
            }
          }
        }
        contributors = names.join(', ');
      } else if (contributorsList is List && contributorsList.isNotEmpty) {
        for (final contributor in contributorsList) {
          if (contributor is Map<String, dynamic>) {
            final name = contributor['name'] ?? contributor['displayName'] ?? '';
            if (name is String && name.trim().isNotEmpty) {
              names.add(name.trim());
            }
          } else if (contributor is String && contributor.trim().isNotEmpty) {
            names.add(contributor.trim());
          }
        }
        contributors = names.join(', ');
      }
    }

    // Get task name - try taskId first, then extract from timelineId
    var taskRef = data['taskId'] as DocumentReference<Map<String, dynamic>>?;
    if (taskRef != null) {
      try {
        final snap = await taskRef.get();
        taskName = snap.data()?['name'] ?? '';
      } catch (_) {}
    }

    // If no taskId or couldn't get name, try to get it from timelineId
    if (taskName.isEmpty) {
      final timelineRef =
          data['timelineId'] as DocumentReference<Map<String, dynamic>>?;
      if (timelineRef != null) {
        try {
          final timelineSnap = await timelineRef.get();
          final timelineData = timelineSnap.data();
          if (timelineData != null) {
            // Get taskId from the timeline document
            taskRef =
                timelineData['taskId'] as DocumentReference<Map<String, dynamic>>?;
            if (taskRef != null) {
              final taskSnap = await taskRef.get();
              taskName = taskSnap.data()?['name'] ?? '';
            }
            // Also try to get task name directly from timeline if stored
            if (taskName.isEmpty) {
              taskName = _stringFromData(timelineData, const [
                    'taskName',
                    'taskTitle',
                    'taskDisplayName',
                  ]) ??
                  '';
            }
          }
        } catch (_) {}
      }
    }

    // Fallback to denormalized task name fields
    if (taskName.isEmpty) {
      taskName = _stringFromData(data, const [
            'taskName',
            'taskTitle',
            'taskDisplayName',
          ]) ??
          '';
    }

    // Get process name from data first, then from reference
    processName = _stringFromData(data, const [
          'processConcatenatedName',
          'processName',
          'objectProcessName',
          'processTitle',
          'processDisplayName',
          'processLabel',
        ]) ??
        '';
    if (processName.isEmpty && companyRef != null) {
      final processRef = (data['processId'] ??
              data['objectProcessId'] ??
              data['objectProcessTaskId'])
          as DocumentReference<Map<String, dynamic>>?;
      if (processRef != null) {
        try {
          final snap = await processRef.get();
          processName =
              snap.data()?['name'] ?? snap.data()?['processName'] ?? '';
        } catch (_) {}
      }
    }

    // Get object name from data first, then from reference
    // Check for objectIds (list) first, then single object references
    objectName = _stringFromData(data, const [
          'companyObjectName',
          'objectName',
          'objectLocalName',
          'objectDisplayName',
        ]) ??
        '';
    if (objectName.isEmpty && companyRef != null) {
      // Try objectIds list first (used by quality form)
      final objectIds = data['objectIds'];
      if (objectIds is List && objectIds.isNotEmpty) {
        final objectNames = <String>[];
        for (final objRef in objectIds) {
          if (objRef is DocumentReference<Map<String, dynamic>>) {
            try {
              final snap = await objRef.get();
              final name = snap.data()?['name'] ?? snap.data()?['objectName'] ?? '';
              if (name is String && name.trim().isNotEmpty) {
                objectNames.add(name.trim());
              }
            } catch (_) {}
          }
        }
        objectName = objectNames.join(', ');
      }

      // Fallback to single object reference
      if (objectName.isEmpty) {
        final objectRef = (data['companyObjectId'] ?? data['objectId'])
            as DocumentReference<Map<String, dynamic>>?;
        if (objectRef != null) {
          try {
            final snap = await objectRef.get();
            objectName =
                snap.data()?['name'] ?? snap.data()?['objectName'] ?? '';
          } catch (_) {}
        }
      }
    }

    return _InspectionDetails(
      contributors: contributors,
      taskName: taskName,
      processName: processName,
      objectName: objectName,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool hideChrome = false;
    final baseAiContext = AiContextPresets.qualityInspectionDetails(
      inspectionId: widget.docRef.id,
      label: widget.docRef.id,
      entityPath: widget.docRef.path,
    );

    Widget buildBottomBar({VoidCallback? onAiPressed}) {
      if (hideChrome) return const SizedBox.shrink();
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DetailsAppBar(
            title: 'Inspection Details',
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
      body: AiScreenContext(
        context: baseAiContext,
        child: _wrapCanvas(
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: _inspectionStream ??= widget.docRef.snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }
              if (!snapshot.hasData || !snapshot.data!.exists) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                return const Center(child: Text('Document not found.'));
              }

              final data = snapshot.data!.data()!;
              final String title = data['name'] as String? ?? '';
              final String description = data['description'] as String? ?? '';

              const bottomPadding = 16.0;

              return SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: bottomPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    FutureBuilder<List<FileCarouselItem>>(
                      future: _loadMediaItems(),
                      builder: (context, mediaSnap) {
                        final items =
                            mediaSnap.data ?? const <FileCarouselItem>[];
                        final hasMedia = items.isNotEmpty;

                        return ContainerHeader(
                          showImage: hasMedia,
                          mediaItems: hasMedia ? items : null,
                          titleHeader: 'Name',
                          title: title,
                          descriptionHeader: 'Description',
                          description: description,
                        );
                      },
                    ),
                    FutureBuilder<_InspectionDetails>(
                      future: _loadDetails(data),
                      builder: (context, detailsSnap) {
                        if (detailsSnap.connectionState ==
                            ConnectionState.waiting) {
                          return const Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }

                        final details = detailsSnap.data;
                        if (details == null) {
                          return const SizedBox.shrink();
                        }

                        final hasAnyDetail = details.contributors.isNotEmpty ||
                            details.taskName.isNotEmpty ||
                            details.processName.isNotEmpty ||
                            details.objectName.isNotEmpty;

                        if (!hasAnyDetail) {
                          return const SizedBox.shrink();
                        }

                        return ContainerActionWidget(
                          title: 'Details',
                          actionText: '',
                          content: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (details.contributors.isNotEmpty) ...[
                                HeaderInfoIconValue(
                                  header: 'Contributors',
                                  value: details.contributors,
                                  icon: Icons.people_outlined,
                                ),
                                const SizedBox(height: 12),
                              ],
                              if (details.taskName.isNotEmpty) ...[
                                HeaderInfoIconValue(
                                  header: 'Task',
                                  value: details.taskName,
                                  icon: Icons.task_outlined,
                                ),
                                const SizedBox(height: 12),
                              ],
                              if (details.processName.isNotEmpty) ...[
                                HeaderInfoIconValue(
                                  header: 'Process',
                                  value: details.processName,
                                  icon: Icons.account_tree_outlined,
                                ),
                                const SizedBox(height: 12),
                              ],
                              if (details.objectName.isNotEmpty)
                                HeaderInfoIconValue(
                                  header: 'Object',
                                  value: details.objectName,
                                  icon: Icons.location_on_outlined,
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                    if (data['employeeAgrees'] != null) ...[
                      const SizedBox(height: 16),
                      ContainerActionWidget(
                        title: 'Employee Response',
                        actionText: '',
                        content: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              data['employeeAgrees'] == true
                                  ? 'Employee agreed with this report.'
                                  : 'Employee disagreed with this report.',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600),
                            ),
                            if (((data['employeeResponse'] as String?)
                                        ?.trim() ??
                                    '')
                                .isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text((data['employeeResponse'] as String)
                                  .trim()),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        ),
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

class _InspectionDetails {
  const _InspectionDetails({
    required this.contributors,
    required this.taskName,
    required this.processName,
    required this.objectName,
  });

  final String contributors;
  final String taskName;
  final String processName;
  final String objectName;
}
