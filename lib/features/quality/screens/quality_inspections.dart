import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:kleenops_admin/app/routes.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/details_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/home_navbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/drawers/appbar_logout_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/search/search_control_strip_adapter.dart';
import 'package:shared_widgets/lists/standardViewGroup.dart';
import 'package:shared_widgets/tiles/standard_tile_large.dart';
import 'package:kleenops_admin/features/auth/providers/auth_provider.dart';
import '../details/quality_inspection_details.dart';
import 'package:kleenops_admin/services/ai/ai_context_service.dart';
import 'package:kleenops_admin/widgets/ai/ai_screen_context.dart';
import 'package:shared_widgets/containers/canvas_top_bookend.dart';
import 'package:shared_widgets/containers/standard_canvas.dart';
import 'package:shared_widgets/drawers/menu_drawer.dart';

enum QualityInspectionGroupBy {
  date,
  process,
  object,
}

/// Top-level screen with its own Scaffold (app bar + content + bottom nav)
class QualityInspectionsScreen extends StatefulWidget {
  const QualityInspectionsScreen({super.key});

  @override
  State<QualityInspectionsScreen> createState() =>
      _QualityInspectionsScreenState();
}

class _QualityInspectionsScreenState extends State<QualityInspectionsScreen> {
  bool _searchVisible = false;

  void _toggleSearch() => setState(() => _searchVisible = !_searchVisible);

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
            title: 'Quality Inspections',
            onAiPressed: onAiPressed,
            menuSections: menuSections,
            showSearchToggle: true,
            searchActive: _searchVisible,
            onSearchToggle: _toggleSearch,
          ),
          const HomeNavBarAdapter(),
        ],
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: null,
      drawer: const UserDrawer(),
      body: AiScreenContext(
        context: AiContextPresets.qualityInspections(),
        child: _wrapCanvas(
          QualityInspectionsContent(searchVisible: _searchVisible),
        ),
      ),
      bottomNavigationBar: Consumer(
        builder: (context, ref, _) {
          final controller = ref.read(aiCanvasControllerProvider);
          final menuSections = MenuDrawerSections(
            actions: [
              ContentMenuItem(
                icon: Icons.bar_chart_outlined,
                label: 'Stats',
                onTap: () => context.push(AppRoutePaths.qualityStats),
              ),
              ContentMenuItem(
                icon: Icons.home_outlined,
                label: 'Quality Home',
                onTap: () => context.push(AppRoutePaths.qualityHome),
              ),
            ],
          );
          return buildBottomBar(
            onAiPressed: controller.toggle,
            menuSections: menuSections,
          );
        },
      ),
    );
  }
}

class QualityInspectionsContent extends ConsumerStatefulWidget {
  const QualityInspectionsContent({
    super.key,
    this.groupBy = QualityInspectionGroupBy.date,
    this.teamId,
    this.searchVisible = false,
  });

  final QualityInspectionGroupBy groupBy;
  final String? teamId;
  final bool searchVisible;

  @override
  ConsumerState<QualityInspectionsContent> createState() =>
      _QualityInspectionsContentState();
}

class _QualityInspectionsContentState
    extends ConsumerState<QualityInspectionsContent> {
  static const String _qualityTimelineCategoryId = 'VdjzT5izZVSWmrhfRRq0';
  final TextEditingController _searchCtl = TextEditingController();
  String _search = '';

  DateTime? _resolveInspectionDate(Map<String, dynamic> data) {
    const keys = ['createdAt', 'startTime', 'endTime', 'updatedAt'];
    for (final key in keys) {
      final raw = data[key];
      if (raw is Timestamp) return raw.toDate();
      if (raw is DateTime) return raw;
      if (raw is int) {
        return DateTime.fromMillisecondsSinceEpoch(raw);
      }
    }
    return null;
  }

  String _sortableLabel(String label) {
    final trimmed = label.trim();
    if (trimmed.isEmpty) return 'zzzz#Unknown';
    return '${trimmed.toLowerCase()}#$trimmed';
  }

  Future<_InspectionSummary> _loadSummary({
    required DocumentReference<Map<String, dynamic>> companyRef,
    required DocumentReference<Map<String, dynamic>> qualityRef,
    required Map<String, dynamic> qualityData,
    DocumentReference<Map<String, dynamic>>? taskRef,
    DocumentReference<Map<String, dynamic>>? processRef,
    DocumentReference<Map<String, dynamic>>? objectRef,
  }) async {
    String taskName = '';
    String processName = '';
    String objectName = '';

    // Prefer denormalized task name on the quality doc itself
    taskName = _stringField(qualityData, const [
          'taskName',
          'taskTitle',
          'taskDisplayName',
        ]) ??
        '';

    // Fallback: read from the task reference
    if (taskName.isEmpty && taskRef != null) {
      try {
        final snap = await taskRef.get();
        taskName = snap.data()?['name'] ?? '';
      } catch (_) {}
    }

    // Last resort: walk back through the source timeline doc
    if (taskName.isEmpty) {
      final timelineRef =
          qualityData['timelineId'] as DocumentReference<Map<String, dynamic>>?;
      if (timelineRef != null) {
        try {
          final timelineSnap = await timelineRef.get();
          final timelineData = timelineSnap.data();
          if (timelineData != null) {
            final timelineTaskRef =
                timelineData['taskId'] as DocumentReference<Map<String, dynamic>>?;
            if (timelineTaskRef != null) {
              final taskSnap = await timelineTaskRef.get();
              taskName = taskSnap.data()?['name'] ?? '';
            }
            if (taskName.isEmpty) {
              taskName = _stringField(timelineData, const [
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

    // Try to get process name from data first, then from reference
    processName = _stringField(qualityData, const [
          'processConcatenatedName',
          'processName',
          'objectProcessName',
          'processTitle',
          'processDisplayName',
          'processLabel',
        ]) ??
        '';
    if (processName.isEmpty && processRef != null) {
      try {
        final snap = await processRef.get();
        processName = snap.data()?['name'] ?? snap.data()?['processName'] ?? '';
      } catch (_) {}
    }

    // Try to get object name from data first, then from reference
    objectName = _stringField(qualityData, const [
          'companyObjectName',
          'objectName',
          'objectLocalName',
          'objectDisplayName',
        ]) ??
        '';
    if (objectName.isEmpty && objectRef != null) {
      try {
        final snap = await objectRef.get();
        objectName = snap.data()?['name'] ?? snap.data()?['objectName'] ?? '';
      } catch (_) {}
    }

    String imageUrl = '';
    try {
      final snap = await companyRef
          .collection('file')
          .where('qualityId', isEqualTo: qualityRef)
          .get();
      if (snap.docs.isNotEmpty) {
        final candidates = <_FileCandidate>[];
        var fallbackOrder = 0;
        for (final doc in snap.docs) {
          final data = doc.data();
          final url = _stringField(
            data,
            const ['downloadUrl', 'url', 'fileUrl', 'imageUrl'],
          );
          if (url == null || url.isEmpty) continue;
          final type = (data['fileType'] ?? data['mediaType'] ?? '')
              .toString()
              .toLowerCase();
          final isImage = type.contains('image');
          if (!isImage) continue;
          final order = data['order'] is num
              ? (data['order'] as num).toInt()
              : fallbackOrder;
          final isMaster = data['isMaster'] == true;
          candidates.add(
            _FileCandidate(
              url: url,
              order: order,
              isMaster: isMaster,
            ),
          );
          fallbackOrder += 1;
        }
        if (candidates.isNotEmpty) {
          candidates.sort((a, b) {
            if (a.isMaster != b.isMaster) {
              return a.isMaster ? -1 : 1;
            }
            return a.order.compareTo(b.order);
          });
          imageUrl = candidates.first.url;
        }
      }
    } catch (_) {}

    final summary = _InspectionSummary(
      taskName: taskName,
      processName: processName,
      objectName: objectName,
      imageUrl: imageUrl,
    );
    debugPrint(
      '[QualityInspections][summary] qualityId=${qualityRef.id} '
      'task="$taskName" process="$processName" object="$objectName" '
      'imageUrl=${imageUrl.isEmpty ? "<empty>" : imageUrl}',
    );
    return summary;
  }

  String _dateGroupKey(Map<String, dynamic> data) {
    final date = _resolveInspectionDate(data);
    if (date == null) return '00000000#Unknown';
    final sortKey = DateFormat('yyyyMMdd').format(date);
    final label = DateFormat('yMMMd').format(date);
    return '$sortKey#$label';
  }

  String? _stringField(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return null;
  }

  dynamic _firstFromList(dynamic raw) {
    if (raw is Iterable && raw.isNotEmpty) {
      return raw.first;
    }
    return null;
  }

  String? _refId(dynamic raw) {
    if (raw is DocumentReference) return raw.id;
    if (raw is String && raw.trim().isNotEmpty) return raw.trim();
    return null;
  }

  String _processGroupKey(Map<String, dynamic> data) {
    final label = _stringField(
      data,
      const [
        'processConcatenatedName',
        'processName',
        'objectProcessName',
        'processTitle',
        'processDisplayName',
        'processLabel',
      ],
    );
    if (label != null) return _sortableLabel(label);

    final refId = _refId(
      data['processId'] ??
          data['objectProcessId'] ??
          data['objectProcessTaskId'],
    );
    if (refId != null) return _sortableLabel(refId);

    final fallback = _stringField(
      data,
      const ['taskName', 'taskTitle', 'taskDisplayName'],
    );
    if (fallback != null) return _sortableLabel(fallback);

    return _sortableLabel('Unknown Process');
  }

  String _objectGroupKey(Map<String, dynamic> data) {
    final label = _stringField(
      data,
      const [
        'companyObjectName',
        'objectName',
        'objectLocalName',
        'objectDisplayName',
      ],
    );
    if (label != null) return _sortableLabel(label);

    final refId = _refId(
      data['companyObjectId'] ??
          data['objectId'] ??
          _firstFromList(data['objectIds']),
    );
    if (refId != null) return _sortableLabel(refId);

    return _sortableLabel('Unknown Object');
  }

  dynamic _groupKey(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    switch (widget.groupBy) {
      case QualityInspectionGroupBy.date:
        return _dateGroupKey(data);
      case QualityInspectionGroupBy.process:
        return _processGroupKey(data);
      case QualityInspectionGroupBy.object:
        return _objectGroupKey(data);
    }
  }

  int _dateDescendingSort(
    QueryDocumentSnapshot<Map<String, dynamic>> a,
    QueryDocumentSnapshot<Map<String, dynamic>> b,
  ) {
    final aDate = _resolveInspectionDate(a.data());
    final bDate = _resolveInspectionDate(b.data());
    if (aDate == null && bDate == null) return 0;
    if (aDate == null) return 1;
    if (bDate == null) return -1;
    return bDate.compareTo(aDate);
  }

  @override
  void dispose() {
    _searchCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final companyAsync = ref.watch(companyIdProvider);
    const bottomInset = 16.0;

    return companyAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (companyRef) {
        if (companyRef == null) {
          return const Center(child: Text('No company found.'));
        }

        final teamId = widget.teamId?.trim();
        final teamRef = (teamId == null || teamId.isEmpty)
            ? null
            : FirebaseFirestore.instance.collection('team').doc(teamId);

        var query = companyRef
            .collection('timeline')
            .where('timelineCategory', isEqualTo: _qualityTimelineCategoryId);
        if (teamRef != null) {
          query = query.where('teamId', isEqualTo: teamRef);
        }
        query = query.orderBy('createdAt', descending: true);
        debugPrint(
          '[QualityInspections][query] '
          'company=${companyRef.path} '
          'teamFilter=${teamRef?.path ?? "<none>"} '
          'category=$_qualityTimelineCategoryId '
          'groupBy=${widget.groupBy}',
        );

        final int Function(String, String) groupSort =
            widget.groupBy == QualityInspectionGroupBy.date
                ? (a, b) => b.compareTo(a)
                : (a, b) => a.compareTo(b);

        final list = StandardViewGroup(
          queryStream: query.snapshots(),
          groupBy: _groupKey,
          groupSort: groupSort,
          itemSort: _dateDescendingSort,
          headerIcon: null,
          itemBuilder: (doc) {
            final data = doc.data();
            final name = data['name'] ?? '';
            final taskRef =
                data['taskId'] as DocumentReference<Map<String, dynamic>>?;
            final processRef = (data['processId'] ??
                    data['objectProcessId'] ??
                    data['objectProcessTaskId'])
                as DocumentReference<Map<String, dynamic>>?;
            final objectRef = (data['companyObjectId'] ??
                    data['objectId'] ??
                    _firstFromList(data['objectIds']))
                as DocumentReference<Map<String, dynamic>>?;
            debugPrint(
              '[QualityInspections][doc] id=${doc.id} '
              'name="$name" '
              'teamId=${data['teamId']} '
              'taskId=${data['taskId']} '
              'timelineCategory=${data['timelineCategory']} '
              'objectIds=${data['objectIds']} '
              'createdAt=${data['createdAt']} '
              'fields=${data.keys.toList()}',
            );

            return FutureBuilder<_InspectionSummary>(
              future: _loadSummary(
                companyRef: companyRef,
                qualityRef: doc.reference,
                qualityData: data,
                taskRef: taskRef,
                processRef: processRef,
                objectRef: objectRef,
              ),
              builder: (context, snap) {
                final summary = snap.data;
                final taskName = summary?.taskName ?? '';
                final processName = summary?.processName ?? '';
                final objectName = summary?.objectName ?? '';
                final imageUrl = summary?.imageUrl ?? '';

                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => QualityInspectionDetailsScreen(
                            docRef: doc.reference,
                          ),
                        ),
                      );
                    },
                    child: StandardTileLargeDart(
                      imageUrl: imageUrl,
                      firstLine: name,
                      firstLineIcon: Icons.assignment_outlined,
                      secondLine: taskName,
                      secondLineIcon: Icons.task_outlined,
                      thirdLine: processName,
                      thirdLineIcon: Icons.account_tree_outlined,
                      fourthLine: objectName,
                      fourthLineIcon: Icons.location_on_outlined,
                    ),
                  ),
                );
              },
            );
          },
        );

        return Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: Column(
            children: [
              if (widget.searchVisible)
                SearchControlStrip(
                  controller: _searchCtl,
                  hintText: 'SearchÆ’?Ä°',
                  onChanged: (t) => setState(() => _search = t.trim()),
                ),
              Expanded(child: list),
            ],
          ),
        );
      },
    );
  }
}

class _InspectionSummary {
  const _InspectionSummary({
    required this.taskName,
    required this.processName,
    required this.objectName,
    required this.imageUrl,
  });

  final String taskName;
  final String processName;
  final String objectName;
  final String imageUrl;
}

class _FileCandidate {
  const _FileCandidate({
    required this.url,
    required this.order,
    required this.isMaster,
  });

  final String url;
  final int order;
  final bool isMaster;
}

