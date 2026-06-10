// lib/features/tasks/screens/tasks_reports_quality_form.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/details_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/home_navbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/forms/cancel_save_adapter.dart';
import 'package:kleenops_admin/common/field_info/field_info_registry.dart';
import 'package:kleenops_admin/features/auth/providers/auth_provider.dart';
import 'package:kleenops_admin/repositories/user_repository.dart';
import 'package:kleenops_admin/services/storage_service.dart';
import 'package:kleenops_admin/services/ai/ai_context_service.dart';
import 'package:kleenops_admin/widgets/ai/ai_screen_context.dart';
import 'package:shared_widgets/containers/canvas_top_bookend.dart';
import 'package:shared_widgets/containers/container_action.dart';
import 'package:shared_widgets/fields/file_uploader.dart';
import 'package:shared_widgets/markup/image_markup.dart';
import 'package:shared_widgets/theme/app_palette.dart';
import 'package:kleenops_admin/services/ai_text_adapter.dart';
import 'package:kleenops_admin/widgets/fields/multi_select/property_multi_select.dart';
import 'package:kleenops_admin/widgets/fields/multi_select/building_multi_select.dart';
import 'package:kleenops_admin/widgets/fields/multi_select/floor_multi_select.dart';
import 'package:kleenops_admin/widgets/fields/multi_select/location_multi_select.dart';
import 'package:kleenops_admin/widgets/fields/multi_select/object_multi_select.dart';
import 'package:path/path.dart' as p;
import 'package:kleenops_admin/l10n/app_localizations.dart';
import 'package:shared_widgets/utils/process_localization_utils.dart';
import 'package:kleenops_admin/common/utils/snackbar_service.dart';

class TasksReportsQualityForm extends ConsumerStatefulWidget {
  const TasksReportsQualityForm({
    super.key,
    this.timelineRef,
    this.locationRefs,
  });

  /// Source timeline doc (completed task) we’re filing against.
  final DocumentReference<Map<String, dynamic>>? timelineRef;

  /// Pre-selected location context (optional).
  final List<DocumentReference<Map<String, dynamic>>>? locationRefs;

  @override
  ConsumerState<TasksReportsQualityForm> createState() =>
      _TasksReportsQualityFormState();
}

class _TasksReportsQualityFormState
    extends ConsumerState<TasksReportsQualityForm> {
  /* ───────── form state ───────── */
  final _nameCtl = TextEditingController();
  final _descCtl = TextEditingController();

  /* ───────── media ───────── */
  String? _imageUrl;
  String? _videoUrl;
  List<Map<String, dynamic>> _images = [];
  List<Map<String, dynamic>> _videos = [];
  List<Map<String, dynamic>> _documents = [];

  /* ───────── selections ───────── */
  List<DocumentReference> _props = [],
      _blds = [],
      _flrs = [],
      _locs = [],
      _objs = [];

  DocumentReference? _selectedTeamRef;
  DocumentReference? _createdByTeamRef;
  DocumentReference? _timelineTaskRef;
  DocumentReference<Map<String, dynamic>>? _memberRef;

  bool _loading = true;
  bool _saving = false;
  late final String _aiContextKey =
      'quality_report_form:${UniqueKey()}';
  late final Set<String> _supportedLocaleCodeSet = AppLocalizations
      .supportedLocales
      .map(_localeCodeOf)
      .where((code) => code.isNotEmpty)
      .toSet()
    ..add(_normalizeLocaleCode(ProcessLocalizationUtils.defaultLocaleCode));

  @override
  void initState() {
    super.initState();
    _initialise();
  }

  Future<void> _initialise() async {
    await Future.wait([
      _prime(widget.locationRefs ?? []),
      _loadPrimaryTeam(),
      _loadTimelineTask(),
    ]);
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _prime(
      List<DocumentReference<Map<String, dynamic>>> locRefs) async {
    final pSet = <String, DocumentReference>{};
    final bSet = <String, DocumentReference>{};
    final fSet = <String, DocumentReference>{};

    _locs = locRefs.map((r) => r as DocumentReference).toList();

    for (final loc in locRefs) {
      final d = (await loc.get()).data() ?? {};
      final p = d['propertyId'] as DocumentReference?;
      final b = d['buildingId'] as DocumentReference?;
      final f = d['floorId'] as DocumentReference?;
      if (p != null) pSet[p.id] = p;
      if (b != null) bSet[b.id] = b;
      if (f != null) fSet[f.id] = f;
    }
    _props = pSet.values.toList();
    _blds = bSet.values.toList();
    _flrs = fSet.values.toList();
  }

  Future<void> _loadPrimaryTeam() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final indexSnap = await UserRepository()
        .memberByUidGroup(uid)
        .where('active', isEqualTo: true)
        .limit(1)
        .get();

    if (indexSnap.docs.isEmpty) {
      _createdByTeamRef = null;
      _selectedTeamRef = null;
      _memberRef = null;
      return;
    }

    final indexDoc = indexSnap.docs.first;
    final memberId = indexDoc.data()['memberId'] as String?;
    if (memberId == null || memberId.trim().isEmpty) {
      _createdByTeamRef = null;
      _selectedTeamRef = null;
      _memberRef = null;
      return;
    }
    final companyRef =
        indexDoc.reference.parent.parent as DocumentReference<Map<String, dynamic>>;
    final memberDoc = companyRef.collection('member').doc(memberId.trim());
    final memberSnap = await memberDoc.get();
    final memberData = memberSnap.data() ?? <String, dynamic>{};
    _createdByTeamRef =
        memberData['primaryTeamId'] as DocumentReference?;
    _selectedTeamRef = _createdByTeamRef;
    _memberRef = memberDoc;
  }

  Future<void> _loadTimelineTask() async {
    if (widget.timelineRef == null) return;
    final data = (await widget.timelineRef!.get()).data() ?? {};
    _timelineTaskRef = data['taskId'] as DocumentReference?;
    _selectedTeamRef = data['teamId'] as DocumentReference? ?? _selectedTeamRef;
  }

  List<Map<String, dynamic>> _cloneEntries(
    List<Map<String, dynamic>> entries,
  ) {
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

  String? _stringFromEntry(
    Map<String, dynamic> entry,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = entry[key];
      if (value is String) {
        final trimmed = value.trim();
        if (trimmed.isNotEmpty) return trimmed;
      }
    }
    return null;
  }

  int? _intFromEntry(
    Map<String, dynamic> entry,
    List<String> keys,
  ) {
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

  String _attachmentName(String reportName, int index, String mediaType) {
    final trimmed = reportName.trim();
    final label = trimmed.isNotEmpty ? trimmed : 'Quality Report';
    return '$label $mediaType ${index + 1}';
  }

  String _normalizeLocaleCode(String code) {
    return ProcessLocalizationUtils.normalizeLocaleCode(code);
  }

  String _localeCodeOf(Locale locale) {
    final language = locale.languageCode.trim().toLowerCase();
    final script = locale.scriptCode?.trim().toLowerCase();
    final country = locale.countryCode?.trim().toLowerCase();
    final segments = <String>[
      if (language.isNotEmpty) language,
      if (script != null && script.isNotEmpty) script,
      if (country != null && country.isNotEmpty) country,
    ];
    if (segments.isEmpty) return '';
    return _normalizeLocaleCode(segments.join('-'));
  }

  String _resolveLocaleCode() {
    final locale = Localizations.maybeLocaleOf(context);
    final inferredFull = locale != null ? _localeCodeOf(locale) : '';
    final inferredLanguage = locale?.languageCode.trim().toLowerCase() ?? '';
    final candidates = <String>[
      if (inferredFull.isNotEmpty) inferredFull,
      if (inferredLanguage.isNotEmpty) inferredLanguage,
      ProcessLocalizationUtils.defaultLocaleCode,
    ];
    return candidates.firstWhere(
      (code) => _supportedLocaleCodeSet.contains(_normalizeLocaleCode(code)),
      orElse: () => ProcessLocalizationUtils.defaultLocaleCode,
    );
  }

  Map<String, dynamic> _buildLocalizedPayload({
    required String value,
    required String localeCode,
  }) {
    final trimmed = value.trim();
    return ProcessLocalizationUtils.buildLocalizedFieldPayload(
      source: trimmed,
      sourceLanguage: localeCode,
      translations: <String, String>{localeCode: trimmed},
      fallbackLocaleCode: ProcessLocalizationUtils.defaultLocaleCode,
    );
  }

  /* ── image markup ───────────────────────────────────────── */
  Future<void> _launchImageMarkup() async {
    if (_imageUrl == null || _imageUrl!.isEmpty) {
      SnackbarService.instance.showSnackBar(
        const SnackBar(duration: Duration(seconds: 5), content: Text('No image to mark up.')),
      );
      return;
    }
    final res = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => BasicImageMarkupScreen(imageUrl: _imageUrl!),
      ),
    );
    if (res != null && res.isNotEmpty) {
      setState(() => _imageUrl = res);
    }
  }

  /* ── save ───────────────────────────────────────────────── */
  List<_QualityAttachment> _buildAttachments() {
    final attachments = <_QualityAttachment>[];

    for (final image in _images) {
      final url = _imageUrlFromEntry(image);
      if (url == null || url.isEmpty) continue;
      attachments.add(
        _QualityAttachment(
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
        _QualityAttachment(
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
        _QualityAttachment(
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

  Future<void> _saveAttachmentDocs({
    required DocumentReference<Map<String, dynamic>> companyRef,
    required DocumentReference<Map<String, dynamic>> qualityRef,
    required DocumentReference<Map<String, dynamic>> currentMemberRef,
    required List<_QualityAttachment> attachments,
  }) async {
    if (attachments.isEmpty) return;
    final batch = FirebaseFirestore.instance.batch();
    final fileCollection = companyRef.collection('file');
    final reportName = _nameCtl.text.trim();

    for (var i = 0; i < attachments.length; i++) {
      final attachment = attachments[i];
      final fileRef = fileCollection.doc();
      final storagePath = _storagePathFromUrl(attachment.url);
      final fileName =
          attachment.fileName ?? _fileNameFromUrl(attachment.url);
      final extension = attachment.fileExtension ?? '';

      final data = <String, dynamic>{
        'firestorePath': fileRef.path,
        'downloadUrl': attachment.url,
        'name': _attachmentName(reportName, i, attachment.mediaType),
        'mediaType': attachment.mediaType,
        'fileType': attachment.fileType,
        'createdAt': FieldValue.serverTimestamp(),
        if (storagePath != null && storagePath.isNotEmpty)
          'storagePath': storagePath,
        if (fileName != null && fileName.trim().isNotEmpty)
          'sourceFileName': fileName.trim(),
        if (extension.isNotEmpty) 'fileExtension': extension,
        if (attachment.thumbnailUrl != null &&
            attachment.thumbnailUrl!.trim().isNotEmpty)
          'thumbnailUrl': attachment.thumbnailUrl!.trim(),
        if (attachment.durationSeconds != null)
          'duration': attachment.durationSeconds,
        if (attachment.durationSeconds != null)
          'videoDuration': attachment.durationSeconds,
        if (attachment.sizeBytes != null) 'sizeBytes': attachment.sizeBytes,
        if (attachment.order != null) 'order': attachment.order,
        if (widget.timelineRef != null) 'timelineId': widget.timelineRef,
        if (_timelineTaskRef != null) 'taskId': _timelineTaskRef,
        'qualityId': qualityRef,
        'memberRef': currentMemberRef,
        'createdBy': currentMemberRef,
        if (_selectedTeamRef != null) 'teamId': _selectedTeamRef,
        if (_createdByTeamRef != null) 'createdByTeamId': _createdByTeamRef,
      };

      batch.set(fileRef, data);
    }

    await batch.commit();
  }

  Future<void> _save() async {
    if (_saving) return;
    final loc = AppLocalizations.of(context)!;

    final name = _nameCtl.text.trim();
    final desc = _descCtl.text.trim();
    if (name.isEmpty || desc.isEmpty) {
      SnackbarService.instance.showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 5),
          content: Text(loc.processesFormNameRequiredMessage),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final attachments = _buildAttachments();
    setState(() => _saving = true);

    // Calculate endTime as 20 minutes from now
    final currentTime = DateTime.now();
    final createdAtTs = Timestamp.fromDate(currentTime);
    final endTime = Timestamp.fromDate(
      currentTime.add(const Duration(minutes: 30)),
    );

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw 'Not logged in';

      DocumentReference<Map<String, dynamic>>? compRef;
      ref.read(companyIdProvider).whenData((c) => compRef = c);
      if (compRef == null) throw 'No company context';

      final companyRef = compRef!;
      final localeCode = _resolveLocaleCode();
      final timelineColl = companyRef.collection('timeline');
      final uid = user.uid;

      String denormalizedTaskName = '';
      if (_timelineTaskRef != null) {
        try {
          final snap = await _timelineTaskRef!.get();
          final taskData = snap.data() as Map<String, dynamic>?;
          if (taskData != null) {
            denormalizedTaskName = (taskData['name'] ??
                    taskData['title'] ??
                    taskData['taskName'] ??
                    '')
                .toString()
                .trim();
          }
        } catch (_) {}
      }

      String denormalizedObjectName = '';
      if (_objs.isNotEmpty) {
        try {
          final snap = await _objs.first.get();
          final objData = snap.data() as Map<String, dynamic>?;
          if (objData != null) {
            denormalizedObjectName = (objData['name'] ??
                    objData['companyObjectName'] ??
                    objData['objectName'] ??
                    '')
                .toString()
                .trim();
          }
        } catch (_) {}
      }

      Future<DocumentReference<Map<String, dynamic>>?> resolveMemberRef(
        String memberOrUid,
      ) async {
        final trimmed = memberOrUid.trim();
        if (trimmed.isEmpty) return null;
        final directRef = companyRef.collection('member').doc(trimmed);
        final directSnap = await directRef.get();
        if (directSnap.exists) return directRef;
        final indexSnap =
            await companyRef.collection('memberByUid').doc(trimmed).get();
        final memberId = indexSnap.data()?['memberId'] as String?;
        if (memberId == null || memberId.trim().isEmpty) return null;
        return companyRef.collection('member').doc(memberId.trim());
      }

      Map<String, dynamic> baseData({
        required DocumentReference<Map<String, dynamic>> subjectMemberRef,
        required DocumentReference<Map<String, dynamic>> currentMemberRef,
      }) {
        final data = <String, dynamic>{
          'title': name,
          'name': name,
          'description': desc,
          'titleLocalized': _buildLocalizedPayload(
            value: name,
            localeCode: localeCode,
          ),
          'nameLocalized': _buildLocalizedPayload(
            value: name,
            localeCode: localeCode,
          ),
          'descriptionLocalized': _buildLocalizedPayload(
            value: desc,
            localeCode: localeCode,
          ),
          'propertyId': _props,
          'buildingId': _blds,
          'floorId': _flrs,
          'locationId': _locs,
          'objectIds': _objs,
          'taskId': _timelineTaskRef,
          if (denormalizedTaskName.isNotEmpty) 'taskName': denormalizedTaskName,
          if (denormalizedObjectName.isNotEmpty)
            'objectName': denormalizedObjectName,
          'createdBy': currentMemberRef,
          // Stored as the member doc ID (string) — the timeline security
          // rule compares this against callerMemberId(), which is a string.
          // A DocumentReference here fails the create rule (permission-denied).
          'createdByMemberId': currentMemberRef.id,
          'teamId': _selectedTeamRef,
          'createdByTeamId': _createdByTeamRef,
          'timelineId': widget.timelineRef,
          'timelineCategory': 'VdjzT5izZVSWmrhfRRq0',
          'timelineCategoryId': FirebaseFirestore.instance
              .collection('timelineCategory')
              .doc('VdjzT5izZVSWmrhfRRq0'),
          'opened': false,
          'interrupting': true,
          'createdAt': createdAtTs,
          'startTime': createdAtTs,
          'endTime': endTime,
          'memberId': subjectMemberRef,
        }..removeWhere((k, v) => v == null);
        return data;
      }

      var contributorIds = <String>[];
      if (widget.timelineRef != null) {
        final snap = await widget.timelineRef!.get();
        final data = snap.data() ?? {};
        final contribMap = (data['contributors'] ?? {}) as Map<String, dynamic>;
        contributorIds = contribMap.keys.whereType<String>().toList();
      }

      final currentMemberRef = _memberRef ?? await resolveMemberRef(uid);
      if (currentMemberRef == null) {
        throw 'Member profile not found';
      }

      final createdQualityRefs = <DocumentReference<Map<String, dynamic>>>[];
      if (contributorIds.isEmpty) {
        final docData = baseData(
          subjectMemberRef: currentMemberRef,
          currentMemberRef: currentMemberRef,
        );
        final docRef = await timelineColl.add(docData);
        createdQualityRefs.add(docRef);
      } else {
        for (final id in contributorIds) {
          final subjectMemberRef = await resolveMemberRef(id);
          if (subjectMemberRef == null) continue;
          final docData = baseData(
            subjectMemberRef: subjectMemberRef,
            currentMemberRef: currentMemberRef,
          );
          final docRef = await timelineColl.add(docData);
          createdQualityRefs.add(docRef);
        }
      }

      if (attachments.isNotEmpty) {
        for (final qualityRef in createdQualityRefs) {
          await _saveAttachmentDocs(
            companyRef: companyRef,
            qualityRef: qualityRef,
            currentMemberRef: currentMemberRef,
            attachments: attachments,
          );
        }
      }
      SnackbarService.instance.showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 5),
          content: Text(
            'Quality report saved${contributorIds.isNotEmpty ? ' for ${contributorIds.length} user(s)' : ''}',
          ),
        ),
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      SnackbarService.instance.showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 5),
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final compRef = ref.watch(companyIdProvider).maybeWhen(
          data: (c) => c,
          orElse: () => null,
        );
    final palette = AppPaletteScope.of(context);
    if (compRef == null || _loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      body: SafeArea(
        top: true,
        bottom: false,
        child: AiScreenContext(
        context: AiContextState(
          key: _aiContextKey,
          sectionKey: 'quality',
          screenType: 'quality_report_form',
          label: loc.nav_quality,
          forms: AiContextPresets.qualityForms,
          actions: AiContextPresets.qualityActions,
          guidance: AiContextPresets.qualityGuidance,
          title: '${loc.nav_quality} AI',
          subtitle: loc.fieldInfoTrainingDetailsBody,
        ),
        child: _saving
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: EdgeInsets.zero,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const CanvasTopBookend(),
                    const SizedBox(height: 8),
                    ContainerActionWidget(
                      title: loc.fieldInfoTrainingElementContentTitle,
                      titleInfoKey: FieldInfoKeys.tasksQualityImages,
                      actionText: '',
                      content: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          FileUploaderField(
                            allowImages: true,
                            allowVideos: true,
                            allowDocuments: true,
                            enablePdfMarkup: false,
                            imageUrl: _imageUrl,
                            images: _images,
                            onImagesChanged: (entries) {
                              setState(() => _images = _cloneEntries(entries));
                            },
                            onImageChanged: (u) => setState(
                              () => _imageUrl = u.trim().isEmpty ? null : u,
                            ),
                            onMarkupTap: _launchImageMarkup,
                            videoUrl: _videoUrl,
                            videos: _videos,
                            onVideosChanged: (videos) {
                              setState(() => _videos = _cloneEntries(videos));
                            },
                            onVideoChanged: (u) => setState(
                              () => _videoUrl = u.trim().isEmpty ? null : u,
                            ),
                            onVideoDurationChanged: _updateVideoDuration,
                            documents: _documents,
                            onDocumentsChanged: (docs) {
                              setState(() => _documents = _cloneEntries(docs));
                            },
                            imageStorageFolder:
                                'company/${compRef.id}/timeline/images',
                            videoStorageFolder:
                                'company/${compRef.id}/timeline/videos',
                            documentStorageFolder:
                                'company/${compRef.id}/timeline/files',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    ContainerActionWidget(
                      title: loc.nav_quality,
                      titleInfoKey: FieldInfoKeys.tasksQualityDetails,
                      actionText: '',
                      content: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          AITextField(
                            labelText: loc.commonName,
                            initialValue: _nameCtl.text,
                            onChanged: (t) => _nameCtl.text = t,
                          ),
                          const SizedBox(height: 16),
                          AITextField(
                            labelText: loc.commonDescription,
                            initialValue: _descCtl.text,
                            onChanged: (t) => _descCtl.text = t,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    ContainerActionWidget(
                      title: loc.fieldInfoFacilitiesBuildingLocationTitle,
                      titleInfoKey: FieldInfoKeys.tasksQualityLocation,
                      actionText: '',
                      content: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          PropertyMultiSelectDropdown(
                            companyId: compRef,
                            selectedProperties: _props,
                            onChanged: (p) => setState(() => _props = p),
                            selectedColor: palette.primary2,
                          ),
                          const SizedBox(height: 16),
                          BuildingMultiSelectDropdown(
                            selectedProperties: _props,
                            selectedBuildings: _blds,
                            onChanged: (b) => setState(() => _blds = b),
                            selectedColor: palette.primary2,
                          ),
                          const SizedBox(height: 16),
                          FloorMultiSelectDropdown(
                            selectedBuildings: _blds,
                            selectedFloors: _flrs,
                            onChanged: (f) => setState(() => _flrs = f),
                            selectedColor: palette.primary2,
                          ),
                          const SizedBox(height: 16),
                          LocationMultiSelectDropdown(
                            companyRef: compRef,
                            selectedFloors: _flrs
                                .cast<DocumentReference<Map<String, dynamic>>>(),
                            selectedLocations: _locs
                                .cast<DocumentReference<Map<String, dynamic>>>(),
                            selectedColor: palette.primary2,
                            onChanged: (locs) {
                              setState(() {
                                _locs = locs
                                    .map((r) => r as DocumentReference)
                                    .toList();
                                _objs = [];
                              });
                            },
                          ),
                          const SizedBox(height: 16),
                          ObjectMultiSelectDropdown(
                            companyId: compRef,
                            selectedLocations: _locs,
                            selectedObjects: _objs,
                            onChanged: (o) => setState(() => _objs = o),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 80),
                  ],
                ),
              ),
        ),
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Theme(
            data: Theme.of(context).copyWith(primaryColor: palette.primary2),
            child: CancelSaveBar(
              onCancel: () => Navigator.pop(context),
              onSave: _save,
              isSaving: _saving,
              // Stacked above DetailsAppBar + HomeNavBarAdapter — the OS
              // nav-bar inset is reserved once by HomeNavBar (lowest bar),
              // so this bar must not duplicate it.
              reserveNavBarSpace: false,
            ),
          ),
          DetailsAppBar(
            title: loc.nav_quality,
            onAiPressed: ref.read(aiCanvasControllerProvider).toggle,
          ),
          const HomeNavBarAdapter(),
        ],
      ),
    );
  }
}

class _QualityAttachment {
  const _QualityAttachment({
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

