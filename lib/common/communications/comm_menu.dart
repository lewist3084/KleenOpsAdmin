import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kleenops_admin/app/routes.dart';
import 'package:kleenops_admin/common/resources/menu_badges.dart';
import 'package:shared_widgets/drawers/menu_drawer.dart';

/// Inject the canonical 7 communication items into the drawer's Communications
/// section (mirrors kleenops `withCommunicationsInSections`). Idempotent — if a
/// screen already supplied communications, they're kept as-is.
MenuDrawerSections withCommunicationsInSections(
  BuildContext context,
  MenuDrawerSections sections,
) {
  if (sections.communications.isNotEmpty) return sections;
  return MenuDrawerSections(
    actions: sections.actions,
    resources: sections.resources,
    communications: buildAdminCommunicationMenuItems(context),
  );
}

/// Communication menu items for the admin app menu drawer.
/// Mirrors the main KleenOps app's communication section exactly — 7 items in
/// the same order, each (except Calendar/Directory) carrying a live red badge
/// fed by the overlord member doc (see menu_badges.dart).
///
/// Order: Phone, Video Call, Text Message, Email, Message Board, Calendar,
/// Directory.
List<ContentMenuItem> buildAdminCommunicationMenuItems(BuildContext context) {
  return [
    ContentMenuItem(
      icon: Icons.phone_outlined,
      label: 'Phone',
      badge: menuBadge(missedVoiceCallBadgeProvider),
      onTap: () => context.push(AppRoutePaths.commPhone),
    ),
    ContentMenuItem(
      icon: Icons.video_camera_front,
      label: 'Video Call',
      badge: menuBadge(missedVideoCallBadgeProvider),
      onTap: () => context.push(AppRoutePaths.commVideoCall),
    ),
    ContentMenuItem(
      icon: Icons.chat_outlined,
      label: 'Text Message',
      badge: menuBadge(unreadTextBadgeProvider),
      onTap: () => context.push(AppRoutePaths.commInternalMessages),
    ),
    ContentMenuItem(
      icon: Icons.email_outlined,
      label: 'Email',
      badge: menuBadge(unreadEmailBadgeProvider),
      onTap: () => context.push(AppRoutePaths.commEmail),
    ),
    ContentMenuItem(
      icon: Icons.push_pin_outlined,
      label: 'Message Board',
      badge: menuBadge(unreadBulletinBadgeProvider),
      onTap: () => context.push(AppRoutePaths.commMessageBoard),
    ),
    ContentMenuItem(
      icon: Icons.calendar_today,
      label: 'Calendar',
      onTap: () => context.push(AppRoutePaths.commCalendar),
    ),
    ContentMenuItem(
      icon: Icons.perm_contact_cal,
      label: 'Directory',
      onTap: () => context.push(AppRoutePaths.commDirectory),
    ),
  ];
}
