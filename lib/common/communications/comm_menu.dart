import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kleenops_admin/app/routes.dart';
import 'package:shared_widgets/drawers/menu_drawer.dart';
import 'package:url_launcher/url_launcher.dart';

/// Communication menu items for the admin app menu drawer.
/// Mirrors the main KleenOps app's communication section.
List<ContentMenuItem> buildAdminCommunicationMenuItems(BuildContext context) {
  return [
    ContentMenuItem(
      icon: Icons.phone_outlined,
      label: 'Phone',
      onTap: () => launchUrl(Uri(scheme: 'tel')),
    ),
    ContentMenuItem(
      icon: Icons.headset_mic,
      label: 'Intercom',
      onTap: () => context.push(AppRoutePaths.commIntercom),
    ),
    ContentMenuItem(
      icon: Icons.video_camera_front,
      label: 'Video Call',
      onTap: () => context.push(AppRoutePaths.commVideoCall),
    ),
    ContentMenuItem(
      icon: Icons.chat_outlined,
      label: 'Internal Messages',
      onTap: () => context.push(AppRoutePaths.commInternalMessages),
    ),
    ContentMenuItem(
      icon: Icons.sms_outlined,
      label: 'External Messages',
      onTap: () => context.push(AppRoutePaths.commExternalMessages),
    ),
    ContentMenuItem(
      icon: Icons.push_pin_outlined,
      label: 'Message Board',
      onTap: () => context.push(AppRoutePaths.commMessageBoard),
    ),
    ContentMenuItem(
      icon: Icons.email_outlined,
      label: 'Email',
      onTap: () => context.push(AppRoutePaths.commEmail),
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
