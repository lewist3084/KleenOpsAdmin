// Single composition point for the admin drawer's universal menu items, so the
// same fixed set appears on EVERY screen (mirrors the kleenops appbar-adapter
// chain). Order matches kleenops: My Tasks + Agent Tasks → Actions, Files →
// Resources, the 7 Communications + Reminders → Communications. Each helper is
// idempotent, so screens that already passed some items are left intact.

import 'package:flutter/material.dart';
import 'package:shared_widgets/drawers/menu_drawer.dart';

import 'package:kleenops_admin/common/communications/comm_menu.dart';
import 'package:kleenops_admin/common/resources/agent_tasks/agent_tasks_menu.dart';
import 'package:kleenops_admin/common/resources/my_tasks/my_tasks_menu.dart';
import 'package:kleenops_admin/common/resources/projects/projects_menu.dart';
import 'package:kleenops_admin/common/resources/reminders/reminders_menu.dart';
import 'package:kleenops_admin/common/resources/resources_menu.dart';

/// Apply the full universal-injection chain to [sections].
MenuDrawerSections withAdminUniversalSections(
  BuildContext context,
  MenuDrawerSections sections,
) {
  return withRemindersInSections(
    context,
    withCommunicationsInSections(
      context,
      withAgentTasksInSections(
        context,
        withProjectsInSections(
          context,
          withFilesInSections(
            context,
            withMyTasksInSections(context, sections),
          ),
        ),
      ),
    ),
  );
}
