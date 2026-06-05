import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kleenops_admin/app/shared_widgets/navigation/details_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/home_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/home_navbar_adapter.dart';
import 'package:kleenops_admin/services/ai/ai_context_service.dart';
import 'package:kleenops_admin/widgets/layout/bookended_canvas.dart';
import 'package:shared_widgets/drawers/menu_drawer.dart';

/// Placeholder for external SMS messaging via Twilio.
///
/// When Twilio SMS integration is added, this screen will display SMS
/// conversations with external contacts using provisioned business phone
/// numbers, similar to the internal messaging flow.
class ExternalMessagesScreen extends ConsumerWidget {
  const ExternalMessagesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(aiCanvasControllerProvider);
    final menuSections = MenuDrawerSections(
      actions: const <ContentMenuItem>[],
      resources: const <ContentMenuItem>[],
    );

    return Scaffold(
      body: BookendedCanvas(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.sms_outlined, size: 80, color: Colors.grey.shade400),
                const SizedBox(height: 24),
                Text(
                  'External Messaging',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'SMS messaging with external contacts will be available '
                  'once a business phone number is provisioned and Twilio SMS '
                  'integration is configured.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DetailsAppBar(
            title: 'External Messages',
            onAiPressed: controller.toggle,
            menuSections: menuSections,
          ),
          const HomeNavBarAdapter(),
        ],
      ),
    );
  }
}

