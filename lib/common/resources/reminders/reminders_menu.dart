// Injects a "Reminders" entry into every screen's drawer Communications
// section (between Email and Message Board), mirroring kleenops. Opens the
// Reminders list (kleenops/{id}/reminder owned by the signed-in member).

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kleenops_admin/app/routes.dart';
import 'package:kleenops_admin/common/resources/menu_badges.dart';
import 'package:shared_widgets/drawers/menu_drawer.dart';

const String kRemindersMenuLabel = 'Reminders';
const String _kMessageBoardLabel = 'Message Board';
const String _kEmailLabel = 'Email';

MenuDrawerSections withRemindersInSections(
  BuildContext context,
  MenuDrawerSections sections,
) {
  return MenuDrawerSections(
    actions: sections.actions,
    resources: sections.resources,
    communications:
        withRemindersCommunicationMenuItem(context, sections.communications),
  );
}

List<ContentMenuItem> withRemindersCommunicationMenuItem(
  BuildContext context,
  List<ContentMenuItem> communications,
) {
  final normalized = kRemindersMenuLabel.toLowerCase();
  final hasEntry = communications
      .any((item) => item.label.trim().toLowerCase() == normalized);
  if (hasEntry) return communications;

  final reminders = buildRemindersMenuItem(context);
  int boardIndex = -1;
  int emailIndex = -1;
  for (var i = 0; i < communications.length; i++) {
    final label = communications[i].label.trim().toLowerCase();
    if (label == _kMessageBoardLabel.toLowerCase()) boardIndex = i;
    if (label == _kEmailLabel.toLowerCase()) emailIndex = i;
  }
  final insertAt = boardIndex >= 0
      ? boardIndex
      : (emailIndex >= 0 ? emailIndex + 1 : communications.length);
  return [
    ...communications.sublist(0, insertAt),
    reminders,
    ...communications.sublist(insertAt),
  ];
}

ContentMenuItem buildRemindersMenuItem(BuildContext context) {
  return ContentMenuItem(
    icon: Icons.notifications_active_outlined,
    label: kRemindersMenuLabel,
    badge: menuBadge(remindersPendingCountProvider),
    onTap: () => context.push(AppRoutePaths.drawerReminders),
  );
}
