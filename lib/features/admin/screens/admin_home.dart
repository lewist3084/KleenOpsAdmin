//  admin_home.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kleenops_admin/app/routes.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/menu_button_block_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/details_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/home_navbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/home_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/drawers/appbar_logout_adapter.dart';
import 'package:shared_widgets/containers/canvas_top_bookend.dart';
import 'package:shared_widgets/containers/standard_canvas.dart';
import 'package:shared_widgets/drawers/menu_drawer.dart';

/// Top-level screen with its own Scaffold (app bar + content + bottom nav)
class AdminHomeScreen extends StatelessWidget {
  const AdminHomeScreen({super.key});

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
    final bool hideChrome = false;

    Widget buildBottomBar({
      VoidCallback? onAiPressed,
      MenuDrawerSections? menuSections,
    }) {
      if (hideChrome) return const SizedBox.shrink();
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DetailsAppBar(
            title: 'Admin',
            onAiPressed: onAiPressed,
            menuSections: menuSections,
          ),
          const HomeNavBarAdapter(),
        ],
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: null,
      drawer: const UserDrawer(),
      body: _wrapCanvas(
          const AdminHomeContent(),
        ),
      bottomNavigationBar: Consumer(
        builder: (context, ref, _) {
          final menuSections = MenuDrawerSections(
            actions: [
              ContentMenuItem(
                icon: Icons.apartment_outlined,
                label: 'Company',
                onTap: () => context.push(AppRoutePaths.adminCompany),
              ),
              ContentMenuItem(
                icon: Icons.verified_user_outlined,
                label: 'Compliance',
                onTap: () => context.push(AppRoutePaths.adminCompliance),
              ),
              ContentMenuItem(
                icon: Icons.checklist_outlined,
                label: 'Compliance Dashboard',
                onTap: () => context.push(AppRoutePaths.adminCompliance),
              ),
              ContentMenuItem(
                icon: Icons.rocket_launch_outlined,
                label: 'Business Setup Wizard',
                onTap: () => context.push(AppRoutePaths.adminSetupWizard),
              ),
              ContentMenuItem(
                icon: Icons.policy_outlined,
                label: 'Policies',
                onTap: () => context.push(AppRoutePaths.adminPolicies),
              ),
            ],
          );
          return buildBottomBar(
            menuSections: menuSections,
          );
        },
      ),
    );
  }
}

class AdminHomeContent extends StatelessWidget {
  const AdminHomeContent({super.key}); // Already const constructor with Key

  @override
  Widget build(BuildContext context) {
    final bool hideChrome = false;
    final bottomInset =
        (hideChrome ? 16.0 : kBottomNavigationBarHeight + 16.0) +
            MediaQuery.of(context).padding.bottom;

    return SingleChildScrollView(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image or banner
          Container(
            width: double.infinity,
            color: Colors.white,
            padding: const EdgeInsets.only(top: 16.0),
            child: Center(
              child: Image.asset(
                'assets/sax.png',
                height: MediaQuery.of(context).size.height * 0.3,
                fit: BoxFit.contain,
              ),
            ),
          ),
          const MenuButtonBlock(), // Marked as const
        ],
      ),
    );
  }
}
