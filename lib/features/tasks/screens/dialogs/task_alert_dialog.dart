// – NEW (2025-05-24) – dialog to manage alert-on-start / alert-when-complete
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_widgets/tiles/selectable_row_tile.dart';
import 'package:kleenops_admin/repositories/task_repository.dart';
import 'package:shared_widgets/dialogs/dialog_action.dart';

class TaskAlertDialog extends StatefulWidget {
  const TaskAlertDialog({
    super.key,
    required this.timelineRef,
    required this.currentMemberRef,
  });

  final DocumentReference<Map<String, dynamic>> timelineRef;
  final DocumentReference<Map<String, dynamic>> currentMemberRef;

  @override
  State<TaskAlertDialog> createState() => _TaskAlertDialogState();
}

class _TaskAlertDialogState extends State<TaskAlertDialog> {
  bool wantStart = false;
  bool wantDone  = false;

  List<DocumentReference> startRefs = <DocumentReference>[];
  List<DocumentReference> doneRefs  = <DocumentReference>[];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final snap = await widget.timelineRef.get();
    final data = snap.data() ?? {};
    startRefs = List<DocumentReference>.from(data['alertOnStart'] ?? const []);
    doneRefs  = List<DocumentReference>.from(data['alertWhenComplete'] ?? const []);
    wantStart = startRefs.contains(widget.currentMemberRef);
    wantDone  = doneRefs .contains(widget.currentMemberRef);
    if (mounted) setState(() {});
  }

  Future<List<Widget>> _names(List<DocumentReference> refs) async {
    final snaps = await Future.wait(refs.map((r) => r.get()));
    return [
      for (var i = 0; i < refs.length; i++)
        ListTile(
          dense: true,
          leading: const Icon(Icons.person),
          title: Text(
            (snaps[i].data() as Map<String, dynamic>?)?['name'] ?? refs[i].id,
          ),
        ),
    ];
  }

  Future<void> _save() async {
    final batch = TaskRepository().batch();
    final me   = widget.currentMemberRef;

    if (wantStart && !startRefs.contains(me)) {
      batch.update(widget.timelineRef, {
        'alertOnStart': FieldValue.arrayUnion([me])
      });
    } else if (!wantStart && startRefs.contains(me)) {
      batch.update(widget.timelineRef, {
        'alertOnStart': FieldValue.arrayRemove([me])
      });
    }

    if (wantDone && !doneRefs.contains(me)) {
      batch.update(widget.timelineRef, {
        'alertWhenComplete': FieldValue.arrayUnion([me])
      });
    } else if (!wantDone && doneRefs.contains(me)) {
      batch.update(widget.timelineRef, {
        'alertWhenComplete': FieldValue.arrayRemove([me])
      });
    }

    await batch.commit();
  }

  @override
  Widget build(BuildContext context) {
    return DialogAction(
      title: 'Task Alerts',
      cancelText: 'Cancel',
      actionText: 'Save',
      onCancel: () => Navigator.of(context).pop(),
      onAction: () async {
        await _save();
        // ignore result, just close
        if (mounted) Navigator.of(context).pop();
      },
      content: FutureBuilder(
        future: Future.wait([
          _names(startRefs),
          _names(doneRefs),
        ]),
        builder: (ctx, snap) {
          final startTiles = snap.data?[0] ?? [];
          final doneTiles  = snap.data?[1] ?? [];

          return SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SelectableRowTile<bool>(
                  value: true,
                  selected: wantStart,
                  label: 'Alert on Start',
                  onTap: () => setState(() => wantStart = !wantStart),
                ),
                SelectableRowTile<bool>(
                  value: true,
                  selected: wantDone,
                  label: 'Alert when Complete',
                  onTap: () => setState(() => wantDone = !wantDone),
                ),
                const SizedBox(height: 16),
                if (startTiles.isNotEmpty)
                  const Text('Alert on Start', style: TextStyle(fontWeight: FontWeight.bold)),
                ...startTiles,
                if (doneTiles.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text('Alert when Complete', style: TextStyle(fontWeight: FontWeight.bold)),
                  ...doneTiles,
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
