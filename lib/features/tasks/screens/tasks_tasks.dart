//  lib/features/tasks/screens/tasks_tasks.dart                 */
import 'dart:async';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:kleenops_admin/app/routes.dart';
import 'package:kleenops_admin/features/tasks/forms/tasks_reports_request_form.dart';
import 'package:kleenops_admin/features/quality/forms/tasks_reports_quality_form.dart';
import '../details/tasks_tasks_details.dart';
import '../tabs/task_details_tabs.dart';
import 'package:shared_widgets/lists/standardView.dart';
import 'package:kleenops_admin/widgets/tiles/task_tile.dart';
import 'package:kleenops_admin/features/tasks/logic/task_boundaries.dart';
import 'package:kleenops_admin/features/tasks/logic/task_data_logic.dart';
import 'package:kleenops_admin/features/tasks/logic/task_list_filter.dart';
import 'package:kleenops_admin/features/tasks/logic/time_based_rebuild_mixin.dart';
import 'package:kleenops_admin/features/tasks/screens/dialogs/trailing_actions.dart';
import 'package:kleenops_admin/features/auth/providers/auth_provider.dart';
import 'package:kleenops_admin/services/video_call_overlay_controller.dart';
import 'package:kleenops_admin/services/video_call_service.dart';
import 'package:kleenops_admin/features/tasks/providers/tasks_timeline_provider.dart';
import 'package:kleenops_admin/features/tasks/providers/task_list_controller.dart';
import 'package:kleenops_admin/features/tasks/screens/components/task_list_view.dart';
import 'package:kleenops_admin/app/shared_widgets/search/search_control_strip_adapter.dart';
import 'package:shared_widgets/theme/app_palette.dart';
import 'package:kleenops_admin/features/tasks/screens/dialogs/task_alert_dialog.dart';
import 'package:kleenops_admin/features/tasks/providers/tasks_provider.dart';
import 'package:kleenops_admin/repositories/task_repository.dart';
import 'package:kleenops_admin/widgets/drawers/task_drawer.dart';
import 'package:kleenops_admin/features/tasks/screens/dialogs/task_timer_dialog.dart';
import 'package:kleenops_admin/common/communications/texting/services/texting_service.dart';
import 'package:kleenops_admin/common/communications/texting/screens/text_conversation_detail_screen.dart';
import 'package:shared_widgets/utils/contact_info.dart';
import 'package:kleenops_admin/common/utils/snackbar_service.dart';
// Task-Settings dialog
/* ───────── widget ───────── */
class TasksTasksContent extends ConsumerStatefulWidget {
  const TasksTasksContent({super.key});
  @override
  ConsumerState<TasksTasksContent> createState() => _TasksTasksContentState();
}
class _TasksTasksContentState extends ConsumerState<TasksTasksContent>
    with
        AutomaticKeepAliveClientMixin<TasksTasksContent>,
        WidgetsBindingObserver,
        TimeBasedRebuildMixin<TasksTasksContent> {
  /* ── state ── */
  TaskDataSnapshot? _taskDataSnapshot;
  int _swipeSnackBarEpoch = 0;
  bool _lastOverrideFilter = false;
  bool _overrideResetInFlight = false;
  bool _wasOnTasksTab = false;
  DocumentReference<Map<String, dynamic>>? _overrideMemberRef;
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  final ImagePicker _imagePicker = ImagePicker();
  Uint8List? _searchAttachmentBytes;
  String? _searchAttachmentName;
  bool _searchAttachmentIsImage = false;
  @override
  bool get wantKeepAlive => true;
  // expansion removed: leading icon now opens a left-side task drawer
  // search now stored in taskListControllerProvider
  /* ───────── helpers ───────── */
  Map<String, dynamic> _ac(Map? raw) =>
      (raw ?? const <String, dynamic>{}).cast<String, dynamic>();
  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.isEmpty) return '';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }
  static const List<String> _teamAccessKeys = <String>[
    'teamAccess',
    'TeamAccess',
    'Team Access',
  ];
  List<dynamic> _resolveTeamAccess(Map<String, dynamic> data) {
    for (final key in _teamAccessKeys) {
      final value = data[key];
      if (value is List) return value;
    }
    return const <dynamic>[];
  }
  Set<String> _roleIdsFromUser(Map<String, dynamic> userData) {
    final roleIds = <String>{};
    void addRole(dynamic raw) {
      if (raw is DocumentReference) {
        roleIds.add(raw.id);
        return;
      }
      if (raw is String) {
        final trimmed = raw.trim();
        if (trimmed.isEmpty) return;
        roleIds.add(
          trimmed.contains('/') ? trimmed.split('/').last : trimmed,
        );
      }
    }
    final raw = userData['roleId'] ?? userData['roleIds'] ?? userData['roles'];
    if (raw is Iterable) {
      for (final entry in raw) {
        addRole(entry);
      }
    } else {
      addRole(raw);
    }
    return roleIds;
  }
  String? _leadingText(Map<String, dynamic> ac) {
    if (ac.isEmpty) return null;
    return ac.length == 1
        ? _initials(ac.values.first['name'] ?? '')
        : '${ac.length}';
  }
  /// Leading icon chosen only by timelineCategory
  IconData _leadingIcon(Map<String, dynamic> data) {
    switch (data['timelineCategory'] as String?) {
      case 'Rpl9Mn34gJBdZ007jXpo':
        return Icons.add_box_outlined;
      case 'kG9DMLORk88VrZIGD7x3':
        return Icons.view_timeline_outlined;
      case 'ZOQH1ojP4a6QgRKCFTr8':
        return Icons.assignment_add;
      default:
        return Icons.view_timeline_outlined;
    }
  }
  List<String> _taskParticipantMemberIds({
    required Map<String, dynamic> activeContributors,
    required Map<String, dynamic> contributors,
    required String currentMemberId,
  }) {
    final ids = <String>{
      ...contributors.keys,
      ...activeContributors.keys,
    };
    ids.remove(currentMemberId);
    ids.removeWhere((id) => id.trim().isEmpty);
    return ids.toList();
  }
  bool _canStartTaskCall(BuildContext context) {
    final controller = VideoCallOverlayController.instance;
    if (controller.session != null || controller.incomingCall != null) {
      SnackbarService.instance.showSnackBar(
        const SnackBar(
          duration: Duration(seconds: 5),
          content: Text('Finish the current call before starting a new one.'),
        ),
      );
      return false;
    }
    return true;
  }
  void _startTaskVoiceCall({
    required BuildContext context,
    required String companyId,
    required DocumentReference<Map<String, dynamic>> timelineRef,
    required Map<String, dynamic> activeContributors,
    required Map<String, dynamic> contributors,
    required String currentMemberId,
    String? taskLabel,
    required String sourceContext,
  }) {
    if (!_canStartTaskCall(context)) return;
    final participantMemberIds = _taskParticipantMemberIds(
      activeContributors: activeContributors,
      contributors: contributors,
      currentMemberId: currentMemberId,
    );
    if (participantMemberIds.isEmpty) {
      SnackbarService.instance.showSnackBar(
        const SnackBar(
          duration: Duration(seconds: 5),
          content: Text('No task contributors available for voice call.'),
        ),
      );
      return;
    }
    final subject = taskLabel != null && taskLabel.trim().isNotEmpty
        ? 'Voice: ${taskLabel.trim()}'
        : 'Voice call';
    VideoCallService.instance.startTaskCall(
      companyId: companyId,
      currentMemberId: currentMemberId,
      taskId: timelineRef.id,
      subject: subject,
      participantMemberIds: participantMemberIds,
      callType: VideoCallType.voice,
      source: 'tasks',
      sourceContext: sourceContext,
    );
  }
  void _startTaskVideoConference({
    required BuildContext context,
    required DocumentReference<Map<String, dynamic>> timelineRef,
    required Map<String, dynamic> activeContributors,
    required Map<String, dynamic> contributors,
    required String companyId,
    required String currentMemberId,
    String? taskLabel,
    required String sourceContext,
  }) {
    if (!_canStartTaskCall(context)) return;
    final participantMemberIds = _taskParticipantMemberIds(
      activeContributors: activeContributors,
      contributors: contributors,
      currentMemberId: currentMemberId,
    );
    if (participantMemberIds.isEmpty) {
      SnackbarService.instance.showSnackBar(
        const SnackBar(
          duration: Duration(seconds: 5),
          content: Text('No task contributors available for video call.'),
        ),
      );
      return;
    }
    VideoCallService.instance.startTaskCall(
      companyId: companyId,
      currentMemberId: currentMemberId,
      taskId: timelineRef.id,
      subject: taskLabel,
      participantMemberIds: participantMemberIds,
      source: 'tasks',
      sourceContext: sourceContext,
    );
  }
  /// Ordered `{memberId: name}` map of every task participant — former
  /// contributors first, then anyone currently active — with the current
  /// member and blank ids dropped. Active entries win on the name so a
  /// rejoined member keeps their latest label.
  Map<String, String> _taskParticipantNames({
    required Map<String, dynamic> activeContributors,
    required Map<String, dynamic> contributors,
    required String currentMemberId,
  }) {
    final names = <String, String>{};
    void absorb(Map<String, dynamic> source) {
      source.forEach((id, value) {
        if (id.trim().isEmpty || id == currentMemberId) return;
        final name = value is Map ? value['name'] as String? : null;
        names[id] = (name != null && name.trim().isNotEmpty)
            ? name.trim()
            : names[id] ?? 'Teammate';
      });
    }

    absorb(contributors);
    absorb(activeContributors);
    return names;
  }
  /// Opens a group text wired to every task contributor at once. Falls back
  /// to a 1:1 conversation when only one other person ever worked the task.
  Future<void> _startTaskText({
    required BuildContext context,
    required DocumentReference<Map<String, dynamic>> companyRef,
    required DocumentReference<Map<String, dynamic>> currentMemberRef,
    required String currentMemberName,
    required Map<String, dynamic> activeContributors,
    required Map<String, dynamic> contributors,
    String? taskLabel,
  }) async {
    final participants = _taskParticipantNames(
      activeContributors: activeContributors,
      contributors: contributors,
      currentMemberId: currentMemberRef.id,
    );
    if (participants.isEmpty) {
      SnackbarService.instance.showSnackBar(
        const SnackBar(
          duration: Duration(seconds: 5),
          content: Text('No task contributors available to message.'),
        ),
      );
      return;
    }

    final navigator = Navigator.of(context);
    final memberCollection = companyRef.collection('member');
    final service = TextingService(
      companyRef: companyRef,
      memberRef: currentMemberRef,
      memberName: currentMemberName,
    );

    try {
      final DocumentReference<Map<String, dynamic>> conversationRef;
      if (participants.length == 1) {
        final only = participants.entries.first;
        final conversation = await service.getOrCreateDirectConversation(
          otherMemberRef: memberCollection.doc(only.key),
          otherMemberName: only.value,
        );
        conversationRef = conversation.ref;
      } else {
        final names = participants.values.toList();
        final title = taskLabel != null && taskLabel.trim().isNotEmpty
            ? taskLabel.trim()
            : names.length <= 3
                ? names.join(', ')
                : '${names.take(2).join(', ')} +${names.length - 2}';
        final conversation = await service.createGroupConversation(
          title: title,
          participantRefs:
              participants.keys.map((id) => memberCollection.doc(id)).toList(),
          participantNames: names,
        );
        conversationRef = conversation.ref;
      }
      if (!mounted) return;
      navigator.push(
        MaterialPageRoute(
          builder: (_) => TextConversationDetailScreen(
            conversationRef: conversationRef,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      SnackbarService.instance.showSnackBar(
        SnackBar(duration: const Duration(seconds: 5), content: Text('Could not start conversation: $e')),
      );
    }
  }
  /// Opens the email composer pre-addressed to every task contributor. The
  /// recipients' primary (main) email is resolved off each member doc.
  Future<void> _startTaskEmail({
    required BuildContext context,
    required DocumentReference<Map<String, dynamic>> companyRef,
    required String currentMemberId,
    required Map<String, dynamic> activeContributors,
    required Map<String, dynamic> contributors,
    String? taskLabel,
  }) async {
    final ids = _taskParticipantMemberIds(
      activeContributors: activeContributors,
      contributors: contributors,
      currentMemberId: currentMemberId,
    );
    if (ids.isEmpty) {
      SnackbarService.instance.showSnackBar(
        const SnackBar(
          duration: Duration(seconds: 5),
          content: Text('No task contributors available to email.'),
        ),
      );
      return;
    }

    final memberCollection = companyRef.collection('member');

    try {
      final snaps = await Future.wait(
        ids.map((id) => memberCollection.doc(id).get()),
      );
      final emails = <String>{};
      for (final snap in snaps) {
        final data = snap.data();
        if (data == null) continue;
        final email = parseContactInfo(data).primaryEmail?.value;
        if (email != null && email.trim().isNotEmpty) {
          emails.add(email.trim());
        }
      }
      if (!mounted || !context.mounted) return;
      if (emails.isEmpty) {
        SnackbarService.instance.showSnackBar(
          const SnackBar(
            duration: Duration(seconds: 5),
            content:
                Text('No contributor email addresses on file for this task.'),
          ),
        );
        return;
      }
      final query = <String, String>{'to': emails.join(',')};
      if (taskLabel != null && taskLabel.trim().isNotEmpty) {
        query['subject'] = 'Task: ${taskLabel.trim()}';
      }
      context.push(
        Uri(
          path: AppRoutes.drawerEmailCompose,
          queryParameters: query,
        ).toString(),
      );
    } catch (e) {
      if (!mounted) return;
      SnackbarService.instance.showSnackBar(
        SnackBar(duration: const Duration(seconds: 5), content: Text('Could not open email: $e')),
      );
    }
  }
  // no-op placeholder kept for reference (no more expansion tray toggle)
  void _clearSearchAttachment() {
    setState(() {
      _searchAttachmentName = null;
      _searchAttachmentBytes = null;
      _searchAttachmentIsImage = false;
    });
  }
  Future<void> _attachSearchReferenceFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(withData: true);
      if (result == null || result.files.isEmpty) {
        return;
      }
      final file = result.files.first;
      Uint8List? bytes = file.bytes;
      if (bytes == null && file.path != null && !kIsWeb) {
        final pickedFile = XFile(file.path!);
        bytes = await pickedFile.readAsBytes();
      }
      if (!mounted) {
        return;
      }
      if (bytes == null) {
        SnackbarService.instance.showSnackBar(
          const SnackBar(duration: Duration(seconds: 5), content: Text('Unable to read selected file.')),
        );
        return;
      }
      final extension = (file.extension ?? '').toLowerCase();
      const imageExtensions = <String>{
        'jpg',
        'jpeg',
        'png',
        'gif',
        'bmp',
        'webp',
        'heic',
        'heif',
      };
      setState(() {
        _searchAttachmentName = file.name;
        _searchAttachmentBytes = bytes;
        _searchAttachmentIsImage = imageExtensions.contains(extension);
      });
      SnackbarService.instance.showSnackBar(
        SnackBar(duration: const Duration(seconds: 5), content: Text('${file.name} attached to search input.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      SnackbarService.instance.showSnackBar(
        SnackBar(duration: const Duration(seconds: 5), content: Text('Unable to attach file: $error')),
      );
    }
  }
  Future<void> _captureSearchPhoto() async {
    try {
      final image = await _imagePicker.pickImage(source: ImageSource.camera);
      if (image == null) {
        return;
      }
      final bytes = await image.readAsBytes();
      if (!mounted) {
        return;
      }
      setState(() {
        _searchAttachmentName = image.name;
        _searchAttachmentBytes = bytes;
        _searchAttachmentIsImage = true;
      });
      SnackbarService.instance.showSnackBar(
        const SnackBar(duration: Duration(seconds: 5), content: Text('Photo attached to search input.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      SnackbarService.instance.showSnackBar(
        SnackBar(duration: const Duration(seconds: 5), content: Text('Unable to capture photo: $error')),
      );
    }
  }
  Widget _buildSearchAttachmentPreview(BuildContext context) {
    final name = _searchAttachmentName;
    if (name == null) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    if (_searchAttachmentIsImage && _searchAttachmentBytes != null) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.dividerColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    name,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  tooltip: 'Remove attachment',
                  icon: const Icon(Icons.close),
                  onPressed: _clearSearchAttachment,
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.memory(
                _searchAttachmentBytes!,
                height: 140,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
          ],
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Row(
        children: [
          const Icon(Icons.insert_drive_file_outlined),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              name,
              style: theme.textTheme.bodyMedium,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            tooltip: 'Remove attachment',
            icon: const Icon(Icons.close),
            onPressed: _clearSearchAttachment,
          ),
        ],
      ),
    );
  }
  TaskDataSnapshot _ensureTaskDataSnapshot(
    TaskTimelineSnapshot timeline,
    Set<String> activeTrainingIdSet,
    Set<String> roleIdSet,
    String memberId,
  ) {
    final cached = _taskDataSnapshot;
    if (cached != null &&
        cached.revision == timeline.revision &&
        setEquals(cached.activeTrainingIdSet, activeTrainingIdSet) &&
        setEquals(cached.roleIdSet, roleIdSet) &&
        cached.memberId == memberId) {
      return cached;
    }
    final snapshot = TaskDataSnapshot.build(
      timeline: timeline,
      activeTrainingIdSet: activeTrainingIdSet,
      roleIdSet: roleIdSet,
      memberId: memberId,
    );
    _taskDataSnapshot = snapshot;
    return snapshot;
  }
  int _beginSwipeSnackBar(BuildContext context) {
    _swipeSnackBarEpoch += 1;
    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
    }
    return _swipeSnackBarEpoch;
  }
  void _showSwipeSnackBar(
    BuildContext context,
    SnackBar snackBar,
    int token,
  ) {
    if (!mounted || token != _swipeSnackBarEpoch) return;
    SnackbarService.instance.showSnackBar(snackBar);
  }
  Future<void> _clearOverrideFilter({bool force = false}) async {
    if (!force && !_lastOverrideFilter) return;
    final memberRef = _overrideMemberRef;
    if (memberRef == null) return;
    final updates = <String, Object?>{'overrideActionFilter': false};
    final writes = <Future<void>>[
      memberRef.update(updates).catchError((_) {/* ignore member errors */}),
    ];
    await Future.wait(writes);
    _lastOverrideFilter = false;
  }
  void _scheduleOverrideReset({bool force = false}) {
    if (_overrideResetInFlight) return;
    if (!force && !_lastOverrideFilter) return;
    _overrideResetInFlight = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _overrideResetInFlight = false;
      await _clearOverrideFilter(force: force);
    });
  }
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The mixin handles `resumed` by triggering a rebuild + invoking
    // `onTimeBoundaryReached` (which refreshes the controller anchor).
    // Non-resume transitions still need to clear the action override.
    if (state != AppLifecycleState.resumed) {
      unawaited(_clearOverrideFilter());
    }
    super.didChangeAppLifecycleState(state);
  }

  /// Called by the mixin on each scheduled boundary tick (and on app
  /// resume). Refresh the hour-aligned anchor so the Firestore query
  /// window slides forward when needed.
  @override
  void onTimeBoundaryReached() {
    if (!mounted) return;
    ref.read(taskListControllerProvider.notifier).refreshAnchor();
  }

  /* ───────── lifecycle ───────── */
  @override
  void initState() {
    super.initState();
    // Mixin handles WidgetsBindingObserver registration + 5-min safety
    // net timer. We just need an initial anchor refresh.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(taskListControllerProvider.notifier).refreshAnchor();
    });
  }

  @override
  void dispose() {
    unawaited(_clearOverrideFilter(force: true));
    _taskDataSnapshot = null;
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }
  /* ───────── build ───────── */
  @override
  Widget build(BuildContext context) {
    super.build(context);
    ref.listen<bool>(
      taskListControllerProvider.select((s) => s.searchBarVisible),
      (prev, next) {
        if (next) {
          FocusScope.of(context).requestFocus(_searchFocus);
        } else {
          _searchFocus.unfocus();
          _searchCtrl.clear();
        }
      },
    );
    return ref.watch(userDocumentProvider).when(
          loading: () => const Center(child: CircularProgressIndicator()),
          // Friendly prompt instead of raw error
          error: (e, _) =>
              const Center(child: Text('Please sign-in to view tasks')),
          data: (userData) {
            final userRoleIds = _roleIdsFromUser(userData);
            final windowAnchor = ref.watch(
              taskListControllerProvider.select((state) => state.windowAnchor),
            );
            // Subscribe to the controller's refresh tick so the screen
            // rebuilds (and the filter re-evaluates against current time)
            // on every refreshAnchor call, not just when the hour rolls.
            // Catches blackout-window endings inside the current hour.
            ref.watch(
              taskListControllerProvider.select((state) => state.refreshTick),
            );
            final searchLower = ref.watch(
              taskListControllerProvider.select((state) => state.searchLower),
            );
            final showSearchBar = ref.watch(
              taskListControllerProvider.select((state) => state.searchBarVisible),
            );
            final trainingWarningAcknowledged = ref.watch(
              taskListControllerProvider.select((state) => state.trainingWarningAcknowledged),
            );
            final tabIndex = ref.watch(tasksTabIndexProvider);
            final memberRef = userData['memberRef']
                as DocumentReference<Map<String, dynamic>>?;
            if (memberRef == null) {
              return const Center(child: Text('Member profile not found.'));
            }
            final uid = memberRef.id;
            _overrideMemberRef = memberRef;
            _lastOverrideFilter = userData['overrideActionFilter'] == true;
            if (tabIndex == 0) {
              if (!_wasOnTasksTab) {
                _wasOnTasksTab = true;
                _scheduleOverrideReset();
              }
            } else if (_wasOnTasksTab) {
              _wasOnTasksTab = false;
              _scheduleOverrideReset();
            }
            final lb = windowAnchor
                .subtract(Duration(hours: userData['rearWindow'] ?? 12));
            final ub = windowAnchor
                .add(Duration(hours: userData['frontWindow'] ?? 12));
            /* ── user prefs ── */
            final showBlackouts = userData['showBlackouts'] == true;
            final showSkipped = userData['showSkipped'] == true;
            final showCompleted = userData['showCompleted'] == true;
            final showPriority = userData['showPriority'] == true;
            final showFlagged = userData['showFlagged'] == true;
            final showDependents = userData['showDependents'] != false;
            final disablePacing = userData['disablePacing'] == true;
            final overrideFilter = userData['overrideActionFilter'] == true;
            // timeline-category flags (true if missing)
            final showCatAddBox = userData['showCatAddBox'] != false;
            final showCatTimeline = userData['showCatTimeline'] != false;
            final showCatAssignment = userData['showCatAssignment'] != false;
            final canSkip = userData['canSkip'] == true;
            final canComplete = userData['canComplete'] == true;
            final canAlertTask = userData['canAlertTask'] == true;
            final canFlag = userData['canFlag'] == true;
            final canQuality = userData['canQuality'] == true;
            final canRemoveContributor =
                userData['canRemoveContributor'] == true;
            final currentMemberName =
                (userData['name'] as String?) ?? 'Unknown';
            final teamAccess = _resolveTeamAccess(userData);
            final userCompanyRef =
                userData['companyId'] as DocumentReference<Map<String, dynamic>>?;
            DocumentReference<Map<String, dynamic>> typedRef(
              DocumentReference ref,
            ) =>
                ref.withConverter<Map<String, dynamic>>(
                  fromFirestore: (snap, _) =>
                      snap.data() ?? <String, dynamic>{},
                  toFirestore: (value, _) => value,
                );
            DocumentReference<Map<String, dynamic>>? typedTeamRef(Object? raw) {
              if (raw is DocumentReference) {
                return typedRef(raw);
              }
              if (raw is String && raw.isNotEmpty) {
                if (raw.contains('/')) {
                  return ref.read(taskRepositoryProvider).docFromPath(raw);
                }
                if (userCompanyRef != null) {
                  return userCompanyRef
                      .collection('team')
                      .doc(raw)
                      .withConverter<Map<String, dynamic>>(
                    fromFirestore: (snap, _) =>
                        snap.data() ?? <String, dynamic>{},
                    toFirestore: (value, _) => value,
                  );
                }
              }
              return null;
            }
            final seenTeamPaths = <String>{};
            final List<DocumentReference<Map<String, dynamic>>> teamRefs =
                teamAccess
                    .map(typedTeamRef)
                    .whereType<DocumentReference<Map<String, dynamic>>>()
                    .where((ref) => seenTeamPaths.add(ref.path))
                    .toList();
            final primaryTeamRef = typedTeamRef(userData['primaryTeamId']);
            final teamPaths = teamRefs
                .map((ref) => ref.path)
                .toSet()
                .toList()
              ..sort();
            // Gate: require clock-in (unless override)
            final bool isClockedIn = userData['clockedIn'] == true;
            final bool overrideClockIn = userData['overrideClockIn'] == true;
            if (!isClockedIn && !overrideClockIn) {
              return const Center(
                child: Text('Please clock-in under Timecard'),
              );
            }
            if (teamPaths.isEmpty) {
              return const Center(
                child: Text(
                  'Team access required.\nPlease ask your admin to add you to a team.',
                  textAlign: TextAlign.center,
                ),
              );
            }
            return ref.watch(companyIdProvider).when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('Company Error: $e')),
                  data: (companyRef) {
                    if (companyRef == null) {
                      return const Center(child: Text('No company assigned.'));
                    }
                    final cid = companyRef.id;
                    final settingsByTeamPath =
                        <String, TeamSettings>{};
                    Object? teamSettingsError;
                    var teamSettingsLoading = false;
                    for (final teamPath in teamPaths) {
                      final settingsAsync =
                          ref.watch(teamSettingsProvider(teamPath));
                      settingsAsync.when(
                        data: (settings) {
                          settingsByTeamPath[teamPath] = settings;
                        },
                        loading: () {
                          teamSettingsLoading = true;
                        },
                        error: (e, _) {
                          teamSettingsError ??= e;
                        },
                      );
                    }
                    if (teamSettingsLoading &&
                        settingsByTeamPath.length != teamPaths.length) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (teamSettingsError != null &&
                        settingsByTeamPath.isEmpty) {
                      return Center(
                        child: Text('Team settings error: $teamSettingsError'),
                      );
                    }
                    const fallbackTeamSettings = TeamSettings(
                      pacingEnabled: false,
                      pacingIntervalMinutes: 90,
                    );
                        /* ── categories filter ── */
                        final categoriesFilter = <String>[
                          if (showCatTimeline) 'kG9DMLORk88VrZIGD7x3',
                          if (showCatAddBox) 'Rpl9Mn34gJBdZ007jXpo',
                          if (showCatAssignment) 'ZOQH1ojP4a6QgRKCFTr8',
                        ];
                        if (categoriesFilter.isEmpty)
                          categoriesFilter.add('###NO_MATCH###');
                        /* ── Firestore query ── */
                        final timelineParams = TaskTimelineParams(
                          companyId: cid,
                          categoryIds: categoriesFilter,
                          teamPaths: teamPaths,
                          selectedTeamPath: null,
                          lowerBoundMillis: lb.millisecondsSinceEpoch,
                          upperBoundMillis: ub.millisecondsSinceEpoch,
                          personalMemberPath: memberRef.path,
                        );
                        final trainingParams = TaskTrainingParams(
                          companyPath: companyRef.path,
                          memberPath: memberRef.path,
                        );
                        return ref
                            .watch(tasksTrainingStatusProvider(trainingParams))
                            .when(
                          loading: () =>
                              const Center(child: CircularProgressIndicator()),
                          error: (e, _) =>
                              Center(child: Text('Training status error: $e')),
                          data: (trainingStatus) {
                            final activeTrainingIds =
                                trainingStatus.activeTrainingIds;
                            final lockout = trainingStatus.lockout;
                            final showWarnOverlay =
                                trainingStatus.showWarnOverlay;
                            final warnMessage = trainingStatus.warnMessage;
                                if (lockout) {
                                  return Container(
                                    color: Theme.of(context).canvasColor,
                                    padding: const EdgeInsets.all(16.0),
                                    alignment: Alignment.center,
                                    child: const Text(
                                      'Please complete required training before starting tasks.',
                                      textAlign: TextAlign.center,
                                    ),
                                  );
                                }
                                return Stack(
                                  children: [
                                    Container(
                                      color: Theme.of(context).canvasColor,
                                      child: NotificationListener<ScrollNotification>(
                                    onNotification: (n) {
                                      if (n is ScrollUpdateNotification &&
                                          n.scrollDelta != null) {
                                        ref
                                            .read(taskListControllerProvider
                                                .notifier)
                                            .setFabVisible(n.scrollDelta! < 0);
                                      }
                                      return false;
                                    },
                                    child: ref
                                        .watch(tasksTimelineProvider(timelineParams))
                                        .when(
                                      loading: () => const Center(
                                          child: CircularProgressIndicator()),
                                      error: (e, _) => Center(
                                          child: Text('Error: $e')),
                                      data: (timelineSnapshot) {
                                        final taskData =
                                          _ensureTaskDataSnapshot(
                                            timelineSnapshot,
                                            activeTrainingIds,
                                            userRoleIds,
                                            memberRef.id,
                                          );
                                        final eligible = taskData.eligible;
                                        final dataByDocId =
                                            taskData.dataByDocId;
                                        final evalNow = DateTime.now();
                                        // 2) use `eligible` instead of `docs` for collapse & pacing logic:
                                        final activeCache =
                                            <String, Map<String, dynamic>>{};
                                        Map<String, dynamic> activeForDoc(
                                                QueryDocumentSnapshot<
                                                        Map<String, dynamic>>
                                                    doc) =>
                                            activeCache.putIfAbsent(
                                              doc.id,
                                              () => _ac(
                                                dataByDocId[doc.id]
                                                        ?['activeContributors']
                                                    as Map?,
                                              ),
                                            );
                                        final contributorsCache =
                                            <String, Map<String, dynamic>>{};
                                        Map<String, dynamic> contributorsForDoc(
                                                QueryDocumentSnapshot<
                                                        Map<String, dynamic>>
                                                    doc) =>
                                            contributorsCache.putIfAbsent(
                                              doc.id,
                                              () => _ac(
                                                dataByDocId[doc.id]
                                                    ?['contributors'] as Map?,
                                              ),
                                            );
                                        final noteCache = <String, bool>{};
                                        bool hasNoteForDoc(
                                                QueryDocumentSnapshot<
                                                        Map<String, dynamic>>
                                                    doc) =>
                                            noteCache.putIfAbsent(
                                              doc.id,
                                              () => _ac(
                                                dataByDocId[doc.id]?['taskNote']
                                                    as Map?,
                                              ).isNotEmpty,
                                            );
                                        final priorityCache = <String, bool>{};
                                        bool priorityForDoc(
                                                QueryDocumentSnapshot<
                                                        Map<String, dynamic>>
                                                    doc) =>
                                            priorityCache.putIfAbsent(
                                              doc.id,
                                              () => isPriorityActive(
                                                  dataByDocId[doc.id]!,
                                                  evalNow),
                                            );
                                        final blackoutCache = <String, bool>{};
                                        bool blackoutForDoc(
                                                QueryDocumentSnapshot<
                                                        Map<String, dynamic>>
                                                    doc) =>
                                            blackoutCache.putIfAbsent(
                                              doc.id,
                                              () => isInBlackout(
                                                  dataByDocId[doc.id]!,
                                                  evalNow),
                                            );
                                        final skipCache = <String, bool>{};
                                        bool skipForDoc(
                                                QueryDocumentSnapshot<
                                                        Map<String, dynamic>>
                                                    doc) =>
                                            skipCache.putIfAbsent(
                                              doc.id,
                                              () => isSkipActive(
                                                  dataByDocId[doc.id]!,
                                                  evalNow),
                                            );
                                        final doneCache = <String, bool>{};
                                        bool doneForDoc(
                                                QueryDocumentSnapshot<
                                                        Map<String, dynamic>>
                                                    doc) =>
                                            doneCache.putIfAbsent(
                                              doc.id,
                                              () =>
                                                  dataByDocId[doc.id]
                                                      ?['completeTimestamp'] !=
                                                  null,
                                            );
                                        final timerCache = <String, bool>{};
                                        bool hasActiveTimerForDoc(
                                                QueryDocumentSnapshot<
                                                        Map<String, dynamic>>
                                                    doc) =>
                                            timerCache.putIfAbsent(
                                              doc.id,
                                              () => TaskTimerDialog.isActive(
                                                dataByDocId[doc.id],
                                                evalNow,
                                              ),
                                            );
                                        final expiredTimerCache =
                                            <String, bool>{};
                                        bool hasExpiredTimerForDoc(
                                                QueryDocumentSnapshot<
                                                        Map<String, dynamic>>
                                                    doc) =>
                                            expiredTimerCache.putIfAbsent(
                                              doc.id,
                                              () => TaskTimerDialog.isExpired(
                                                dataByDocId[doc.id],
                                                evalNow,
                                              ),
                                            );
                                        final startCache = <String, DateTime>{};
                                        DateTime startForDoc(
                                                QueryDocumentSnapshot<
                                                        Map<String, dynamic>>
                                                    doc) =>
                                            startCache.putIfAbsent(
                                              doc.id,
                                              () => (dataByDocId[doc.id]
                                                          ?['startTime']
                                                      as Timestamp)
                                                  .toDate(),
                                            );
                                        final teamPathCache =
                                            <String, String?>{};
                                        String? teamPathForDoc(
                                                QueryDocumentSnapshot<
                                                        Map<String, dynamic>>
                                                    doc) =>
                                            teamPathCache.putIfAbsent(
                                              doc.id,
                                              () => (dataByDocId[doc.id]
                                                          ?['teamId']
                                                      as DocumentReference?)
                                                  ?.path,
                                            );

                                        final docsByTeamPath =
                                            <String, List<QueryDocumentSnapshot<Map<String, dynamic>>>>{};
                                        for (final doc in eligible) {
                                          final teamPath =
                                              teamPathForDoc(doc);
                                          if (teamPath == null) continue;
                                          docsByTeamPath
                                              .putIfAbsent(
                                                teamPath,
                                                () => <QueryDocumentSnapshot<Map<String, dynamic>>>[],
                                              )
                                              .add(doc);
                                        }

                                        // Project every entry's startTime onto viewDay so a
                                        // multi-day / "scheduled until complete" task that
                                        // started on a previous calendar date but is still
                                        // valid today shows up at today's same-time-of-day.
                                        // This matches the UI's time-of-day grouping in
                                        // TaskListView (timeKeyForDoc uses hour*60+minute) and
                                        // prevents the anchor from being dragged back to
                                        // whatever date the carryover task originated on.
                                        //
                                        // Anchor is computed PER TEAM (not globally). A user
                                        // on multiple teams should get an independent wave per
                                        // team — a quiet team's earliest open task must not
                                        // drag a busy team's pacing window. The earlier global
                                        // hoist caused exactly that: an 11-task 5 AM block in
                                        // a secondary team pulled the primary team's anchor
                                        // back from its own 8 AM, leaving only active-
                                        // contributor tasks visible.
                                        final viewDay = DateTime(
                                          windowAnchor.year,
                                          windowAnchor.month,
                                          windowAnchor.day,
                                        );

                                        final filteredById =
                                            <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
                                        var collapse = false;

                                        for (final teamPath in teamPaths) {
                                          final teamDocs =
                                              docsByTeamPath[teamPath];
                                          if (teamDocs == null ||
                                              teamDocs.isEmpty) {
                                            continue;
                                          }
                                          final teamSettings =
                                              settingsByTeamPath[teamPath] ??
                                                  fallbackTeamSettings;
                                          final filterResult =
                                              filterTaskDocs(
                                            eligibleDocs: teamDocs,
                                            dataByDocId: dataByDocId,
                                            memberRef: memberRef,
                                            now: evalNow,
                                            showFlagged: showFlagged,
                                            showCompleted: showCompleted,
                                            showBlackouts: showBlackouts,
                                            showSkipped: showSkipped,
                                            showPriority: showPriority,
                                            showDependents: showDependents,
                                            pacingEnabled:
                                                teamSettings.pacingEnabled,
                                            disablePacing: disablePacing,
                                            paceMinutes: teamSettings
                                                .pacingIntervalMinutes,
                                            searchLower: searchLower,
                                            viewDay: viewDay,
                                          );

                                          final debug = filterResult.debug;
                                          if (kDebugMode && debug != null) {
                                            debugPrint(
                                              '[TasksFilter][$teamPath] pacingEnabled=${teamSettings.pacingEnabled} '
                                              'disablePacing=$disablePacing paceMin=${teamSettings.pacingIntervalMinutes} '
                                              'collapse=${debug.collapseActive} eligible=${debug.totalEntries} '
                                              'filtered=${debug.filteredCount} withinPace=${debug.withinPaceCount} '
                                              'earliestOpen=${debug.earliestOpen?.toIso8601String() ?? 'null'} '
                                              'active=${debug.hasActiveContributorCount} done=${debug.doneCount} '
                                              'skip=${debug.skippedCount} blackout=${debug.blackoutCount} '
                                              'lockedOut=${debug.lockedOutCount}',
                                            );
                                          }

                                          collapse = collapse ||
                                              filterResult.collapse;
                                          for (final doc
                                              in filterResult.filteredDocs) {
                                            filteredById[doc.id] = doc;
                                          }
                                        }

                                        final filtered = filteredById.values
                                            .toList(growable: false)
                                          ..sort((a, b) {
                                            final aStart = startForDoc(a);
                                            final bStart = startForDoc(b);
                                            final cmp =
                                                aStart.compareTo(bStart);
                                            if (cmp != 0) return cmp;
                                            return a.id.compareTo(b.id);
                                          });
                                        // Schedule a precise rebuild at the next
                                        // time-based boundary on screen (blackout
                                        // end, priority delay completion, etc.).
                                        // Also include next-hour so the hour-aligned
                                        // window anchor rolls. All teammates with
                                        // synced clocks flip state together.
                                        final upcoming = earliestUpcomingBoundary(
                                          datas: eligible
                                              .map((d) => dataByDocId[d.id])
                                              .whereType<
                                                  Map<String, dynamic>>(),
                                          now: evalNow,
                                        );
                                        final nextHour = nextHourAfter(evalNow);
                                        final earliest = upcoming == null ||
                                                nextHour.isBefore(upcoming)
                                            ? nextHour
                                            : upcoming;
                                        scheduleRebuildAt(earliest);
                                        final listBottomPadding = 16.0 + 88.0;
                                        final taskList = TaskListView(
                                          // Rollups should respect per-user eligibility/
                                          // authorization, not the raw timeline set.
                                          allDocs: eligible,
                                          filteredDocs: filtered,
                                          collapse: collapse,
                                          startForDoc: startForDoc,
                                          indentGroupedItems: false,
                                          teamRefs: teamRefs,
                                          companyRef: companyRef,
                                          primaryTeamRef: primaryTeamRef,
                                          padding: EdgeInsets.only(
                                            bottom: listBottomPadding,
                                          ),
                                          onSwipeLeft: canSkip
                                              ? (doc) async {
                                                  final snackToken =
                                                      _beginSwipeSnackBar(
                                                          context);
                                                  bool? newSkip;
                                                  bool blocked = false;
                                                  // Skip is a time-boxed snooze:
                                                  // it auto-expires kSkipDuration
                                                  // from now so the task returns
                                                  // on its own. Manual un-skip
                                                  // (swiping an already-skipped
                                                  // task) clears it immediately.
                                                  final skipUntilTs =
                                                      Timestamp.fromDate(
                                                          DateTime.now()
                                                              .add(kSkipDuration));
                                                  await FirebaseFirestore
                                                      .instance
                                                      .runTransaction(
                                                    (txn) async {
                                                      final curr =
                                                          (await txn.get(doc
                                                                  .reference))
                                                              .data()!;
                                                      final currSkip =
                                                          isSkipActive(curr,
                                                              DateTime.now());
                                                      final activeRaw =
                                                          curr['activeContributors'];
                                                      final active =
                                                          activeRaw is Map
                                                              ? Map<String,
                                                                      dynamic>.from(
                                                                  activeRaw)
                                                              : <String,
                                                                  dynamic>{};
                                                      if (!currSkip &&
                                                          active.isNotEmpty) {
                                                        blocked = true;
                                                        return;
                                                      }
                                                      newSkip = !currSkip;
                                                      txn.update(
                                                        doc.reference,
                                                        newSkip == true
                                                            ? {
                                                                'skipUntil':
                                                                    skipUntilTs,
                                                                'skip': true,
                                                              }
                                                            : {
                                                                'skipUntil':
                                                                    FieldValue
                                                                        .delete(),
                                                                'skip': FieldValue
                                                                    .delete(),
                                                              },
                                                      );
                                                    },
                                                  );
                                                  if (blocked) {
                                                    _showSwipeSnackBar(
                                                      context,
                                                      const SnackBar(
                                                        content: Text(
                                                          'Task has active contributors and cannot be skipped.',
                                                        ),
                                                        duration: Duration(seconds: 5),
                                                      ),
                                                      snackToken,
                                                    );
                                                    return;
                                                  }
                                                  if (newSkip == null) {
                                                    return;
                                                  }
                                                  final message =
                                                      newSkip == true
                                                          ? 'Task skipped'
                                                          : 'Skip removed';
                                                  _showSwipeSnackBar(
                                                    context,
                                                    SnackBar(
                                                      content: Text(message),
                                                      duration: const Duration(seconds: 5),
                                                    ),
                                                    snackToken,
                                                  );
                                                }
                                              : null,
                                          onSwipeRight: canComplete
                                              ? (doc) async {
                                                  final snackToken =
                                                      _beginSwipeSnackBar(
                                                          context);
                                                  // 1) Grab the previous values so UNDO can restore them if needed
                                                  final prevSnap =
                                                      await doc.reference.get();
                                                  final prevData =
                                                      prevSnap.data()!;
                                                  final Timestamp? previousTs =
                                                      prevData[
                                                              'completeTimestamp']
                                                          as Timestamp?;
                                                  final num? previousActual =
                                                      prevData['actualDuration']
                                                          as num?;
                                                  final bool wasComplete =
                                                      previousTs != null;
                                                  bool requireObjectChecks =
                                                      prevData[
                                                              'completeObjectTask'] ==
                                                          true;
                                                  // Read current “duration” (used below when marking complete)
                                                  final num currentDuration =
                                                      (prevData['duration']
                                                              as num?) ??
                                                          0;
                                                  // Also read out whatever activeContributors exist right now:
                                                  final Map<String, dynamic>?
                                                      rawAc =
                                                      (prevData['activeContributors']
                                                              as Map?)
                                                          ?.cast<String,
                                                              dynamic>();
                                                  final List<String>
                                                      contributorIds =
                                                      rawAc?.keys.toList() ??
                                                          <String>[];
                                                  bool clearedActiveTasks =
                                                      false;
                                                  if (!requireObjectChecks) {
                                                    final taskRef =
                                                        prevData['taskId'];
                                                    if (taskRef
                                                        is DocumentReference) {
                                                      final taskSnap =
                                                          await taskRef.get();
                                                      if (taskSnap.exists) {
                                                        final taskData =
                                                            taskSnap.data()
                                                                as Map<String,
                                                                    dynamic>?;
                                                        if (taskData?[
                                                                'completeObjectTask'] ==
                                                            true) {
                                                          requireObjectChecks =
                                                              true;
                                                          await doc.reference
                                                              .update({
                                                            'completeObjectTask':
                                                                true,
                                                          });
                                                        }
                                                      }
                                                    }
                                                  }
                                                  if (!wasComplete &&
                                                      requireObjectChecks) {
                                                    final taskRef =
                                                        prevData['taskId'];
                                                    final Map<String, dynamic>
                                                        objectTaskChecks =
                                                        (prevData[
                                                                    'objectTaskChecks']
                                                                as Map?)
                                                            ?.cast<String,
                                                                dynamic>() ??
                                                            <String, dynamic>{};
                                                    if (taskRef
                                                        is DocumentReference) {
                                                      final objectTasksSnap =
                                                          await companyRef
                                                              .collection(
                                                                  'objectProcessTask')
                                                              .where('taskId',
                                                                  isEqualTo:
                                                                      taskRef)
                                                              .get();
                                                      final requiredIds =
                                                          objectTasksSnap.docs
                                                              .map((doc) =>
                                                                  doc.id)
                                                              .toList(
                                                                  growable:
                                                                      false);
                                                      final allChecked =
                                                          requiredIds.isEmpty ||
                                                              requiredIds.every(
                                                                (id) =>
                                                                    objectTaskChecks[
                                                                        id] ==
                                                                    true,
                                                              );
                                                      if (!allChecked) {
                                                        _showSwipeSnackBar(
                                                          context,
                                                          const SnackBar(
                                                            content: Text(
                                                              'For this task, you have to check off each individual task before it can be marked as complete.',
                                                            ),
                                                            duration: Duration(seconds: 5),
                                                          ),
                                                          snackToken,
                                                        );
                                                        return;
                                                      }
                                                    }
                                                  }
                                                  // 2) Pre-resolve each active contributor's memberRef and compute
                                                  //    their elapsed duration. We do this BEFORE the transaction
                                                  //    because the memberByUid fallback requires arbitrary reads.
                                                  final DateTime nowDt =
                                                      DateTime.now();
                                                  final Timestamp endTs =
                                                      Timestamp.fromDate(nowDt);
                                                  final Map<String,
                                                          _SwipeCloseout>
                                                      closeouts = {};
                                                  if (!wasComplete &&
                                                      rawAc != null &&
                                                      rawAc.isNotEmpty) {
                                                    for (final entry
                                                        in rawAc.entries) {
                                                      final ac = entry.value;
                                                      if (ac is! Map) continue;
                                                      final acMap = Map<String,
                                                          dynamic>.from(ac);
                                                      final startTs =
                                                          acMap['startTime']
                                                              as Timestamp?;
                                                      if (startTs == null) {
                                                        continue;
                                                      }
                                                      final elapsedMs = nowDt
                                                          .difference(startTs
                                                              .toDate())
                                                          .inMilliseconds;
                                                      final int durationMinutes =
                                                          elapsedMs <= 0
                                                              ? 1
                                                              : (elapsedMs /
                                                                      60000)
                                                                  .ceil();
                                                      DocumentReference<
                                                              Map<String,
                                                                  dynamic>>?
                                                          resolvedRef;
                                                      final acMemberId =
                                                          acMap['memberId'];
                                                      if (acMemberId
                                                          is DocumentReference) {
                                                        resolvedRef = acMemberId
                                                            .withConverter<
                                                                Map<String,
                                                                    dynamic>>(
                                                          fromFirestore: (s, _) =>
                                                              s.data() ??
                                                              <String,
                                                                  dynamic>{},
                                                          toFirestore: (v, _) => v,
                                                        );
                                                      } else {
                                                        final directRef =
                                                            companyRef
                                                                .collection(
                                                                    'member')
                                                                .doc(entry.key);
                                                        final directSnap =
                                                            await directRef
                                                                .get();
                                                        if (directSnap.exists) {
                                                          resolvedRef =
                                                              directRef;
                                                        } else {
                                                          final indexSnap =
                                                              await companyRef
                                                                  .collection(
                                                                      'memberByUid')
                                                                  .doc(entry
                                                                      .key)
                                                                  .get();
                                                          final mid =
                                                              indexSnap.data()?[
                                                                      'memberId']
                                                                  as String?;
                                                          if (mid != null &&
                                                              mid.trim()
                                                                  .isNotEmpty) {
                                                            resolvedRef = companyRef
                                                                .collection(
                                                                    'member')
                                                                .doc(mid.trim());
                                                          }
                                                        }
                                                      }
                                                      closeouts[entry.key] =
                                                          _SwipeCloseout(
                                                        memberDocRef:
                                                            resolvedRef,
                                                        memberName: (acMap[
                                                                    'name']
                                                                as String?) ??
                                                            '',
                                                        startTs: startTs,
                                                        durationMinutes:
                                                            durationMinutes,
                                                        geoIn: acMap['geoIn'],
                                                      );
                                                    }
                                                  }

                                                  // 3) In a single transaction, do everything at once:
                                                  final taskRepo = ref.read(
                                                      taskRepositoryProvider);
                                                  await FirebaseFirestore
                                                      .instance
                                                      .runTransaction(
                                                          (txn) async {
                                                    // Re‐fetch inside TXN for concurrency safety
                                                    final freshSnap = await txn
                                                        .get(doc.reference);
                                                    final freshData =
                                                        freshSnap.data()!;
                                                    final bool isDone = freshData[
                                                            'completeTimestamp'] !=
                                                        null;
                                                    if (isDone) {
                                                      // UNDO path: remove completeTimestamp, actualDuration, forcedComplete, forcedCompleteBy
                                                      txn.update(
                                                          doc.reference, {
                                                        'completeTimestamp':
                                                            FieldValue.delete(),
                                                        'actualDuration':
                                                            FieldValue.delete(),
                                                        'forcedComplete':
                                                            FieldValue.delete(),
                                                        'forcedCompleteBy':
                                                            FieldValue.delete(),
                                                        // (we leave `activeContributors` alone on UNDO, since they were only
                                                        //  cleared when originally marking complete)
                                                      });
                                                      return;
                                                    }

                                                    // Read the parent task doc for the `name` field on the punch-out
                                                    // timeline entries. All reads must happen before any writes.
                                                    final taskIdField =
                                                        freshData['taskId'];
                                                    DocumentReference<
                                                            Map<String,
                                                                dynamic>>?
                                                        existingTaskRef;
                                                    if (taskIdField
                                                        is DocumentReference) {
                                                      existingTaskRef = taskIdField
                                                          .withConverter<
                                                              Map<String,
                                                                  dynamic>>(
                                                        fromFirestore: (s, _) =>
                                                            s.data() ??
                                                            <String, dynamic>{},
                                                        toFirestore: (v, _) =>
                                                            v,
                                                      );
                                                    }
                                                    String taskName = '';
                                                    if (existingTaskRef !=
                                                        null) {
                                                      final taskSnap = await txn
                                                          .get(existingTaskRef);
                                                      taskName = _firstString(
                                                          taskSnap
                                                              .data()?['name']);
                                                    }
                                                    final String taskTitle =
                                                        _firstString(freshData[
                                                            'title']);

                                                    // Merge contributors map: start with what's there, overlay each
                                                    // closeout entry so the active contributor moves to `contributors`.
                                                    final mergedContribs = Map<
                                                        String,
                                                        dynamic>.from((freshData[
                                                                'contributors']
                                                            as Map?) ??
                                                        const {});
                                                    for (final entry
                                                        in closeouts.entries) {
                                                      final close = entry.value;
                                                      final existing = Map<
                                                          String,
                                                          dynamic>.from((mergedContribs[
                                                                  entry.key]
                                                              as Map?) ??
                                                          const {});
                                                      existing['startTime'] ??=
                                                          close.startTs;
                                                      existing['endTime'] =
                                                          endTs;
                                                      existing['duration'] =
                                                          close.durationMinutes;
                                                      if (close.memberDocRef !=
                                                          null) {
                                                        existing['memberId'] =
                                                            close.memberDocRef;
                                                      }
                                                      if (close.memberName
                                                          .isNotEmpty) {
                                                        existing['name'] = close
                                                            .memberName;
                                                      }
                                                      if (close.geoIn != null) {
                                                        existing['geoIn'] =
                                                            close.geoIn;
                                                      }
                                                      mergedContribs[
                                                          entry.key] = existing;
                                                    }
                                                    int totalDuration = 0;
                                                    for (final v in
                                                        mergedContribs.values) {
                                                      if (v is Map) {
                                                        totalDuration += ((v['duration']
                                                                    as num?) ??
                                                                0)
                                                            .toInt();
                                                      }
                                                    }

                                                    // Write one punch-out timeline entry per active contributor so
                                                    // `handleSyncTaskLaborCost` credits their labor + contribution time.
                                                    for (final entry
                                                        in closeouts.entries) {
                                                      final close = entry.value;
                                                      if (close.memberDocRef ==
                                                          null) {
                                                        continue;
                                                      }
                                                      final newTimelineRef =
                                                          taskRepo
                                                              .newTimelineDoc(
                                                                  cid);
                                                      txn.set(newTimelineRef, {
                                                        'memberId':
                                                            close.memberDocRef,
                                                        'memberName':
                                                            close.memberName,
                                                        'name': taskName,
                                                        'title': taskTitle,
                                                        'startTime':
                                                            close.startTs,
                                                        'endTime': endTs,
                                                        'taskId':
                                                            existingTaskRef ??
                                                                doc.reference,
                                                        'timelineId':
                                                            doc.reference,
                                                        'duration': close
                                                            .durationMinutes,
                                                        'timelineCategory':
                                                            'E2HMUuMUUl4Alttuweba',
                                                        'timelineCategoryId':
                                                            taskRepo
                                                                .timelineCategoryDoc(
                                                                    'E2HMUuMUUl4Alttuweba'),
                                                        if (close.geoIn !=
                                                            null)
                                                          'geoIn': close.geoIn,
                                                      });
                                                    }

                                                    // Mark the task complete. When there were active contributors,
                                                    // overwrite `contributors` with the merged map and use the sum
                                                    // of their durations as `actualDuration` (matches click-out flow).
                                                    // When there were none, fall back to the planned duration; no
                                                    // one (including the swiper) gets credited.
                                                    final bool hasActive =
                                                        closeouts.isNotEmpty;
                                                    final taskUpdates =
                                                        <String, Object?>{
                                                      'completeTimestamp':
                                                          FieldValue
                                                              .serverTimestamp(),
                                                      'actualDuration': hasActive
                                                          ? totalDuration
                                                          : currentDuration,
                                                      'forcedComplete': true,
                                                      'forcedCompleteBy':
                                                          memberRef,
                                                      if (hasActive)
                                                        'contributors':
                                                            mergedContribs,
                                                      'activeContributors':
                                                          FieldValue.delete(),
                                                    };
                                                    txn.update(doc.reference,
                                                        taskUpdates);
                                                    // Mark contributors for cleanup outside the transaction
                                                    clearedActiveTasks = true;
                                                  });
                                                  if (clearedActiveTasks &&
                                                      contributorIds
                                                          .isNotEmpty) {
                                                    for (final memberId
                                                        in contributorIds) {
                                                      try {
                                                        DocumentReference<
                                                                Map<String,
                                                                    dynamic>>?
                                                            resolvedMemberRef;
                                                        final directRef =
                                                            companyRef
                                                                .collection(
                                                                    'member')
                                                                .doc(memberId);
                                                        final directSnap =
                                                            await directRef
                                                                .get();
                                                        if (directSnap
                                                            .exists) {
                                                          resolvedMemberRef =
                                                              directRef;
                                                        } else {
                                                          final indexSnap =
                                                              await companyRef
                                                                  .collection(
                                                                      'memberByUid')
                                                                  .doc(
                                                                      memberId)
                                                                  .get();
                                                          final resolvedId =
                                                              indexSnap.data()?[
                                                                  'memberId'] as String?;
                                                          if (resolvedId !=
                                                                  null &&
                                                              resolvedId
                                                                  .trim()
                                                                  .isNotEmpty) {
                                                            resolvedMemberRef =
                                                                companyRef
                                                                    .collection(
                                                                        'member')
                                                                    .doc(
                                                                        resolvedId
                                                                            .trim());
                                                          }
                                                        }
                                                        if (resolvedMemberRef !=
                                                            null) {
                                                          await resolvedMemberRef
                                                              .update({
                                                            'activeTaskId':
                                                                FieldValue
                                                                    .delete(),
                                                          });
                                                        }
                                                      } catch (_) {
                                                        // ignore cleanup errors per member
                                                      }
                                                    }
                                                  }
                                                  // 6) Show Snackbar with “UNDO” behavior
                                                  _showSwipeSnackBar(
                                                    context,
                                                    SnackBar(
                                                      content: const Text(
                                                          'Completion toggled'),
                                                      action: SnackBarAction(
                                                        label: 'UNDO',
                                                        onPressed: () async {
                                                          if (previousTs !=
                                                              null) {
                                                            // Restore previous completeTimestamp + actualDuration
                                                            final restoreData =
                                                                <String,
                                                                    Object?>{
                                                              'completeTimestamp':
                                                                  previousTs,
                                                              'actualDuration':
                                                                  previousActual ??
                                                                      FieldValue
                                                                          .delete(),
                                                              // Undo forced-complete fields as well
                                                              'forcedComplete':
                                                                  FieldValue
                                                                      .delete(),
                                                              'forcedCompleteBy':
                                                                  FieldValue
                                                                      .delete(),
                                                            };
                                                            await doc.reference
                                                                .update(
                                                                    restoreData);
                                                          } else {
                                                            // If it was never marked complete before, just clear those fields
                                                            await doc.reference
                                                                .update({
                                                              'completeTimestamp':
                                                                  FieldValue
                                                                      .delete(),
                                                              'actualDuration':
                                                                  FieldValue
                                                                      .delete(),
                                                              'forcedComplete':
                                                                  FieldValue
                                                                      .delete(),
                                                              'forcedCompleteBy':
                                                                  FieldValue
                                                                      .delete(),
                                                            });
                                                          }
                                                          // Note: we do NOT restore activeContributors or user.activeTaskId on UNDO;
                                                          // if you need that, you would have to cache them above and re‐write them here.
                                                        },
                                                      ),
                                                      duration: const Duration(seconds: 5),
                                                    ),
                                                    snackToken,
                                                  );
                                                }
                                              : null,
                                          leftSwipeBackground: Container(
                                            color: Colors.green,
                                            alignment: Alignment.centerLeft,
                                            padding:
                                                const EdgeInsets.only(left: 16),
                                            child: const Icon(Icons.check_box,
                                                color: Colors.white),
                                          ),
                                          rightSwipeBackground: Container(
                                            color: Colors.grey,
                                            alignment: Alignment.centerRight,
                                            padding: const EdgeInsets.only(
                                                right: 16),
                                            child: const Icon(
                                                Icons.skip_next_outlined,
                                                color: Colors.white),
                                          ),
                                          builder: (d) {
                                            final m = dataByDocId[d.id]!;
                                            final ac = activeForDoc(d);
                                            final hist = contributorsForDoc(d);
                                            final pr = priorityForDoc(d);
                                            final blk = blackoutForDoc(d);
                                            final skip = skipForDoc(d);
                                            final done = doneForDoc(d);
                                            final contrib = ac.isNotEmpty;
                                            final hasNote = hasNoteForDoc(d);
                                            final hasActiveTimer =
                                                hasActiveTimerForDoc(d);
                                            final hasExpiredTimer =
                                                hasExpiredTimerForDoc(d);
                                            final Color? timerBadgeColor =
                                                hasActiveTimer
                                                    ? Colors.red
                                                    : hasExpiredTimer
                                                        ? Colors.green
                                                        : null;
                                            final showVideoIcon =
                                                hist.isNotEmpty ||
                                                    ac.isNotEmpty ||
                                                    done;
                                            final rawName = m['name'];
                                            final rawTitle = m['title'];
                                            final String? taskLabel = rawName
                                                        is String &&
                                                    rawName.trim().isNotEmpty
                                                ? rawName.trim()
                                                : rawTitle is String &&
                                                        rawTitle
                                                            .trim()
                                                            .isNotEmpty
                                                    ? rawTitle.trim()
                                                    : null;
                                            final startDt = startForDoc(d);
                                            int? badge;
                                            if (m['endTimeExtended'] != null) {
                                              final days = evalNow
                                                  .difference(startDt)
                                                  .inDays;
                                              if (days > 0) badge = days;
                                            }
                                            final leadingText =
                                                _leadingText(ac);
                                            final leadingIconData =
                                                leadingText == null
                                                    ? _leadingIcon(m)
                                                    : null;
                                            bool grey() {
                                              if (contrib) return false;
                                              if (done) return true;
                                              if (overrideFilter) return false;
                                              if ((skip || blk) &&
                                                  !overrideFilter) return true;
                                              if (collapse &&
                                                  showPriority &&
                                                  !pr &&
                                                  !contrib) {
                                                return true;
                                              }
                                              return false;
                                            }
                                            final isGrey = grey();
                                            final txtColor = isGrey
                                                ? Colors.grey[500]
                                                : Colors.black;
                                            final palette =
                                                AppPaletteScope.of(context);
                                            final iconColor = isGrey
                                                ? Colors.grey[300]
                                                : pr
                                                    ? Colors.red
                                                    : palette.primary2;
                                            //
                                            // ────────────────────────────────────────────────────────────
                                            // Replace everything from this comment down to “TasksIconTextTile(…)”
                                            //
                                            // ── Hide or force‐show trailing icon based on overrideFilter, collapse, etc. ──
                                            //
                                            // First, compute whether we normally would “restrict” actions (hide the icon)
                                            // *but* we will bypass that restriction entirely if overrideFilter == true.
                                            //
                                            final bool restrictActions =
                                                // Only restrict when in a live priority collapse:
                                                collapse
                                                    // and this task is “open‐non‐priority” (no AC, not skipped, not blackout, not done, not itself priority)
                                                    &&
                                                    ac.isEmpty &&
                                                    !skip &&
                                                    !blk &&
                                                    !done &&
                                                    !pr &&
                                                    !overrideFilter; // if overrideFilter is true, restrictActions is always false
                                            IconData? trailingIcon1;
                                            VoidCallback? trailingAction1;
                                            if (restrictActions) {
                                              // In a “priority‐only” collapse, hide entirely:
                                              trailingIcon1 = null;
                                              trailingAction1 = null;
                                            } else if (overrideFilter &&
                                                !done &&
                                                ac.isEmpty) {
                                              // ── When overrideFilter == true, show a start checkbox for any non‐completed task:
                                              trailingIcon1 =
                                                  Icons.check_box_outline_blank;
                                              trailingAction1 = TrailingActions
                                                  .getTrailingAction1(
                                                doc: d,
                                                currentMemberId: uid,
                                                currentUserName:
                                                    userData['name'] ??
                                                        'Unknown',
                                                companyDocId: cid,
                                                allowOverrideJoin:
                                                    overrideFilter,
                                                context: context,
                                              );
                                            } else {
                                              // ── Default behavior when overrideFilter == false (or task is done):
                                              /// 1) Pick the visual icon first (it may later be hidden if unusable).
                                              if (done) {
                                                // Completed tasks always get the “checked” icon, no action
                                                trailingIcon1 =
                                                    Icons.check_box_outlined;
                                                trailingAction1 = null;
                                              } else if (ac.isNotEmpty) {
                                                // ANYTIME there are active contributors, show person/person_add AND make it tappable
                                                trailingIcon1 =
                                                    ac.containsKey(uid)
                                                        ? Icons.person
                                                        : Icons.person_add;
                                                // Because there’s someone working, we allow the same action you’d normally get:
                                                trailingAction1 =
                                                    TrailingActions
                                                        .getTrailingAction1(
                                                  doc: d,
                                                  currentMemberId: uid,
                                                currentUserName:
                                                    userData['name'] ??
                                                        'Unknown',
                                                companyDocId: cid,
                                                allowOverrideJoin:
                                                    overrideFilter,
                                                context: context,
                                              );
                                              } else if (!overrideFilter &&
                                                  skip) {
                                                // Skip‐flagged, no contributors ⇒ show skip icon, no tap action
                                                trailingIcon1 = Icons.skip_next;
                                                trailingAction1 = null;
                                              } else if (!overrideFilter &&
                                                  blk) {
                                                // Blackout, no contributors ⇒ show pause icon, no tap action
                                                trailingIcon1 =
                                                    Icons.pause_circle;
                                                trailingAction1 = null;
                                              } else {
                                                // No contributors, no skip/blko ⇒ blank checkbox, only tappable if overrideFilter == false
                                                trailingIcon1 = Icons
                                                    .check_box_outline_blank;
                                                trailingAction1 =
                                                    TrailingActions
                                                        .getTrailingAction1(
                                                  doc: d,
                                                  currentMemberId: uid,
                                                currentUserName:
                                                    userData['name'] ??
                                                        'Unknown',
                                                companyDocId: cid,
                                                allowOverrideJoin:
                                                    overrideFilter,
                                                context: context,
                                              );
                                              }
                                              /// 3) If it’s a blank checkbox with no action, remove it entirely.
                                              if (trailingIcon1 ==
                                                      Icons
                                                          .check_box_outline_blank &&
                                                  trailingAction1 == null) {
                                                trailingIcon1 = null;
                                              }
                                            }
                                            //
                                            // ────────────────────────────────────────────────────────────
                                            // End of replaced section. Now return the tile with the chosen icons/actions:
                                            //
                                            // rebuild the two alert-reference lists for this tile
                                            final onStartRefs = (m[
                                                            'alertOnStart']
                                                        as List?)
                                                    ?.cast<
                                                        DocumentReference>() ??
                                                const [];
                                            final onCompleteRefs = (m[
                                                            'alertWhenComplete']
                                                        as List?)
                                                    ?.cast<
                                                        DocumentReference>() ??
                                                const [];
                                            final flagBadge =
                                                onStartRefs.contains(memberRef) ||
                                                    onCompleteRefs
                                                        .contains(memberRef);
                                            final isIncomplete =
                                                m['completeTimestamp'] == null;
                                            return InkWell(
                                              onTap: () =>
                                                  Navigator.of(context).push(
                                                MaterialPageRoute(
                                                  builder: (_) =>
                                                      TasksTasksDetails(
                                                    companyId: cid,
                                                    docId: d.id,
                                                  ),
                                                ),
                                              ),
                                              child: TaskTile(
                                                leadingIcon: leadingIconData,
                                                twoDigitText: leadingText,
                                                leadingBadge:
                                                    leadingText == null &&
                                                            !contrib
                                                        ? badge
                                                        : null,
                                                leadingIconColor: iconColor,
                                                leadingIconAction: () =>
                                                    TaskDrawer.show(
                                                  context,
                                                  onHistoryTap: () =>
                                                      Navigator.of(context)
                                                          .push(
                                                    MaterialPageRoute(
                                                      builder: (_) =>
                                                          TaskDetailsTabs(
                                                        companyId: cid,
                                                        routineId: d.id,
                                                      ),
                                                    ),
                                                  ),
                                                  activeContributors: ac,
                                                  pastContributors: hist,
                                                  onNoteTap: hasNote
                                                      ? () => TaskTile
                                                              .showTaskNoteDialog(
                                                            context: context,
                                                            taskData: m,
                                                          )
                                                      : null,
                                                  onServiceRequestTap: () {
                                                    final locs = (m[
                                                                'locationId']
                                                            as List<dynamic>?)
                                                        ?.cast<
                                                            DocumentReference<
                                                                Map<String,
                                                                    dynamic>>>();
                                                    Navigator.of(context).push(
                                                      MaterialPageRoute(
                                                        builder: (_) =>
                                                            TasksReportsRequestForm(
                                                          timelineRef:
                                                              d.reference,
                                                          locationRefs: locs,
                                                        ),
                                                      ),
                                                    );
                                                  },
                                                  onVoiceAlertTap: (canAlertTask &&
                                                          ac.isEmpty &&
                                                          !done)
                                                      ? () => TaskTile
                                                              .showTaskAlertForm(
                                                            context: context,
                                                            timelineRef:
                                                                d.reference,
                                                          )
                                                      : null,
                                                onCommunicationTap:
                                                    showVideoIcon
                                                        ? () =>
                                                          _startTaskVoiceCall(
                                                              context:
                                                                  context,
                                                              companyId: cid,
                                                              timelineRef: d
                                                                  .reference,
                                                              activeContributors:
                                                                  ac,
                                                              contributors:
                                                                  hist,
                                                              currentMemberId:
                                                                  uid,
                                                              taskLabel:
                                                                  taskLabel,
                                                              sourceContext:
                                                                  'task_drawer',
                                                            )
                                                        : null,
                                                  onVideoConferenceTap:
                                                      showVideoIcon
                                                          ? () =>
                                                              _startTaskVideoConference(
                                                                context:
                                                                    context,
                                                                timelineRef: d
                                                                    .reference,
                                                                activeContributors:
                                                                    ac,
                                                                contributors:
                                                                    hist,
                                                                companyId: cid,
                                                                currentMemberId:
                                                                    uid,
                                                                taskLabel:
                                                                    taskLabel,
                                                                sourceContext:
                                                                    'task_drawer',
                                                              )
                                                          : null,
                                                  onTextTap: showVideoIcon
                                                      ? () => _startTaskText(
                                                            context: context,
                                                            companyRef:
                                                                companyRef,
                                                            currentMemberRef:
                                                                memberRef,
                                                            currentMemberName:
                                                                currentMemberName,
                                                            activeContributors:
                                                                ac,
                                                            contributors: hist,
                                                            taskLabel:
                                                                taskLabel,
                                                          )
                                                      : null,
                                                  onEmailTap: showVideoIcon
                                                      ? () => _startTaskEmail(
                                                            context: context,
                                                            companyRef:
                                                                companyRef,
                                                            currentMemberId:
                                                                uid,
                                                            activeContributors:
                                                                ac,
                                                            contributors: hist,
                                                            taskLabel:
                                                                taskLabel,
                                                          )
                                                      : null,
                                                  onAlertFlagTap: (canFlag &&
                                                          isIncomplete)
                                                      ? () => showDialog(
                                                            context: context,
                                                          builder: (_) =>
                                                              TaskAlertDialog(
                                                            timelineRef:
                                                                d.reference,
                                                            currentMemberRef:
                                                                memberRef,
                                                          ),
                                                        )
                                                      : null,
                                                  onQualityReportTap:
                                                      (canQuality && done)
                                                          ? () {
                                                              final locs = (m[
                                                                          'locationId']
                                                                      as List<
                                                                          dynamic>?)
                                                                  ?.cast<
                                                                      DocumentReference<
                                                                          Map<String,
                                                                              dynamic>>>();
                                                              Navigator.of(
                                                                      context)
                                                                  .push(
                                                                MaterialPageRoute(
                                                                  builder: (_) =>
                                                                      TasksReportsQualityForm(
                                                                    timelineRef:
                                                                        d.reference,
                                                                    locationRefs:
                                                                        locs,
                                                                  ),
                                                                ),
                                                              );
                                                            }
                                                          : null,
                                                  onTimerTap: !done
                                                      ? () => TaskTimerDialog
                                                              .show(
                                                            context: context,
                                                            timelineRef:
                                                                d.reference,
                                                            taskData: m,
                                                            currentMemberRef:
                                                                memberRef,
                                                            currentMemberId:
                                                                uid,
                                                            currentMemberName:
                                                                currentMemberName,
                                                          )
                                                      : null,
                                                ),
                                                showNoteAvatar:
                                                    hasNote && !contrib,
                                                showFlagBadge: flagBadge,
                                                timerBadgeColor:
                                                    timerBadgeColor,
                                                text: m['name'] ?? 'Untitled',
                                                textColor: txtColor,
                                                isActive: ac.containsKey(uid),
                                                onHistoryTap: () =>
                                                    Navigator.of(context).push(
                                                  MaterialPageRoute(
                                                    builder: (_) =>
                                                        TaskDetailsTabs(
                                                      companyId: cid,
                                                      routineId: d.id,
                                                    ),
                                                  ),
                                                ),
                                                hasActiveContributors: contrib,
                                                activeContributorsMap: ac,
                                                pastContributorsMap: hist,
                                                onContributorsTap: contrib
                                                    ? () => TaskTile
                                                            .showActiveContributorsDialog(
                                                            context: context,
                                                            taskData: m,
                                                            companyDocId: cid,
                                                            timelineRef:
                                                                d.reference,
                                                            currentMemberId:
                                                                uid,
                                                            currentMemberName:
                                                                currentMemberName,
                                                            canRemoveContributor:
                                                                canRemoveContributor,
                                                          )
                                                    : null,
                                                onNoteTap: hasNote
                                                    ? () => TaskTile
                                                        .showTaskNoteDialog(
                                                            context: context,
                                                            taskData: m)
                                                    : null,
                                                onServiceRequestTap: () {
                                                  final locs = (m['locationId']
                                                          as List<dynamic>?)
                                                      ?.cast<
                                                          DocumentReference<
                                                              Map<String,
                                                                  dynamic>>>();
                                                  Navigator.of(context).push(
                                                    MaterialPageRoute(
                                                      builder: (_) =>
                                                          TasksReportsRequestForm(
                                                        timelineRef:
                                                            d.reference,
                                                        locationRefs: locs,
                                                      ),
                                                    ),
                                                  );
                                                },
                                                onVoiceAlertTap: (canAlertTask &&
                                                        ac.isEmpty &&
                                                        !done)
                                                    ? () => TaskTile
                                                            .showTaskAlertForm(
                                                          context: context,
                                                          timelineRef:
                                                              d.reference,
                                                        )
                                                    : null,
                                                onVoiceCallTap: showVideoIcon
                                                    ? () =>
                                                        _startTaskVoiceCall(
                                                          context: context,
                                                          companyId: cid,
                                                          timelineRef:
                                                              d.reference,
                                                          activeContributors:
                                                              ac,
                                                          contributors: hist,
                                                          currentMemberId: uid,
                                                          taskLabel: taskLabel,
                                                          sourceContext:
                                                              'task_tile',
                                                        )
                                                    : null,
                                                onVideoConferenceTap:
                                                    showVideoIcon
                                                        ? () =>
                                                            _startTaskVideoConference(
                                                              context: context,
                                                              timelineRef:
                                                                  d.reference,
                                                              activeContributors:
                                                                  ac,
                                                              contributors:
                                                                  hist,
                                                              companyId: cid,
                                                              currentMemberId:
                                                                  uid,
                                                              taskLabel:
                                                                  taskLabel,
                                                              sourceContext:
                                                                  'task_tile',
                                                            )
                                                        : null,
                                                onAlertFlagTap:
                                                    (canFlag && isIncomplete)
                                                        ? () => showDialog(
                                                              context: context,
                                                              builder: (_) =>
                                                                  TaskAlertDialog(
                                                                timelineRef:
                                                                    d.reference,
                                                                currentMemberRef:
                                                                    memberRef,
                                                              ),
                                                            )
                                                        : null,
                                                onQualityReportTap:
                                                    (canQuality && done)
                                                        ? () {
                                                            final locs = (m[
                                                                        'locationId']
                                                                    as List<
                                                                        dynamic>?)
                                                                ?.cast<
                                                                    DocumentReference<
                                                                        Map<String,
                                                                            dynamic>>>();
                                                            Navigator.of(
                                                                    context)
                                                                .push(
                                                              MaterialPageRoute(
                                                                builder: (_) =>
                                                                    TasksReportsQualityForm(
                                                                  timelineRef: d
                                                                      .reference,
                                                                  locationRefs:
                                                                      locs,
                                                                ),
                                                              ),
                                                            );
                                                          }
                                                        : null,
                                                trailingIcon1: trailingIcon1,
                                                trailingAction1:
                                                    trailingAction1,
                                              ),
                                            );
                                          },
                                        );
                                        final searchControl = Column(
                                          children: [
                                            SearchControlStrip(
                                              controller: _searchCtrl,
                                              focusNode: _searchFocus,
                                              hintText: 'Search tasks...',
                                              onChanged: (val) {
                                                ref
                                                    .read(
                                                      taskListControllerProvider
                                                          .notifier,
                                                    )
                                                    .setSearch(val);
                                              },
                                            ),
                                            if (_searchAttachmentName != null)
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                    top: 8),
                                                child:
                                                    _buildSearchAttachmentPreview(
                                                  context,
                                                ),
                                              ),
                                          ],
                                        );
                                        final content = Column(
                                          children: [
                                            Expanded(
                                              child: filtered.isEmpty
                                                  ? const Center(
                                                      child: Text('No tasks.'))
                                                  : taskList,
                                            ),
                                            if (showSearchBar) searchControl,
                                          ],
                                        );
                                        if (showWarnOverlay && !trainingWarningAcknowledged) {
                                          return Stack(
                                            children: [
                                              content,
                                              Container(
                                                color: Colors.black54,
                                                child: Center(
                                                  child: Column(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      const Padding(
                                                        padding: EdgeInsets.all(
                                                            16.0),
                                                        child: SizedBox(),
                                                      ),
                                                      Padding(
                                                        padding:
                                                            const EdgeInsets
                                                                .symmetric(
                                                                horizontal:
                                                                    24.0),
                                                        child: Text(
                                                          warnMessage ??
                                                              'Training notice',
                                                          textAlign:
                                                              TextAlign.center,
                                                          style:
                                                              const TextStyle(
                                                                  color: Colors
                                                                      .white),
                                                        ),
                                                      ),
                                                      ElevatedButton(
                                                        onPressed: () {
                                                      ref
                                                          .read(
                                                            taskListControllerProvider
                                                                .notifier,
                                                          )
                                                          .acknowledgeTrainingWarning();
                                                    },
                                                    child: const Text(
                                                        'Acknowledge'),
                                                  ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ],
                                          );
                                        }
                                        return content;
                                      },
                                    ), // end timeline provider
                                    ),
                                    ),
                                    AnimatedPositioned(
                                      duration: const Duration(milliseconds: 180),
                                      curve: Curves.easeOut,
                                      right: 16,
                                      bottom: 16 + (showSearchBar ? 44.0 : 0.0),
                                      child: Consumer(
                                        builder: (context, ref, _) {
                                          final fabVisible = ref.watch(
                                            taskListControllerProvider.select(
                                              (state) => state.fabVisible,
                                            ),
                                          );
                                          return IgnorePointer(
                                            ignoring: !fabVisible,
                                            child: AnimatedOpacity(
                                              duration:
                                                  const Duration(milliseconds: 300),
                                              opacity: fabVisible ? 1 : 0,
                                              child: FloatingActionButton(
                                                heroTag: 'tasks_fab',
                                                onPressed: () => context.push(
                                                  AppRoutes
                                                      .tasksReportsUnscheduledTaskForm,
                                                ),
                                                child: const Icon(
                                                  Icons.add,
                                                ),
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ],
                                );
                              },
                        );
                      },
                ); // end companyIdProvider.when
          },
        ); // end userDocumentProvider.when
  }
}

class _SwipeCloseout {
  _SwipeCloseout({
    required this.memberDocRef,
    required this.memberName,
    required this.startTs,
    required this.durationMinutes,
    required this.geoIn,
  });

  final DocumentReference<Map<String, dynamic>>? memberDocRef;
  final String memberName;
  final Timestamp startTs;
  final int durationMinutes;
  final Object? geoIn;
}

String _firstString(Object? value) {
  if (value is String) return value;
  if (value is Map) {
    for (final v in value.values) {
      if (v is String && v.trim().isNotEmpty) return v;
    }
  }
  return '';
}
