// lib/widgets/tiles/task_tile.dart
// – revised 2025‑05‑17c – dialogs use context.showShellDialog

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:kleenops_admin/common/extensions/build_context_extensions.dart';
import 'package:kleenops_admin/features/tasks/forms/task_alert_form.dart';
import 'package:kleenops_admin/widgets/icons/badge_icon.dart';
import 'package:shared_widgets/dialogs/dialog_action.dart';
import 'package:shared_widgets/theme/app_palette.dart';
import 'package:kleenops_admin/common/utils/snackbar_service.dart';

class TaskTile extends StatelessWidget {
  const TaskTile({
    super.key,
    // primary
    this.leadingIcon,
    this.leadingIconAction,
    required this.text,
    this.leadingIconColor,
    this.textSize,
    this.textColor,
    this.twoDigitText,
    this.leadingBadge,
    // trailing
    this.trailingIcon1,
    this.trailingAction1,
    this.trailingBadge1,
    this.trailingIcon2,
    this.trailingAction2,
    // extras
    required this.isActive,
    required this.onHistoryTap,
    this.onContributorsTap,
    this.hasActiveContributors = false,
    this.activeContributorsMap,
    this.pastContributorsMap,
    this.onNoteTap,
    this.onServiceRequestTap,
    this.onVoiceAlertTap,
    this.onVoiceCallTap,
    this.onVideoConferenceTap,
    this.onQualityReportTap,
    this.onAlertFlagTap,     // ← NEW
    this.showNoteAvatar = false,
    this.showFlagBadge = false,
    this.timerBadgeColor,
  });

  // ────────── params ──────────
  final IconData? leadingIcon;
  final VoidCallback? leadingIconAction;
  final String text;
  final Color? leadingIconColor;
  final double? textSize;
  final Color? textColor;
  final String? twoDigitText;
  final int? leadingBadge;

  final IconData? trailingIcon1;
  final VoidCallback? trailingAction1;
  final int? trailingBadge1;

  final IconData? trailingIcon2;
  final VoidCallback? trailingAction2;

  final bool isActive;
  final VoidCallback onHistoryTap;
  final VoidCallback? onContributorsTap;
  final bool hasActiveContributors;

  /// Currently-active contributors keyed by memberId. Used to populate the
  /// leading-icon hover tooltip — no UI of its own, callers don't need to
  /// pass it unless they want the hover.
  final Map<String, dynamic>? activeContributorsMap;

  /// Past contributors keyed by memberId. Same role as
  /// [activeContributorsMap] — drives the leading-icon hover tooltip.
  final Map<String, dynamic>? pastContributorsMap;

  final VoidCallback? onNoteTap;
  final VoidCallback? onServiceRequestTap;
  final VoidCallback? onVoiceAlertTap;
  final VoidCallback? onVoiceCallTap;
  final VoidCallback? onVideoConferenceTap;
  final VoidCallback? onQualityReportTap;
  final VoidCallback? onAlertFlagTap;      // ← NEW

  final bool showNoteAvatar;
  final bool showFlagBadge;
  final Color? timerBadgeColor;

  static const double _leadSize = 32;

  @override
  Widget build(BuildContext context) {
    final Color trayClr = AppPaletteScope.of(context).primary2;
    final Color mainClr = leadingIconColor ?? trayClr;
    final Color txtClr  = textColor ?? Colors.black;

    final primary = Material(
      color: Colors.white,
      child: ListTile(
        dense: true,
        visualDensity: VisualDensity.compact,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8),
        tileColor: Colors.white,
        leading: _buildLeading(mainClr),
        title : Text(text,
            style: TextStyle(fontSize: textSize ?? 14, color: txtClr)),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          _buildTrailing(trailingIcon1, trailingAction1, mainClr, trailingBadge1),
          _buildTrailing(trailingIcon2, trailingAction2, mainClr),
        ]),
      ),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [primary, _buildExtraRow(trayClr)],
    );
  }

  /// ───────── extras row ─────────
  Widget _buildExtraRow(Color clr) {
    // your existing extras list stays the same
    final extras = <Widget>[
      _mini(icon: Icons.history_outlined, onTap: onHistoryTap, clr: clr),
      if (onContributorsTap != null)
        _mini(icon: Icons.people, onTap: onContributorsTap!, clr: clr),
      _divider(),
      if (onNoteTap != null)
        _mini(icon: Icons.note_alt, onTap: onNoteTap!, clr: clr),
      if (onVoiceAlertTap != null)
        _mini(icon: Icons.warning_amber_outlined, onTap: onVoiceAlertTap!, clr: clr),
      if (onVoiceCallTap != null)
        _mini(icon: Icons.record_voice_over, onTap: onVoiceCallTap!, clr: clr),
      if (onVideoConferenceTap != null)
        _mini(icon: Icons.video_camera_front,
              onTap: onVideoConferenceTap!, clr: clr),
      _divider(),
      if (onServiceRequestTap != null)
        _mini(icon: Icons.assignment_add, onTap: onServiceRequestTap!, clr: clr),
      if (onAlertFlagTap != null)           // ← your flag icon
        _mini(icon: Icons.flag, onTap: onAlertFlagTap!, clr: clr),
      if (onQualityReportTap != null)
        _mini(icon: Icons.content_paste_search,
              onTap: onQualityReportTap!, clr: clr),
    ];

    // wrap the whole tray so taps don’t bubble up
    return isActive
      ? GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {}, // absorbs taps on the tray area
          child: Container(
            color: Colors.grey[100],
            height: 40,
            alignment: Alignment.center,
            child: Wrap(
              spacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: extras,
            ),
          ),
        )
      : const SizedBox.shrink();
  }

  /* ───────── helpers (unchanged below) ───────── */

  Widget _divider() => Container(width: 1, height: 24, color: Colors.grey[300]);

  Widget _mini({
    required IconData icon,
    required VoidCallback onTap,
    required Color clr,
  }) =>
      IconButton(
        icon: Icon(icon, size: 22, color: clr),
        onPressed: onTap,
        padding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
      );

  Widget _buildTrailing(
    IconData? icon,
    VoidCallback? act,
    Color clr, [
    int? badge,
  ]) {
    if (icon == null) return const SizedBox.shrink();
    final btn = IconButton(
      icon: Icon(icon, size: 20, color: clr),
      onPressed: act,
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
    );
    return badge == null
        ? btn
        : BadgeIcon(badgeCount: badge, topOffset: -2, rightOffset: -2, child: btn);
  }

  Widget _buildLeading(Color clr) {
    Widget glyph;
    if (twoDigitText != null) {
      glyph = CircleAvatar(
        radius: 13,
        backgroundColor: clr,
        child: Text(twoDigitText!,
            style: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black)),
      );
    } else if (leadingIcon != null) {
      glyph = Icon(leadingIcon, size: 18, color: clr);
    } else {
      glyph = const SizedBox.shrink();
    }

    // Center the glyph in the full square so the orbital badges sit at its
    // corners consistently.
    final main = SizedBox(
      width: _leadSize,
      height: _leadSize,
      child: Center(child: glyph),
    );

    final cluster = SizedBox(
      width: _leadSize,
      height: _leadSize,
      child: BadgeIcon(
        badgeCount: leadingBadge,
        showEditBadge: showNoteAvatar,
        showFlagBadge: showFlagBadge,
        timerBadgeColor: timerBadgeColor,
        topOffset: -2,
        rightOffset: -2,
        leftOffset: -2,
        badgeColor: Colors.grey[300]!,
        child: main,
      ),
    );

    final tooltipMessage = _contributorTooltipMessage();
    final tooltipped = tooltipMessage == null
        ? cluster
        : Tooltip(
            message: tooltipMessage,
            waitDuration: const Duration(milliseconds: 300),
            child: cluster,
          );

    if (leadingIconAction == null) return tooltipped;

    // The whole square — center icon *and* the orbital badges — opens the
    // drawer. The badges sit on top in the Stack and would otherwise swallow
    // taps, so one opaque handler wraps the entire cluster.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: leadingIconAction,
      child: tooltipped,
    );
  }

  /// Builds the hover-tooltip string for the leading icon. Lists active
  /// contributors first ("Active: …"), then past contributors who aren't
  /// also active ("Past: …"). Returns `null` when neither map has anyone,
  /// so the caller can skip wrapping the cluster in a Tooltip.
  String? _contributorTooltipMessage() {
    final active = activeContributorsMap ?? const <String, dynamic>{};
    final past = pastContributorsMap ?? const <String, dynamic>{};
    if (active.isEmpty && past.isEmpty) return null;

    String nameFrom(MapEntry<String, dynamic> e) {
      final v = (e.value as Map?)?.cast<String, dynamic>() ?? const {};
      final raw = v['name'];
      if (raw is String && raw.trim().isNotEmpty) return raw.trim();
      return 'Unknown';
    }

    final lines = <String>[];
    if (active.isNotEmpty) {
      final names = active.entries.map(nameFrom).toList()
        ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      lines.add('Active: ${names.join(', ')}');
    }

    final pastOnly = past.entries
        .where((e) => !active.containsKey(e.key))
        .map(nameFrom)
        .toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    if (pastOnly.isNotEmpty) {
      lines.add('Past: ${pastOnly.join(', ')}');
    }

    return lines.isEmpty ? null : lines.join('\n');
  }

  /* ───────── dialogs (DialogAction) – unchanged below ───────── */

  static Future<bool?> showTaskAlertForm({
    required BuildContext context,
    required DocumentReference<Map<String, dynamic>> timelineRef,
  }) {
    return TaskAlertForm.show(
      context,
      timelineRef: timelineRef,
    );
  }

  static Future<void> _showScrollableListDialog({
    required BuildContext context,
    required String title,
    required List<Widget> tiles,
  }) {
    return context.showShellDialog(
      builder: (ctx) => DialogAction(
        title: title,
        cancelText: 'Close',
        actionText: '',
        showActionButton: false,
        onCancel: () => Navigator.of(ctx).pop(),
        onAction: () {},
        content: SizedBox(
          width: double.maxFinite,
          height: MediaQuery.of(ctx).size.height * .60,
          child: ListView(shrinkWrap: true, children: tiles),
        ),
      ),
    );
  }

  static Future<void> _info(BuildContext ctx, String title, String msg) {
    return ctx.showShellDialog(
      builder: (dCtx) => DialogAction(
        title: title,
        cancelText: 'Close',
        actionText: '',
        showActionButton: false,
        onCancel: () => Navigator.of(dCtx).pop(),
        onAction: () {},
        content: Text(msg),
      ),
    );
  }

  /*  —— toTaskRef helper (unchanged) ——  */
  static DocumentReference<Map<String, dynamic>> toTaskRef(
      dynamic taskId, String companyId) {
    if (taskId is DocumentReference<Map<String, dynamic>>) return taskId;
    if (taskId is String) {
      return FirebaseFirestore.instance
          .collection('company')
          .doc(companyId)
          .collection('tasks')
          .doc(taskId)
          .withConverter<Map<String, dynamic>>(
            fromFirestore: (s, _) => s.data() ?? {},
            toFirestore: (m, _) => m,
          );
    }
    throw ArgumentError('taskId must be String or DocumentReference');
  }

  /* ───────── master entry point ───────── */
  static Future<void> showLeadingDialog({
    required BuildContext context,
    required Map<String, dynamic> taskData,
    required String companyDocId,
    DocumentReference<Map<String, dynamic>>? timelineRef,
    String? currentMemberId,
    String? currentMemberName,
    bool canRemoveContributor = false,
  }) async {
    final active =
        (taskData['activeContributors'] as Map?)?.cast<String, dynamic>() ?? {};
    if (active.isEmpty) {
      return showPastContributorsDialog(
        context     : context,
        companyDocId: companyDocId,
        taskRef     : toTaskRef(taskData['taskId'], companyDocId),
      );
    }
    return showActiveContributorsDialog(
      context: context,
      taskData: taskData,
      companyDocId: companyDocId,
      timelineRef: timelineRef,
      currentMemberId: currentMemberId,
      currentMemberName: currentMemberName,
      canRemoveContributor: canRemoveContributor,
    );
  }

  /* ───────── contributors – last 14 days ───────── */
  static Future<void> showPastContributorsDialog({
    required BuildContext context,
    required String companyDocId,
    required DocumentReference taskRef,
  }) async {
    final fs = FirebaseFirestore.instance;
    final docs = await fs
        .collection('company').doc(companyDocId)
        .collection('timeline')
        .where('timelineCategory', isEqualTo: 'E2HMUuMUUl4Alttuweba')
        .where('taskId',          isEqualTo: taskRef)
        .where(
          'startTime',
          isGreaterThanOrEqualTo: Timestamp.fromDate(
            DateTime.now().subtract(const Duration(days: 14)),
          ),
        )
        .get();

    if (docs.docs.isEmpty) {
      return _info(
        context,
        'No Contributors Found',
        'No contributors have worked on this task in the last 14 days.',
      );
    }

    final tiles = docs.docs.map((d) {
      final m  = d.data();
      final ts = m['startTime'] as Timestamp?;
      return ListTile(
        leading : const Icon(Icons.history_outlined),
        title   : Text(m['name'] ?? 'Unknown'),
        subtitle: Text(
          'Start: ${ts != null ? DateFormat('h:mm a').format(ts.toDate()) : 'N/A'}\n'
          'Duration: ${m['duration'] ?? 0} m',
        ),
      );
    }).toList();

    await _showScrollableListDialog(
      context : context,
      title   : 'Contributors (Last 14 Days)',
      tiles   : tiles,
    );
  }

  /* ───────── active contributors ───────── */
  static Future<void> showActiveContributorsDialog({
    required BuildContext context,
    required Map<String, dynamic> taskData,
    String? companyDocId,
    DocumentReference<Map<String, dynamic>>? timelineRef,
    String? currentMemberId,
    String? currentMemberName,
    bool canRemoveContributor = false,
  }) async {
    final active =
        (taskData['activeContributors'] as Map?)?.cast<String, dynamic>() ?? {};
    if (active.isEmpty) {
      return _info(
        context,
        'No Active Contributors',
        'No one is currently working on this task.',
      );
    }

    // Removal requires enough context to run the kick transaction; if any of
    // the supporting params are missing, fall back to a read-only dialog.
    final canKick = canRemoveContributor &&
        companyDocId != null &&
        timelineRef != null &&
        currentMemberId != null &&
        currentMemberId.isNotEmpty;

    await context.showShellDialog(
      builder: (ctx) => DialogAction(
        title: 'Active Contributors',
        cancelText: 'Close',
        actionText: '',
        showActionButton: false,
        onCancel: () => Navigator.of(ctx).pop(),
        onAction: () {},
        content: SizedBox(
          width: double.maxFinite,
          height: MediaQuery.of(ctx).size.height * .60,
          child: _ActiveContributorsList(
            active: active,
            canKick: canKick,
            companyDocId: companyDocId,
            timelineRef: timelineRef,
            currentMemberId: currentMemberId,
            currentMemberName: currentMemberName,
          ),
        ),
      ),
    );
  }

  static Future<bool> _confirmRemoveContributor({
    required BuildContext context,
    required String name,
  }) async {
    bool confirmed = false;
    await showDialog(
      context: context,
      builder: (ctx) => DialogAction(
        title: 'Remove Contributor?',
        content: Text(
          'Remove $name from this task? Their time worked so far will be saved.',
        ),
        cancelText: 'Cancel',
        actionText: 'Remove',
        onCancel: () => Navigator.of(ctx).pop(),
        onAction: () {
          confirmed = true;
          Navigator.of(ctx).pop();
        },
      ),
    );
    return confirmed;
  }

  /// Removes [kickedMemberId] from [timelineRef]'s active contributors.
  /// Closes their contributor record with `removedBy`/`removedAt`, clears
  /// their `member.activeTaskId`, and writes a "task exit" timeline entry
  /// crediting the time worked up to the kick.
  static Future<void> _kickContributor({
    required BuildContext context,
    required String companyDocId,
    required DocumentReference<Map<String, dynamic>> timelineRef,
    required String kickedMemberId,
    required String kickedMemberName,
    required Timestamp? kickedStartTime,
    required String removedByMemberId,
    required String removedByName,
  }) async {
    final firestore = FirebaseFirestore.instance;
    final companyRef = firestore.collection('company').doc(companyDocId);
    final memberRef = companyRef.collection('member').doc(kickedMemberId);
    final removedByRef = companyRef.collection('member').doc(removedByMemberId);
    final newTimelineRef = companyRef.collection('timeline').doc();
    final now = DateTime.now();
    final nowTs = Timestamp.fromDate(now);

    try {
      await firestore.runTransaction((txn) async {
        // ── reads first ──
        final snap = await txn.get(timelineRef);
        if (!snap.exists) {
          throw Exception('Task no longer exists.');
        }
        final data = snap.data()!;
        final active = Map<String, dynamic>.from(
          (data['activeContributors'] as Map?) ?? const {},
        );
        if (!active.containsKey(kickedMemberId)) {
          throw Exception('Contributor is no longer active on this task.');
        }
        final activeEntry =
            (active[kickedMemberId] as Map).cast<String, dynamic>();
        final startTs = (activeEntry['startTime'] as Timestamp?) ??
            kickedStartTime ??
            nowTs;
        final startDt = startTs.toDate();
        final durationMinutes = now.difference(startDt).inMinutes;

        // Resolve the underlying task ref + name (for the timeline entry).
        final taskIdField = data['taskId'];
        DocumentReference<Map<String, dynamic>> existingTaskRef;
        if (taskIdField is DocumentReference<Map<String, dynamic>>) {
          existingTaskRef = taskIdField;
        } else if (taskIdField is DocumentReference) {
          existingTaskRef = taskIdField.withConverter<Map<String, dynamic>>(
            fromFirestore: (s, _) => s.data() ?? <String, dynamic>{},
            toFirestore: (m, _) => m,
          );
        } else if (taskIdField is String) {
          existingTaskRef = companyRef
              .collection('tasks')
              .doc(taskIdField)
              .withConverter<Map<String, dynamic>>(
                fromFirestore: (s, _) => s.data() ?? <String, dynamic>{},
                toFirestore: (m, _) => m,
              );
        } else {
          existingTaskRef = timelineRef;
        }
        final taskSnap = await txn.get(existingTaskRef);
        final taskName = (taskSnap.data()?['name'] as String?) ?? '';
        final taskTitle = (data['title'] as String?) ?? taskName;
        final memberSnap = await txn.get(memberRef);

        // ── writes ──
        final closedContributor = <String, dynamic>{
          ...(((data['contributors'] as Map?)?[kickedMemberId] as Map?)
                  ?.cast<String, dynamic>() ??
              const <String, dynamic>{}),
          'memberId': memberRef,
          'startTime': startTs,
          'endTime': nowTs,
          'duration': durationMinutes,
          'removedBy': removedByRef,
          'removedByName': removedByName,
          'removedAt': nowTs,
        };

        txn.update(timelineRef, {
          'activeContributors.$kickedMemberId': FieldValue.delete(),
          'contributors.$kickedMemberId': closedContributor,
        });

        if (memberSnap.exists) {
          final activeTask = memberSnap.data()?['activeTaskId'];
          if (activeTask is DocumentReference &&
              activeTask.path == timelineRef.path) {
            txn.update(memberRef, {'activeTaskId': FieldValue.delete()});
          }
        }

        txn.set(newTimelineRef, {
          'memberId': memberRef,
          'memberName': kickedMemberName,
          'name': taskName,
          'title': taskTitle,
          'startTime': startTs,
          'endTime': nowTs,
          'taskId': existingTaskRef,
          'timelineId': timelineRef,
          'duration': durationMinutes,
          'timelineCategory': 'E2HMUuMUUl4Alttuweba',
          'timelineCategoryId': companyRef
              .collection('timelineCategory')
              .doc('E2HMUuMUUl4Alttuweba'),
          'removedBy': removedByRef,
          'removedByName': removedByName,
          'createdAt': FieldValue.serverTimestamp(),
        });
      });

      if (!context.mounted) return;
      SnackbarService.instance.showSnackBar(
        SnackBar(duration: const Duration(seconds: 5), content: Text('$kickedMemberName removed from task.')),
      );
    } catch (e) {
      if (!context.mounted) return;
      SnackbarService.instance.showSnackBar(
        SnackBar(duration: const Duration(seconds: 5), content: Text('Could not remove contributor: $e')),
      );
    }
  }

  /* ───────── task notes ───────── */
  static Future<void> showTaskNoteDialog({
    required BuildContext context,
    required Map<String, dynamic> taskData,
  }) async {
    final noteMap =
        (taskData['taskNote'] as Map?)?.cast<String, dynamic>() ?? {};
    if (noteMap.isEmpty) {
      return _info(context, 'No Note',
          'No note has been recorded for this task.');
    }

    final entries = noteMap.values.cast<Map<String, dynamic>>().toList()
      ..sort((b, a) {
        final ta = a['timestamp'] as Timestamp?;
        final tb = b['timestamp'] as Timestamp?;
        return (ta?.compareTo(tb ?? Timestamp(0, 0))) ?? 0;
      });

    final tiles = entries.map((e) {
      final ts = e['timestamp'] as Timestamp?;
      return ListTile(
        leading : const Icon(Icons.notes_outlined),
        title   : Text(e['note'] ?? ''),
        subtitle: Text(
          '${e['name'] ?? 'Unknown'} • '
          '${ts != null ? DateFormat('MMM d, h:mm a').format(ts.toDate()) : ''}',
        ),
      );
    }).toList();

    await _showScrollableListDialog(
      context : context,
      title   : 'Task Notes',
      tiles   : tiles,
    );
  }
}

/// Mutable list of active contributors for the dialog. Owns its own state so
/// dismissed entries can be removed from the tree (Flutter requires that a
/// `Dismissible` actually leave the parent's children list after dismiss).
class _ActiveContributorsList extends StatefulWidget {
  const _ActiveContributorsList({
    required this.active,
    required this.canKick,
    required this.companyDocId,
    required this.timelineRef,
    required this.currentMemberId,
    required this.currentMemberName,
  });

  final Map<String, dynamic> active;
  final bool canKick;
  final String? companyDocId;
  final DocumentReference<Map<String, dynamic>>? timelineRef;
  final String? currentMemberId;
  final String? currentMemberName;

  @override
  State<_ActiveContributorsList> createState() =>
      _ActiveContributorsListState();
}

class _ActiveContributorsListState extends State<_ActiveContributorsList> {
  late final List<MapEntry<String, Map<String, dynamic>>> _entries;

  @override
  void initState() {
    super.initState();
    _entries = widget.active.entries
        .map((e) => MapEntry(
              e.key,
              (e.value as Map).cast<String, dynamic>(),
            ))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return ListView.builder(
      shrinkWrap: true,
      itemCount: _entries.length,
      itemBuilder: (context, index) {
        final entry = _entries[index];
        final memberId = entry.key;
        final v = entry.value;
        final ts = v['startTime'] as Timestamp?;
        final diff = ts != null ? now.difference(ts.toDate()) : null;
        final name = v['name'] as String? ?? 'Unknown';
        final tile = ListTile(
          leading: const Icon(Icons.groups),
          title: Text(name),
          subtitle: Text(
            diff != null
                ? 'Duration: ${diff.inHours}h ${diff.inMinutes % 60}m'
                : 'Start time not available',
          ),
        );

        if (!widget.canKick) return tile;

        return Dismissible(
          key: ValueKey('active_contributor_$memberId'),
          direction: DismissDirection.startToEnd,
          background: Container(
            color: Colors.red.shade600,
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: const Row(
              children: [
                Icon(Icons.person_remove, color: Colors.white),
                SizedBox(width: 8),
                Text('Remove', style: TextStyle(color: Colors.white)),
              ],
            ),
          ),
          confirmDismiss: (_) => TaskTile._confirmRemoveContributor(
            context: context,
            name: name,
          ),
          onDismissed: (_) async {
            setState(() =>
                _entries.removeWhere((e) => e.key == memberId));
            await TaskTile._kickContributor(
              context: context,
              companyDocId: widget.companyDocId!,
              timelineRef: widget.timelineRef!,
              kickedMemberId: memberId,
              kickedMemberName: name,
              kickedStartTime: ts,
              removedByMemberId: widget.currentMemberId!,
              removedByName: widget.currentMemberName ?? '',
            );
          },
          child: tile,
        );
      },
    );
  }
}
