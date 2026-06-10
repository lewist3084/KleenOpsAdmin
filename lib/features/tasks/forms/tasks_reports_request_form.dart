// lib/features/tasks/screens/tasks_reports_request_form.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:kleenops_admin/app/shared_widgets/forms/form_ai_bottom_bar.dart';
import 'package:kleenops_admin/common/field_info/field_info_registry.dart';
import 'package:shared_widgets/services/firestore_service.dart';
import 'package:kleenops_admin/features/auth/providers/auth_provider.dart';
import 'package:kleenops_admin/repositories/task_repository.dart';
import 'package:kleenops_admin/repositories/user_repository.dart';
import 'package:kleenops_admin/services/ai/ai_context_service.dart';
import 'package:kleenops_admin/widgets/ai/ai_screen_context.dart';
import 'package:kleenops_admin/widgets/layout/bookended_canvas.dart';
import 'package:kleenops_admin/services/storage_service.dart';
import 'package:kleenops_admin/l10n/app_localizations.dart';
import 'package:shared_widgets/utils/process_localization_utils.dart';

import 'package:shared_widgets/containers/container_action.dart';
import 'package:shared_widgets/fields/markup_image_field.dart';
import 'package:shared_widgets/markup/image_markup.dart';
import 'package:kleenops_admin/services/ai_text_adapter.dart';
import 'package:shared_widgets/fields/video_field.dart';
import 'package:kleenops_admin/widgets/fields/multi_select/property_multi_select.dart';
import 'package:kleenops_admin/widgets/fields/multi_select/building_multi_select.dart';
import 'package:kleenops_admin/widgets/fields/multi_select/floor_multi_select.dart';
import 'package:kleenops_admin/widgets/fields/multi_select/location_multi_select.dart';
import 'package:kleenops_admin/widgets/fields/multi_select/object_multi_select.dart';
import 'package:kleenops_admin/widgets/fields/team_select.dart';
import 'package:kleenops_admin/common/utils/snackbar_service.dart';

class TasksReportsRequestForm extends ConsumerStatefulWidget {
  const TasksReportsRequestForm({
    super.key,
    this.timelineRef,
    this.locationRefs,
    this.initialName,
    this.initialDescription,
    this.customerRefs,
    this.serviceRequestRef,
    this.reviewTaskRef,
  });

  final DocumentReference<Map<String, dynamic>>? timelineRef;
  final List<DocumentReference<Map<String, dynamic>>>? locationRefs;

  /// Optional seed values when launching from another flow (e.g. converting a
  /// customer-portal service request into a requested task). When
  /// [serviceRequestRef] is supplied, the saved task is also marked
  /// `active: true` so it surfaces on the timeline immediately.
  final String? initialName;
  final String? initialDescription;
  final List<DocumentReference<Map<String, dynamic>>>? customerRefs;
  final DocumentReference<Map<String, dynamic>>? serviceRequestRef;

  /// Review-mode: when set, the form loads fields from this existing
  /// `request: true, active: false` draft task (created server-side by
  /// `onServiceRequestCreated` / `onPublicRequestCreated`). Save updates
  /// the doc in place and flips `active: true` (= "Approve & schedule").
  /// A Decline action is also shown which flips the linked source request
  /// to `status: 'declined'` and leaves the task inactive.
  final DocumentReference<Map<String, dynamic>>? reviewTaskRef;

  @override
  ConsumerState<TasksReportsRequestForm> createState() =>
      _TasksReportsRequestFormState();
}

class _TasksReportsRequestFormState
    extends ConsumerState<TasksReportsRequestForm> {
  final _nameCtl = TextEditingController();
  final _descCtl = TextEditingController();

  String? _imageUrl;
  String? _videoUrl;

  List<DocumentReference> _props = [];
  List<DocumentReference> _blds = [];
  List<DocumentReference> _flrs = [];
  List<DocumentReference> _locs = [];
  List<DocumentReference> _objs = [];

  DocumentReference? _selectedTeamRef;
  DocumentReference? _createdByTeamRef;
  DocumentReference? _timelineTaskRef;

  /// Customer inherited from the source task this request was launched from
  /// (a DocumentReference, or a List for portal-shaped sources). Lets the
  /// request carry the right customer without the requester picking one.
  Object? _sourceCustomerId;

  bool _loading = true;
  bool _saving = false;
  bool _declining = false;
  // Review-mode state: loaded source-request refs so Decline can flip the
  // source doc's status without re-reading the task.
  DocumentReference<Map<String, dynamic>>? _loadedServiceRequestRef;
  DocumentReference<Map<String, dynamic>>? _loadedPublicRequestRef;
  String? _loadedRequestSource;
  late final String _aiContextKey =
      'tasks_service_request_form:${UniqueKey()}';
  late final Set<String> _supportedLocaleCodeSet = AppLocalizations
      .supportedLocales
      .map(_localeCodeOf)
      .where((code) => code.isNotEmpty)
      .toSet()
    ..add(_normalizeLocaleCode(ProcessLocalizationUtils.defaultLocaleCode));

  @override
  void initState() {
    super.initState();
    if (widget.initialName != null && widget.initialName!.isNotEmpty) {
      _nameCtl.text = widget.initialName!;
    }
    if (widget.initialDescription != null &&
        widget.initialDescription!.isNotEmpty) {
      _descCtl.text = widget.initialDescription!;
    }
    _initialise();
  }

  Future<void> _initialise() async {
    await Future.wait([
      _prime(widget.locationRefs ?? []),
      _loadPrimaryTeam(),
      _loadTimelineTask(),
      _loadReviewTask(),
    ]);
    if (mounted) setState(() => _loading = false);
  }

  /// Review-mode: pull the existing draft task into the form's controllers.
  /// Overwrites name/description/team/location selections set by [_prime] /
  /// [_loadPrimaryTeam] / widget seed params, since the draft is the source
  /// of truth — those other paths were no-ops anyway (no widget seeds are
  /// passed in review mode).
  Future<void> _loadReviewTask() async {
    final taskRef = widget.reviewTaskRef;
    if (taskRef == null) return;
    final snap = await taskRef.get();
    final data = snap.data();
    if (data == null) return;

    _nameCtl.text = _stringOf(data['task']).trim();
    _descCtl.text = _stringOf(data['description']).trim();
    _imageUrl = _stringOf(data['imageMessage']);
    if (_imageUrl != null && _imageUrl!.isEmpty) _imageUrl = null;
    _videoUrl = _stringOf(data['videoMessage']);
    if (_videoUrl != null && _videoUrl!.isEmpty) _videoUrl = null;
    _props = _refsOf(data['propertyId']);
    _blds = _refsOf(data['buildingId']);
    _flrs = _refsOf(data['floorId']);
    _locs = _refsOf(data['locationId']);
    _objs = _refsOf(data['objectIds']);
    final team = data['teamId'];
    if (team is DocumentReference) _selectedTeamRef = team;
    final serviceReq = data['serviceRequestRef'];
    if (serviceReq is DocumentReference<Map<String, dynamic>>) {
      _loadedServiceRequestRef = serviceReq;
    }
    final publicReq = data['publicRequestRef'];
    if (publicReq is DocumentReference<Map<String, dynamic>>) {
      _loadedPublicRequestRef = publicReq;
    }
    _loadedRequestSource = _stringOf(data['requestSource']);
  }

  String _stringOf(dynamic v) => v is String ? v : '';

  List<DocumentReference> _refsOf(dynamic v) {
    if (v is! List) return [];
    return v.whereType<DocumentReference>().toList();
  }

  Future<void> _prime(
    List<DocumentReference<Map<String, dynamic>>> locRefs,
  ) async {
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
    final companyRef =
        indexDoc.reference.parent.parent as DocumentReference<Map<String, dynamic>>;
    final memberRef = companyRef.collection('member').doc(memberId.trim());
    final memberSnap = await memberRef.get();
    final memberData = memberSnap.data() ?? <String, dynamic>{};
    _createdByTeamRef = memberData['primaryTeamId'] as DocumentReference?;
    _selectedTeamRef = _createdByTeamRef;
  }

  Future<void> _loadTimelineTask() async {
    if (widget.timelineRef == null) return;
    final data = (await widget.timelineRef!.get()).data() ?? {};
    _timelineTaskRef = data['taskId'] as DocumentReference?;
    if (_timelineTaskRef == null) return;

    final taskSnap = await _timelineTaskRef!.get();
    final taskData = (taskSnap.data() as Map<String, dynamic>?) ?? const {};

    // Inherit the source task's customer so the request is correctly attributed.
    // May be a single ref or a list — passed through verbatim.
    //
    // The name & description are intentionally NOT pre-seeded from the source
    // task: the requester must name the requested task and describe it in their
    // own words. (Review mode loads the existing draft's own name/desc.)
    _sourceCustomerId = taskData['customerId'];
  }

  Future<void> _save() async {
    if (_saving) return;
    final loc = AppLocalizations.of(context)!;

    final name = _nameCtl.text.trim();
    if (name.isEmpty) {
      SnackbarService.instance.showSnackBar(
        SnackBar(duration: const Duration(seconds: 5), content: Text(loc.processesFormNameRequiredMessage)),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw 'Not logged in';

      final compRef = await ref.read(companyIdProvider.future);
      if (compRef == null) throw 'No company context';

      final localeCode = _resolveLocaleCode();
      final description = _descCtl.text.trim();
      final reviewRef = widget.reviewTaskRef;
      final fromServiceRequest = widget.serviceRequestRef != null;

      if (reviewRef != null) {
        // ── Review-mode: update the existing draft + flip active:true ─
        // The server already stamped requestSource/serviceRequestRef/etc;
        // we only write the supervisor's edits + the activation flag.
        final updatePayload = <String, dynamic>{
          'task': name,
          'description': description,
          'taskLocalized': _buildLocalizedPayload(
            value: name,
            localeCode: localeCode,
          ),
          if (description.isNotEmpty)
            'descriptionLocalized': _buildLocalizedPayload(
              value: description,
              localeCode: localeCode,
            ),
          'propertyId': _props,
          'buildingId': _blds,
          'floorId': _flrs,
          'locationId': _locs,
          'objectIds': _objs,
          'teamId': _selectedTeamRef,
          if (_createdByTeamRef != null) 'createdByTeamId': _createdByTeamRef,
          if (_sourceCustomerId != null) 'customerId': _sourceCustomerId,
          'active': true,
          'approvedAt': FieldValue.serverTimestamp(),
          'approvedByUid': user.uid,
          if (_imageUrl != null && _imageUrl!.trim().isNotEmpty)
            'imageMessage': _imageUrl!.trim(),
          if (_videoUrl != null && _videoUrl!.trim().isNotEmpty)
            'videoMessage': _videoUrl!.trim(),
        };
        await reviewRef.update(updatePayload);
        await _saveMediaFiles(
          companyRef: compRef,
          taskRef: reviewRef,
          timelineRef: widget.timelineRef,
          imageUrl: _imageUrl,
          videoUrl: _videoUrl,
        );
        SnackbarService.instance.showSnackBar(
          const SnackBar(
            duration: Duration(seconds: 4),
            content: Text('Approved & scheduled'),
          ),
        );
        if (mounted) Navigator.pop(context);
        return;
      }

      final taskColl = compRef.collection('task');
      final data = <String, dynamic>{
        'task': name,
        'description': description,
        'taskLocalized': _buildLocalizedPayload(
          value: name,
          localeCode: localeCode,
        ),
        if (description.isNotEmpty)
          'descriptionLocalized': _buildLocalizedPayload(
            value: description,
            localeCode: localeCode,
          ),
        'propertyId': _props,
        'buildingId': _blds,
        'floorId': _flrs,
        'locationId': _locs,
        'objectIds': _objs,
        'taskId': _timelineTaskRef,
        'teamId': _selectedTeamRef,
        'createdByTeamId': _createdByTeamRef,
        if (_sourceCustomerId != null) 'customerId': _sourceCustomerId,
        'timelineId': widget.timelineRef,
        'createdAt': FieldValue.serverTimestamp(),
        'request': true,
        'internal': true,
        'requestSource': 'internal',
        // Internal requests land in the scheduling Queue for review/acceptance,
        // so they must be written with active:false explicitly — the Queue list
        // and badge query `active == false`, which does NOT match a missing
        // field. Portal/QR conversions (fromServiceRequest) activate
        // immediately so handleRequestedTask in functions/tasks.js creates the
        // timeline entry on first write.
        'active': fromServiceRequest,
        if (fromServiceRequest) ...{
          'serviceRequestRef': widget.serviceRequestRef,
          if (widget.customerRefs != null && widget.customerRefs!.isNotEmpty)
            'customerId': widget.customerRefs,
        },
      };
      data.removeWhere((k, v) => v == null);
      final meta = await FirestoreService().buildCreateMeta(taskColl);
      final docRef = await taskColl.add({...data, ...meta});
      await _saveMediaFiles(
        companyRef: compRef,
        taskRef: docRef,
        timelineRef: widget.timelineRef,
        imageUrl: _imageUrl,
        videoUrl: _videoUrl,
      );
      SnackbarService.instance.showSnackBar(
        SnackBar(duration: const Duration(seconds: 5), content: Text('${loc.nav_reports} ${loc.commonSave}')),
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

  /// Review-mode only: leave the draft task inactive and mark the source
  /// request as declined so the customer/QR submitter sees it's been
  /// reviewed and won't materialize on the timeline. The task doc stays
  /// in `task` with `request: true, active: false` for audit history.
  Future<void> _decline() async {
    if (_declining || _saving) return;
    final reviewRef = widget.reviewTaskRef;
    if (reviewRef == null) return;

    final reason = await showDialog<String?>(
      context: context,
      builder: (ctx) {
        final ctl = TextEditingController();
        return AlertDialog(
          title: const Text('Decline request'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('The task will stay in the database (inactive) for '
                  'history. The requester will see the request as declined.'),
              const SizedBox(height: 12),
              TextField(
                controller: ctl,
                decoration: const InputDecoration(
                  labelText: 'Reason (optional)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, null),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, ctl.text.trim()),
              child: const Text('Decline'),
            ),
          ],
        );
      },
    );
    if (reason == null) return;

    setState(() => _declining = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      final now = FieldValue.serverTimestamp();

      await reviewRef.update({
        'declinedAt': now,
        if (user != null) 'declinedByUid': user.uid,
        if (reason.isNotEmpty) 'declineReason': reason,
      });

      final sourceRef =
          _loadedServiceRequestRef ?? _loadedPublicRequestRef;
      if (sourceRef != null) {
        await sourceRef.update({
          'status': 'declined',
          'declinedAt': now,
          'updatedAt': now,
          if (reason.isNotEmpty) 'declineReason': reason,
        });
      }

      SnackbarService.instance.showSnackBar(
        const SnackBar(
          duration: Duration(seconds: 4),
          content: Text('Request declined'),
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
      if (mounted) setState(() => _declining = false);
    }
  }

  Future<void> _launchImageMarkup() async {
    if (_imageUrl == null || _imageUrl!.isEmpty) {
      SnackbarService.instance.showSnackBar(
        const SnackBar(duration: Duration(seconds: 5), content: Text('No image to mark up.')),
      );
      return;
    }
    final updated = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => BasicImageMarkupScreen(imageUrl: _imageUrl!),
      ),
    );
    if (updated != null && updated.isNotEmpty) {
      setState(() => _imageUrl = updated);
    }
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

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final compRef = ref.watch(companyIdProvider).maybeWhen(
          data: (c) => c,
          orElse: () => null,
        );
    if (compRef == null || _loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final isReview = widget.reviewTaskRef != null;

    return Scaffold(
      body: BookendedCanvas(
        child: AiScreenContext(
        context: AiContextState(
          key: _aiContextKey,
          sectionKey: 'tasks',
          screenType: 'tasks_service_request_form',
          label: loc.nav_reports,
          forms: AiContextPresets.tasksForms,
          actions: AiContextPresets.tasksActions,
          guidance: AiContextPresets.tasksGuidance,
          title: '${loc.nav_tasks} AI',
          subtitle: loc.fieldInfoTrainingDetailsBody,
        ),
        child: _saving
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: EdgeInsets.zero,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (isReview) _buildReviewHeader(),
                    // 1) File uploader (images + video) — top of the form.
                    ContainerActionWidget(
                      title: loc.fieldInfoTrainingElementContentTitle,
                      titleInfoKey: FieldInfoKeys.tasksRequestVisuals,
                      actionText: '',
                      content: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          MarkupImageField(
                            imageUrl: _imageUrl,
                            onImageChanged: (u) => setState(() => _imageUrl = u),
                            onMarkupTap: _launchImageMarkup,
                            storageFolder:
                                'company/${compRef.id}/timeline/images',
                          ),
                          const SizedBox(height: 16),
                          VideoField(
                            videoUrl: _videoUrl,
                            onVideoChanged: (u) => setState(() => _videoUrl = u),
                            storageFolder:
                                'company/${compRef.id}/timeline/videos',
                            hintText: 'No video selected',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // 2) Task name + description.
                    ContainerActionWidget(
                      title: loc.fieldInfoTrainingDetailsTitle,
                      titleInfoKey: FieldInfoKeys.tasksRequestDetails,
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
                    // 3) Property / building / floor / location (+ object).
                    ContainerActionWidget(
                      title: loc.fieldInfoFacilitiesBuildingLocationTitle,
                      titleInfoKey: FieldInfoKeys.tasksRequestLocation,
                      actionText: '',
                      content: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          PropertyMultiSelectDropdown(
                            companyId: compRef,
                            selectedProperties: _props,
                            onChanged: (p) => setState(() => _props = p),
                          ),
                          const SizedBox(height: 16),
                          BuildingMultiSelectDropdown(
                            selectedProperties: _props,
                            selectedBuildings: _blds,
                            onChanged: (b) => setState(() => _blds = b),
                          ),
                          const SizedBox(height: 16),
                          FloorMultiSelectDropdown(
                            selectedBuildings: _blds,
                            selectedFloors: _flrs,
                            onChanged: (f) => setState(() => _flrs = f),
                          ),
                          const SizedBox(height: 16),
                          LocationMultiSelectDropdown(
                            companyRef: compRef,
                            selectedFloors:
                                _flrs.cast<DocumentReference<Map<String, dynamic>>>(),
                            selectedLocations:
                                _locs.cast<DocumentReference<Map<String, dynamic>>>(),
                            onChanged: (locs) {
                              setState(() {
                                _locs =
                                    locs.map((r) => r as DocumentReference).toList();
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
                    const SizedBox(height: 16),
                    // 4) Team assignment.
                    ContainerActionWidget(
                      title: loc.nav_team,
                      titleInfoKey: FieldInfoKeys.tasksRequestLocation,
                      actionText: '',
                      content: TeamReferenceDropdown(
                        selectedTeam: _selectedTeamRef,
                        onChanged: (t) => setState(() => _selectedTeamRef = t),
                      ),
                    ),
                    const SizedBox(height: 80),
                  ],
                ),
              ),
        ),
      ),
      bottomNavigationBar: FormAiBottomBar(
        title: loc.nav_reports,
        onCancel: () => Navigator.pop(context),
        onSave: _save,
      ),
    );
  }

  Widget _buildReviewHeader() {
    final source = _loadedRequestSource ?? '';
    final label = switch (source) {
      'portal' => 'From customer portal',
      'qr' => 'From QR code scan',
      _ => 'Pending approval',
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          Icon(
            source == 'qr' ? Icons.qr_code_2 : Icons.support_agent,
            size: 18,
            color: Colors.grey[700],
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey[700],
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton.icon(
            onPressed: _declining ? null : _decline,
            icon: _declining
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.do_not_disturb_on_outlined, size: 18),
            label: const Text('Decline'),
            style: TextButton.styleFrom(foregroundColor: Colors.red[700]),
          ),
        ],
      ),
    );
  }

  Future<void> _saveMediaFiles({
    required DocumentReference<Map<String, dynamic>> companyRef,
    required DocumentReference<Map<String, dynamic>> taskRef,
    DocumentReference<Map<String, dynamic>>? timelineRef,
    String? imageUrl,
    String? videoUrl,
  }) async {
    final fileCollection = companyRef.collection('file');
    final batch = ref.read(taskRepositoryProvider).batch();
    var writes = 0;

    void addFile({
      required String url,
      required String mediaType,
      required String fileType,
      int order = 0,
    }) {
      final trimmed = url.trim();
      if (trimmed.isEmpty) return;
      final docRef = fileCollection.doc();
      final storagePath = StorageService().extractPathFromUrl(trimmed).trim();
      final payload = <String, dynamic>{
        'firestorePath': docRef.path,
        'downloadUrl': trimmed,
        'fileUrl': trimmed,
        'name': 'Task Request $mediaType',
        'mediaType': mediaType,
        'fileType': fileType,
        'taskId': taskRef,
        'order': order,
        'createdAt': FieldValue.serverTimestamp(),
      };
      if (timelineRef != null) payload['timelineId'] = timelineRef;
      if (storagePath.isNotEmpty) payload['storagePath'] = storagePath;
      batch.set(docRef, payload);
      writes += 1;
    }

    if (imageUrl != null && imageUrl.trim().isNotEmpty) {
      addFile(url: imageUrl, mediaType: 'Image', fileType: 'image');
    }
    if (videoUrl != null && videoUrl.trim().isNotEmpty) {
      addFile(url: videoUrl, mediaType: 'Video', fileType: 'video', order: 1);
    }

    if (writes > 0) {
      await batch.commit();
    }
  }
}
