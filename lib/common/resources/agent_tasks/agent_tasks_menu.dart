// Injects an "Agent Tasks" entry into every screen's drawer Actions section,
// right after "My Tasks" (mirrors kleenops). Opens the agent-tasks list for
// the signed-in overlord company (cid read at tap time from companyIdProvider).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kleenops_admin/app/routes.dart';
import 'package:kleenops_admin/common/resources/my_tasks/my_tasks_menu.dart';
import 'package:kleenops_admin/common/utils/snackbar_service.dart';
import 'package:kleenops_admin/features/auth/providers/auth_provider.dart';
import 'package:shared_widgets/drawers/menu_drawer.dart';

const String kAgentTasksMenuLabel = 'Agent Tasks';

MenuDrawerSections withAgentTasksInSections(
  BuildContext context,
  MenuDrawerSections sections,
) {
  return MenuDrawerSections(
    actions: withAgentTasksActionMenuItem(context, sections.actions),
    resources: sections.resources,
    communications: sections.communications,
  );
}

List<ContentMenuItem> withAgentTasksActionMenuItem(
  BuildContext context,
  List<ContentMenuItem> actions,
) {
  final normalized = kAgentTasksMenuLabel.toLowerCase();
  final hasEntry =
      actions.any((item) => item.label.trim().toLowerCase() == normalized);
  if (hasEntry) return actions;

  final myTasksNormalized = kMyTasksMenuLabel.toLowerCase();
  final myTasksIndex = actions.indexWhere(
    (item) => item.label.trim().toLowerCase() == myTasksNormalized,
  );

  final agentTasksItem = buildAgentTasksMenuItem(context);
  if (myTasksIndex < 0) {
    return [agentTasksItem, ...actions];
  }
  return [
    ...actions.sublist(0, myTasksIndex + 1),
    agentTasksItem,
    ...actions.sublist(myTasksIndex + 1),
  ];
}

ContentMenuItem buildAgentTasksMenuItem(BuildContext context) {
  return ContentMenuItem(
    icon: Icons.bolt_outlined,
    label: kAgentTasksMenuLabel,
    onTap: () {
      final container = ProviderScope.containerOf(context);
      final companyRef = container.read(companyIdProvider).value;
      if (companyRef == null) {
        SnackbarService.instance.showSnackBar(
          const SnackBar(
            duration: Duration(seconds: 5),
            content: Text(
              'Sign in and pick a company before opening Agent Tasks.',
            ),
          ),
        );
        return;
      }
      context.push('${AppRoutePaths.agentTasks}?cid=${companyRef.id}');
    },
  );
}
