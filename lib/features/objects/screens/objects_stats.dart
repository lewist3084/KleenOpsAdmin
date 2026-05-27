// DEGRADED: Original used kleenops ContentAppBar/UserDrawer adapters.
// Simplified to use admin chrome.

import 'package:flutter/material.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/home_navbar_adapter.dart';

/// Top-level screen with its own Scaffold (app bar + content + bottom nav)
class ObjectsStatsScreen extends StatelessWidget {
  const ObjectsStatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: const ObjectsStatsContent(),
      bottomNavigationBar: const HomeNavBarAdapter(),
    );
  }
}

class ObjectsStatsContent extends StatelessWidget {
  const ObjectsStatsContent({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('Stats', style: TextStyle(fontSize: 20)),
    );
  }
}
