import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_widgets/labels/text_info_checkbox.dart';
import 'package:shared_widgets/theme/app_palette.dart';
import 'package:shared_widgets/dialogs/dialog_action.dart';

Future<void> showTaskSettingsDialog(
  BuildContext context,
  DocumentReference<Map<String, dynamic>> memberDoc,
  Map<String, dynamic> userData,
) {
  return showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => TaskSettingsDialog(
      memberDoc: memberDoc,
      userData: userData,
    ),
  );
}

class TaskSettingsDialog extends StatefulWidget {
  const TaskSettingsDialog({
    super.key,
    required this.memberDoc,
    required this.userData,
  });

  final DocumentReference<Map<String, dynamic>> memberDoc;
  final Map<String, dynamic> userData;

  @override
  State<TaskSettingsDialog> createState() => _TaskSettingsDialogState();
}

class _TaskSettingsDialogState extends State<TaskSettingsDialog> {
  late bool showBlackouts;
  late bool showSkipped;
  late bool showCompleted;
  late bool showPriority;
  late bool disablePacing;
  late bool overrideFilter;

  // Task-type toggles (previously the bottom control strip).
  // Default ON when the field is absent — matches the read sites in tasks_tasks.dart.
  late bool showCatTimeline;
  late bool showCatAssignment;
  late bool showDependents;
  late bool showCatAddBox;

  @override
  void initState() {
    super.initState();
    final d = widget.userData;

    // initialize all local state from the snapshot that was passed in
    showBlackouts = d['showBlackouts'] == true;
    showSkipped = d['showSkipped'] == true;
    showCompleted = d['showCompleted'] == true;
    showPriority = d['showPriority'] == true;
    disablePacing = d['disablePacing'] == true;
    overrideFilter = d['overrideActionFilter'] == true;

    showCatTimeline = d['showCatTimeline'] != false;
    showCatAssignment = d['showCatAssignment'] != false;
    showDependents = d['showDependents'] != false;
    showCatAddBox = d['showCatAddBox'] != false;
  }

  Future<void> _saveAllSettings() {
    // Build a single map of all the fields we care about
    final updates = <String, Object?>{
      'showBlackouts': showBlackouts,
      'showSkipped': showSkipped,
      'showCompleted': showCompleted,
      'showPriority': showPriority,
      'disablePacing': disablePacing,
      'overrideActionFilter': overrideFilter,
      'showCatTimeline': showCatTimeline,
      'showCatAssignment': showCatAssignment,
      'showDependents': showDependents,
      'showCatAddBox': showCatAddBox,
    };

    return widget.memberDoc
        .update(updates)
        .catchError((_) {/* ignore member write failures */});
  }

  // ---------- reusable row widget (no Firestore calls here) ----------
  Widget _row({
    required String label,
    required bool val,
    required void Function(bool?) onChanged,
    required IconData icon,
    required Color activeColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: TextInfoCheckbox(
        leadingIcon: icon,
        text: label,
        value: val,
        onChanged: onChanged,
        activeColor: activeColor,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPaletteScope.of(context);
    final activeColor = palette.primary2;
    final canDisablePacing = widget.userData['canDisablePacing'] == true;
    final canOverride = widget.userData['canOverride'] == true;

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Task-type toggles (replaces the former bottom control strip)
        _row(
          label: 'Show scheduled tasks',
          val: showCatTimeline,
          icon: Icons.view_timeline,
          onChanged: (v) => setState(() => showCatTimeline = v ?? false),
          activeColor: activeColor,
        ),
        _row(
          label: 'Show unscheduled tasks',
          val: showCatAssignment,
          icon: Icons.assignment_add,
          onChanged: (v) => setState(() => showCatAssignment = v ?? false),
          activeColor: activeColor,
        ),
        _row(
          label: 'Show dependents',
          val: showDependents,
          icon: Icons.device_hub,
          onChanged: (v) => setState(() => showDependents = v ?? false),
          activeColor: activeColor,
        ),
        _row(
          label: 'Show added tasks',
          val: showCatAddBox,
          icon: Icons.add_box,
          onChanged: (v) => setState(() => showCatAddBox = v ?? false),
          activeColor: activeColor,
        ),
        Divider(height: 16, color: Colors.grey.shade300),
        // Basic toggles (local only)
        _row(
          label: 'Show blackouts',
          val: showBlackouts,
          icon: Icons.pause_circle_outlined,
          onChanged: (v) => setState(() => showBlackouts = v ?? false),
          activeColor: activeColor,
        ),
        _row(
          label: 'Show skipped',
          val: showSkipped,
          icon: Icons.skip_next_outlined,
          onChanged: (v) => setState(() => showSkipped = v ?? false),
          activeColor: activeColor,
        ),
        _row(
          label: 'Show completed',
          val: showCompleted,
          icon: Icons.check_box_outlined,
          onChanged: (v) => setState(() => showCompleted = v ?? false),
          activeColor: activeColor,
        ),
        _row(
          label: 'Show priority',
          val: showPriority,
          icon: Icons.star_border,
          onChanged: (v) => setState(() => showPriority = v ?? false),
          activeColor: activeColor,
        ),
        if (canDisablePacing)
          _row(
            label: 'Disable pacing',
            val: disablePacing,
            icon: Icons.slow_motion_video_outlined,
            onChanged: (v) => setState(() => disablePacing = v ?? false),
            activeColor: activeColor,
          ),
        if (canOverride)
          _row(
            label: 'Disable action restrictions',
            val: overrideFilter,
            icon: Icons.filter_list_off,
            onChanged: (v) => setState(() => overrideFilter = v ?? false),
            activeColor: activeColor,
          ),
      ],
    );

    return DialogAction(
      title: 'Task Settings',

      // Inject both Close (cancel) and Save (apply) buttons:
      cancelText: 'Close',
      onCancel: () => Navigator.of(context, rootNavigator: true).pop(),
      actionText: 'Save',
      onAction: () async {
        await _saveAllSettings();
        if (context.mounted) {
           Navigator.of(context, rootNavigator: true).pop();
        }
      },

      // We now _do_ want an action button
      showActionButton: true,

      content: content,
    );
  }
}
