// lib/features/tasks/screens/tasks_reports_unscheduled_task_form.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import 'package:kleenops_admin/app/shared_widgets/forms/form_ai_bottom_bar.dart';
import 'package:kleenops_admin/common/field_info/field_info_registry.dart';
import 'package:kleenops_admin/features/auth/providers/auth_provider.dart';
import 'package:kleenops_admin/repositories/task_repository.dart';
import 'package:kleenops_admin/repositories/user_repository.dart';
import 'package:kleenops_admin/services/ai/ai_context_service.dart';
import 'package:kleenops_admin/services/ai_text_adapter.dart';
import 'package:shared_widgets/services/firestore_service.dart';
import 'package:kleenops_admin/services/storage_service.dart';
import 'package:kleenops_admin/widgets/ai/ai_screen_context.dart';
import 'package:kleenops_admin/widgets/fields/multi_select/building_multi_select.dart';
import 'package:kleenops_admin/widgets/fields/multi_select/floor_multi_select.dart';
import 'package:kleenops_admin/widgets/fields/multi_select/location_multi_select.dart';
import 'package:kleenops_admin/widgets/fields/multi_select/object_multi_select.dart';
import 'package:kleenops_admin/widgets/fields/multi_select/property_multi_select.dart';
import 'package:shared_widgets/containers/container_action.dart';
import 'package:shared_widgets/containers/canvas_top_bookend.dart';
import 'package:shared_widgets/fields/file_uploader.dart';
import 'package:kleenops_admin/common/utils/snackbar_service.dart';

/// Screen-level wrapper: hosts its own Scaffold + Save-bar.
class TasksReportsUnscheduledTaskFormScreen extends StatelessWidget {
  TasksReportsUnscheduledTaskFormScreen({super.key});

  final _formKey = GlobalKey<_TasksReportsUnscheduledTaskFormState>();
  final String _aiContextKey = 'tasks_unscheduled_task_form:${UniqueKey()}';

  AiContextState _buildAiContext() {
    return AiContextState(
      key: _aiContextKey,
      sectionKey: 'tasks',
      screenType: 'tasks_unscheduled_task_form',
      label: 'Unscheduled Task',
      forms: AiContextPresets.tasksForms,
      actions: AiContextPresets.tasksActions,
      guidance: AiContextPresets.tasksGuidance,
      title: 'Tasks AI',
      subtitle: 'Ask about this unscheduled task.',
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: AiScreenContext(
          context: _buildAiContext(),
          child: SafeArea(
            top: true,
            bottom: false,
            child: TasksReportsUnscheduledTaskForm(key: _formKey),
          ),
        ),
        bottomNavigationBar: FormAiBottomBar(
          title: 'Unscheduled Task',
          onCancel: () => Navigator.pop(context),
          onSave: () async {
            await _formKey.currentState?.save();
          },
        ),
      );
}

/// Inner form widget (self-contained – no FormShell needed).
class TasksReportsUnscheduledTaskForm extends ConsumerStatefulWidget {
  const TasksReportsUnscheduledTaskForm({
    super.key,
    this.timelineRef,
    this.locationRefs,
  });

  final DocumentReference<Map<String, dynamic>>? timelineRef;
  final List<DocumentReference<Map<String, dynamic>>>? locationRefs;

  @override
  ConsumerState<TasksReportsUnscheduledTaskForm> createState() =>
      _TasksReportsUnscheduledTaskFormState();
}

class _TasksReportsUnscheduledTaskFormState
    extends ConsumerState<TasksReportsUnscheduledTaskForm> {
  final _nameCtl = TextEditingController();
  final _descCtl = TextEditingController();
  final _durationCtl = TextEditingController(text: '0');

  String? _imageUrl;
  String? _videoUrl;
  List<Map<String, dynamic>> _images = [];
  List<Map<String, dynamic>> _videos = [];
  List<Map<String, dynamic>> _documents = [];

  List<DocumentReference> _props = [];
  List<DocumentReference> _blds = [];
  List<DocumentReference> _flrs = [];
  List<DocumentReference> _locs = [];
  List<DocumentReference> _objs = [];

  DocumentReference<Map<String, dynamic>>? _primaryTeamRef;
  DocumentReference<Map<String, dynamic>>? _timelineTaskRef;
  DocumentReference<Map<String, dynamic>>? _memberRef;
  String? _memberName;

  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _locs = (widget.locationRefs ?? []).cast<DocumentReference>();
    await Future.wait([_loadPrimaryTeam(), _loadTimelineTask()]);
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadPrimaryTeam() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final indexSnap = await ref
        .read(userRepositoryProvider)
        .memberByUidGroup(uid)
        .where('active', isEqualTo: true)
        .limit(1)
        .get();
    if (indexSnap.docs.isEmpty) return;

    final indexDoc = indexSnap.docs.first;
    final memberId = indexDoc.data()['memberId'] as String?;
    if (memberId == null || memberId.trim().isEmpty) return;

    final companyRef = indexDoc.reference.parent.parent
        as DocumentReference<Map<String, dynamic>>;
    final memberRef = companyRef.collection('member').doc(memberId.trim());
    final memberSnap = await memberRef.get();
    final memberData = memberSnap.data() ?? <String, dynamic>{};

    _memberRef = memberRef;
    _memberName = memberData['name'] as String?;
    _primaryTeamRef =
        memberData['primaryTeamId'] as DocumentReference<Map<String, dynamic>>?;
  }

  Future<void> _loadTimelineTask() async {
    if (widget.timelineRef == null) return;
    final data = (await widget.timelineRef!.get()).data() ?? {};
    _timelineTaskRef = data['taskId'] as DocumentReference<Map<String, dynamic>>?;
  }

  /// Expose save to the parent save-bar.
  Future<void> save() => _save();

  List<Map<String, dynamic>> _cloneEntries(List<Map<String, dynamic>> entries) {
    return entries.map((entry) => Map<String, dynamic>.from(entry)).toList();
  }

  void _updateVideoDuration(int durationSeconds) {
    final selected = _videoUrl?.trim();
    if (selected == null || selected.isEmpty) return;

    final updated = _videos
        .map((video) {
          final url = _videoUrlFromEntry(video);
          if (url == selected) {
            return <String, dynamic>{
              ...video,
              'videoDuration': durationSeconds,
            };
          }
          return video;
        })
        .whereType<Map<String, dynamic>>()
        .toList();

    setState(() => _videos = updated);
  }

  String? _stringFromEntry(Map<String, dynamic> entry, List<String> keys) {
    for (final key in keys) {
      final value = entry[key];
      if (value is String) {
        final trimmed = value.trim();
        if (trimmed.isNotEmpty) return trimmed;
      }
    }
    return null;
  }

  int? _intFromEntry(Map<String, dynamic> entry, List<String> keys) {
    for (final key in keys) {
      final value = entry[key];
      if (value is int) return value;
      if (value is num) return value.toInt();
    }
    return null;
  }

  int? _entryOrder(Map<String, dynamic> entry) {
    return _intFromEntry(entry, const ['order']);
  }

  String? _imageUrlFromEntry(Map<String, dynamic> entry) {
    return _stringFromEntry(entry, const [
      'url',
      'downloadUrl',
      'downloadURL',
      'imageUrl',
      'thumbnailUrl',
    ]);
  }

  String? _videoUrlFromEntry(Map<String, dynamic> entry) {
    return _stringFromEntry(entry, const [
      'videoUrl',
      'url',
      'video',
    ]);
  }

  String? _documentUrlFromEntry(Map<String, dynamic> entry) {
    return _stringFromEntry(entry, const [
      'url',
      'downloadUrl',
      'downloadURL',
      'fileUrl',
      'documentUrl',
    ]);
  }

  String? _thumbnailFromEntry(Map<String, dynamic> entry) {
    return _stringFromEntry(entry, const [
      'videoThumbnail',
      'thumbnailUrl',
      'thumbnail',
      'thumbUrl',
    ]);
  }

  int? _durationFromEntry(Map<String, dynamic> entry) {
    return _intFromEntry(entry, const ['videoDuration', 'duration']);
  }

  int? _sizeFromEntry(Map<String, dynamic> entry) {
    return _intFromEntry(entry, const ['sizeBytes', 'fileSize', 'size']);
  }

  String _extensionFromUrl(String url) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return '';

    final storagePath = _storagePathFromUrl(trimmed);
    final path = storagePath ?? (Uri.tryParse(trimmed)?.path ?? trimmed);
    final ext = p.extension(path).toLowerCase();
    if (ext.isEmpty) return '';
    return ext.startsWith('.') ? ext.substring(1) : ext;
  }

  String? _storagePathFromUrl(String url) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return null;

    if (trimmed.startsWith('gs://')) {
      final withoutScheme = trimmed.substring(5);
      final parts = withoutScheme.split('/');
      if (parts.length >= 2) {
        return parts.sublist(1).join('/');
      }
      return null;
    }

    if (trimmed.startsWith('http')) {
      final path = StorageService().extractPathFromUrl(trimmed).trim();
      return path.isNotEmpty ? path : null;
    }

    return trimmed.contains('/') ? trimmed : null;
  }

  String? _fileNameFromUrl(String url) {
    final storagePath = _storagePathFromUrl(url);
    final path = storagePath ?? (Uri.tryParse(url)?.path ?? url);
    final name = p.basename(path);
    return name.isNotEmpty ? name : null;
  }

  String _attachmentName(String taskName, int index, String mediaType) {
    final trimmed = taskName.trim();
    final label = trimmed.isNotEmpty ? trimmed : 'Unscheduled Task';
    return '$label $mediaType ${index + 1}';
  }

  List<_UnscheduledAttachment> _buildAttachments() {
    final attachments = <_UnscheduledAttachment>[];

    for (final image in _images) {
      final url = _imageUrlFromEntry(image);
      if (url == null || url.isEmpty) continue;
      attachments.add(
        _UnscheduledAttachment(
          url: url,
          mediaType: 'Image',
          fileType: 'image',
          sizeBytes: _sizeFromEntry(image),
          order: _entryOrder(image),
          fileExtension: _extensionFromUrl(url),
        ),
      );
    }

    for (final video in _videos) {
      final url = _videoUrlFromEntry(video);
      if (url == null || url.isEmpty) continue;
      attachments.add(
        _UnscheduledAttachment(
          url: url,
          mediaType: 'Video',
          fileType: 'video',
          thumbnailUrl: _thumbnailFromEntry(video),
          durationSeconds: _durationFromEntry(video),
          sizeBytes: _sizeFromEntry(video),
          order: _entryOrder(video),
          fileExtension: _extensionFromUrl(url),
        ),
      );
    }

    for (final doc in _documents) {
      final url = _documentUrlFromEntry(doc);
      if (url == null || url.isEmpty) continue;
      final ext = _extensionFromUrl(url);
      attachments.add(
        _UnscheduledAttachment(
          url: url,
          mediaType: 'Document',
          fileType: ext == 'pdf' ? 'pdf' : 'document',
          sizeBytes: _sizeFromEntry(doc),
          order: _entryOrder(doc),
          fileExtension: ext,
          fileName: _stringFromEntry(
            doc,
            const ['fileName', 'name', 'sourceFileName'],
          ),
        ),
      );
    }

    return attachments;
  }

  Future<void> _save() async {
    if (_saving) return;

    final name = _nameCtl.text.trim();
    final description = _descCtl.text.trim();
    final durationStr = _durationCtl.text.trim();
    final parsedDuration = int.tryParse(durationStr);

    final missing = <String>[
      if (name.isEmpty) 'name',
      if (description.isEmpty) 'description',
      if (parsedDuration == null || parsedDuration <= 0) 'duration',
    ];
    if (missing.isNotEmpty) {
      _snack('Please fill in ${missing.join(', ')}', isError: true);
      return;
    }

    final attachments = _buildAttachments();
    setState(() => _saving = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw 'Not logged in';

      final compRef = await ref.read(companyIdProvider.future);
      if (compRef == null) throw 'No company context';

      final memberRef = _memberRef;
      if (memberRef == null) throw 'Member profile not found';

      final duration = int.parse(durationStr);
      final now = DateTime.now();
      final startTs = Timestamp.fromDate(now.subtract(Duration(minutes: duration)));
      final endTs = Timestamp.fromDate(now);

      final data = <String, dynamic>{
        'name': name,
        'description': _descCtl.text.trim(),
        'duration': duration,
        'startTime': startTs,
        'endTime': endTs,
        'endTimeExtended': endTs,
        'propertyId': _props,
        'buildingId': _blds,
        'floorId': _flrs,
        'locationId': _locs,
        'objectIds': _objs,
        'taskId': _timelineTaskRef,
        // Stored as the member doc ID (string) — the timeline security
        // rule compares this against callerMemberId(), which is a string.
        // A DocumentReference here fails the create rule (permission-denied).
        'createdByMemberId': memberRef.id,
        // The ad-hoc timeline query in TaskRepository.watchTimeline filters
        // on `memberId` as a DocumentReference. Without this field the saved
        // task can never match the personal query and stays invisible on the
        // Tasks tab. (createdByMemberId is for the security rule; memberId is
        // for the query — both are required.)
        'memberId': memberRef,
        'teamId': _primaryTeamRef,
        'timelineId': widget.timelineRef,
        'timelineCategory': 'Rpl9Mn34gJBdZ007jXpo',
        'createdAt': FieldValue.serverTimestamp(),
        'completeTimestamp': FieldValue.serverTimestamp(),
      }..removeWhere((k, v) => v == null);

      final col = compRef.collection('timeline');
      final meta = await FirestoreService().buildCreateMeta(col);
      final docRef = await col.add({...data, ...meta});

      // Paired completed-work record. The ad-hoc task doc above surfaces on
      // the Tasks tab; this E2HM… record surfaces the same work in the
      // "My Tasks" tab and feeds the timecard / performance / supervision
      // screens — mirroring how completing a scheduled task spawns one.
      await _saveWorkRecord(
        companyRef: compRef,
        taskRef: docRef,
        memberRef: memberRef,
        name: name,
        startTs: startTs,
        endTs: endTs,
        duration: duration,
      );

      await _saveAttachmentDocs(
        companyRef: compRef,
        timelineRef: docRef,
        currentMemberRef: memberRef,
        taskRef: _timelineTaskRef,
        attachments: attachments,
      );

      if (mounted) {
        _snack('Unscheduled task saved');
        Navigator.pop(context);
      }
    } catch (e) {
      _snack('Error: $e', isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Writes the paired completed-work record (timelineCategory
  /// `E2HMUuMUUl4Alttuweba`) for an unscheduled task. This is the same record
  /// shape that completing a scheduled task produces, so the work shows up in
  /// the "My Tasks" tab and counts toward timecard / performance metrics.
  Future<void> _saveWorkRecord({
    required DocumentReference<Map<String, dynamic>> companyRef,
    required DocumentReference<Map<String, dynamic>> taskRef,
    required DocumentReference<Map<String, dynamic>> memberRef,
    required String name,
    required Timestamp startTs,
    required Timestamp endTs,
    required int duration,
  }) async {
    const workCategoryId = 'E2HMUuMUUl4Alttuweba';
    final col = companyRef.collection('timeline');
    final meta = await FirestoreService().buildCreateMeta(col);
    final memberName = _memberName?.trim();

    final workData = <String, dynamic>{
      'timelineCategory': workCategoryId,
      'timelineCategoryId': ref
          .read(taskRepositoryProvider)
          .timelineCategoryDoc(workCategoryId),
      'memberId': memberRef,
      if (memberName != null && memberName.isNotEmpty) 'memberName': memberName,
      'name': name,
      'title': name,
      'startTime': startTs,
      'endTime': endTs,
      'duration': duration,
      // Allotted time. For scheduled tasks this is filled by the
      // handleAllocateTaskDuration Cloud Function, which proportionally splits
      // the parent task's planned duration across each contributor's punch-out.
      // That function bails for unscheduled tasks because the ad-hoc task doc
      // carries no `contributors` map (totalLogged == 0). An unscheduled task
      // has exactly one member and the entered duration IS the allotted time,
      // so set it directly — otherwise the My Tasks tile renders "N/0 min".
      'taskDurationAllotment': duration,
      // taskId / timelineId point at the ad-hoc task doc so the My Tasks tile
      // can resolve a display name and tap through to the source task.
      'taskId': taskRef,
      'timelineId': taskRef,
    };

    await col.add({...workData, ...meta});
  }

  Future<void> _saveAttachmentDocs({
    required DocumentReference<Map<String, dynamic>> companyRef,
    required DocumentReference<Map<String, dynamic>> timelineRef,
    required DocumentReference<Map<String, dynamic>> currentMemberRef,
    DocumentReference<Map<String, dynamic>>? taskRef,
    required List<_UnscheduledAttachment> attachments,
  }) async {
    if (attachments.isEmpty) return;

    final batch = ref.read(taskRepositoryProvider).batch();
    final fileCollection = companyRef.collection('file');
    final taskName = _nameCtl.text.trim();

    for (var i = 0; i < attachments.length; i++) {
      final attachment = attachments[i];
      final fileRef = fileCollection.doc();
      final storagePath = _storagePathFromUrl(attachment.url);
      final fileName = attachment.fileName ?? _fileNameFromUrl(attachment.url);
      final extension = attachment.fileExtension ?? '';

      final data = <String, dynamic>{
        'firestorePath': fileRef.path,
        'downloadUrl': attachment.url,
        'fileUrl': attachment.url,
        'name': _attachmentName(taskName, i, attachment.mediaType),
        'mediaType': attachment.mediaType,
        'fileType': attachment.fileType,
        'createdAt': FieldValue.serverTimestamp(),
        if (storagePath != null && storagePath.isNotEmpty) 'storagePath': storagePath,
        if (fileName != null && fileName.trim().isNotEmpty)
          'sourceFileName': fileName.trim(),
        if (extension.isNotEmpty) 'fileExtension': extension,
        if (attachment.thumbnailUrl != null && attachment.thumbnailUrl!.trim().isNotEmpty)
          'thumbnailUrl': attachment.thumbnailUrl!.trim(),
        if (attachment.durationSeconds != null) 'duration': attachment.durationSeconds,
        if (attachment.durationSeconds != null) 'videoDuration': attachment.durationSeconds,
        if (attachment.sizeBytes != null) 'sizeBytes': attachment.sizeBytes,
        if (attachment.order != null) 'order': attachment.order,
        'timelineId': timelineRef,
        if (taskRef != null) 'taskId': taskRef,
        'memberRef': currentMemberRef,
        'createdBy': currentMemberRef,
        if (_primaryTeamRef != null) 'teamId': _primaryTeamRef,
      };

      batch.set(fileRef, data);
    }

    await batch.commit();
  }

  void _snack(String msg, {bool isError = false}) {
    SnackbarService.instance.showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 5),
        content: Text(msg),
        backgroundColor: isError ? Colors.red : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final compRef = ref.watch(companyIdProvider).maybeWhen(
          data: (c) => c,
          orElse: () => null,
        );

    if (compRef == null || _loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_saving) {
      return const Center(child: CircularProgressIndicator());
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => FocusScope.of(context).unfocus(),
      child: SingleChildScrollView(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const CanvasTopBookend(),
            ContainerActionWidget(
              title: 'Media',
              titleInfoKey: FieldInfoKeys.tasksRequestVisuals,
              actionText: '',
              content: FileUploaderField(
                allowImages: true,
                allowVideos: true,
                allowDocuments: true,
                enablePdfMarkup: false,
                imageUrl: _imageUrl,
                images: _images,
                onImagesChanged: (entries) {
                  setState(() => _images = _cloneEntries(entries));
                },
                onImageChanged: (u) {
                  setState(() => _imageUrl = u.trim().isEmpty ? null : u);
                },
                videoUrl: _videoUrl,
                videos: _videos,
                onVideosChanged: (entries) {
                  setState(() => _videos = _cloneEntries(entries));
                },
                onVideoChanged: (u) {
                  setState(() => _videoUrl = u.trim().isEmpty ? null : u);
                },
                onVideoDurationChanged: _updateVideoDuration,
                documents: _documents,
                onDocumentsChanged: (entries) {
                  setState(() => _documents = _cloneEntries(entries));
                },
                imageStorageFolder: 'company/${compRef.id}/timeline/images',
                videoStorageFolder: 'company/${compRef.id}/timeline/videos',
                documentStorageFolder: 'company/${compRef.id}/timeline/files',
              ),
            ),
            const SizedBox(height: 16),
            ContainerActionWidget(
              title: 'Details',
              titleInfoKey: FieldInfoKeys.tasksRequestDetails,
              actionText: '',
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AITextField(
                    labelText: 'Name *',
                    initialValue: _nameCtl.text,
                    minLines: 1,
                    maxLines: 1,
                    onChanged: (t) => _nameCtl.text = t,
                  ),
                  const SizedBox(height: 16),
                  AITextField(
                    labelText: 'Description *',
                    initialValue: _descCtl.text,
                    minLines: 3,
                    maxLines: 3,
                    onChanged: (t) => _descCtl.text = t,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ContainerActionWidget(
              title: 'Duration',
              titleInfoKey: FieldInfoKeys.tasksRequestDetails,
              actionText: '',
              content: TextFormField(
                controller: _durationCtl,
                decoration: const InputDecoration(labelText: 'Duration (minutes) *'),
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
              ),
            ),
            const SizedBox(height: 16),
            ContainerActionWidget(
              title: 'Location',
              titleInfoKey: FieldInfoKeys.tasksRequestLocation,
              actionText: '',
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  PropertyMultiSelectDropdown(
                    companyId: compRef,
                    selectedProperties: _props,
                    onChanged: (p) => setState(() {
                      _props = p;
                      _blds = [];
                      _flrs = [];
                      _locs = [];
                      _objs = [];
                    }),
                  ),
                  if (_props.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    BuildingMultiSelectDropdown(
                      selectedProperties: _props,
                      selectedBuildings: _blds,
                      onChanged: (b) => setState(() {
                        _blds = b;
                        _flrs = [];
                        _locs = [];
                        _objs = [];
                      }),
                    ),
                  ],
                  if (_blds.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    FloorMultiSelectDropdown(
                      selectedBuildings: _blds,
                      selectedFloors: _flrs,
                      onChanged: (f) => setState(() {
                        _flrs = f;
                        _locs = [];
                        _objs = [];
                      }),
                    ),
                  ],
                  if (_flrs.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    LocationMultiSelectDropdown(
                      companyRef: compRef,
                      selectedFloors:
                          _flrs.cast<DocumentReference<Map<String, dynamic>>>(),
                      selectedLocations:
                          _locs.cast<DocumentReference<Map<String, dynamic>>>(),
                      onChanged: (locs) => setState(() {
                        _locs = locs.map((r) => r as DocumentReference).toList();
                        _objs = [];
                      }),
                    ),
                  ],
                  if (_locs.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    ObjectMultiSelectDropdown(
                      companyId: compRef,
                      selectedLocations: _locs,
                      selectedObjects: _objs,
                      onChanged: (o) => setState(() => _objs = o),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}

class _UnscheduledAttachment {
  const _UnscheduledAttachment({
    required this.url,
    required this.mediaType,
    required this.fileType,
    this.thumbnailUrl,
    this.durationSeconds,
    this.sizeBytes,
    this.order,
    this.fileName,
    this.fileExtension,
  });

  final String url;
  final String mediaType;
  final String fileType;
  final String? thumbnailUrl;
  final int? durationSeconds;
  final int? sizeBytes;
  final int? order;
  final String? fileName;
  final String? fileExtension;
}
