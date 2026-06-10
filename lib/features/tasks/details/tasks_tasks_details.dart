// lib/features/tasks/details/tasks_tasks_details.dart
//
// Admin port shim. The kleenops task-details screen pulls in the full
// facilities `location_tabs` subtree (object/facilities file-image utils,
// associated-links container, image viewer) which isn't ported to the admin
// app. This thin wrapper keeps the task-tile tap navigation working by
// delegating to the already-ported `TaskDetailsTabs` history/analytics view.
import 'package:flutter/material.dart';
import 'package:kleenops_admin/features/tasks/tabs/task_details_tabs.dart';

class TasksTasksDetails extends StatelessWidget {
  const TasksTasksDetails({
    super.key,
    required this.companyId,
    required this.docId,
  });

  final String companyId;
  final String docId;

  @override
  Widget build(BuildContext context) =>
      TaskDetailsTabs(companyId: companyId, routineId: docId);
}
