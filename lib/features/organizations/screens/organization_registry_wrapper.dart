// lib/features/organizations/screens/organization_registry_wrapper.dart
//
// Chrome wrapper for the overlord organization registry (mirrors
// BrandOwnersWrapper): StandardCanvas + bookend, UserDrawer, DetailsAppBar.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/details_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/home_navbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/drawers/appbar_logout_adapter.dart';
import 'package:shared_widgets/containers/canvas_top_bookend.dart';
import 'package:shared_widgets/containers/standard_canvas.dart';
import 'package:shared_widgets/drawers/menu_drawer.dart';

import 'organization_registry_screen.dart';

class OrganizationRegistryWrapper extends StatelessWidget {
  const OrganizationRegistryWrapper({super.key});

  Widget _wrapCanvas(Widget child) {
    return StandardCanvas(
      child: SafeArea(
        top: true,
        bottom: false,
        child: Stack(
          children: [
            Positioned.fill(child: child),
            const Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: CanvasTopBookend(),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: null,
      drawer: const UserDrawer(),
      body: _wrapCanvas(const OrganizationRegistryScreen()),
      bottomNavigationBar: Consumer(
        builder: (context, ref, _) {
          final menuSections = MenuDrawerSections(actions: const []);
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DetailsAppBar(title: 'Organizations', menuSections: menuSections),
              const HomeNavBarAdapter(),
            ],
          );
        },
      ),
    );
  }
}
