// lib/screens/hr/hr_home.dart

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
class HrHomeScreen extends StatelessWidget {
  const HrHomeScreen({super.key});

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
            title: 'HR',
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
          const HrHomeContent(),
        ),
      bottomNavigationBar: Consumer(
        builder: (context, ref, _) {
          final menuSections = MenuDrawerSections(
            actions: [
              ContentMenuItem(
                icon: Icons.person_add_outlined,
                label: 'Onboarding',
                onTap: () => context.push(AppRoutePaths.hrOnboarding),
              ),
              ContentMenuItem(
                icon: Icons.badge_outlined,
                label: 'Employees',
                onTap: () => context.push(AppRoutePaths.hrEmployees),
              ),
              ContentMenuItem(
                icon: Icons.groups_outlined,
                label: 'Teams',
                onTap: () => context.push(AppRoutePaths.hrTeam),
              ),
              ContentMenuItem(
                icon: Icons.badge,
                label: 'Roles',
                onTap: () => context.push(AppRoutePaths.hrRoles),
              ),
              ContentMenuItem(
                icon: Icons.health_and_safety_outlined,
                label: 'Benefits',
                onTap: () => context.push(AppRoutePaths.hrBenefits),
              ),
              ContentMenuItem(
                icon: Icons.calendar_month_outlined,
                label: 'Time Off',
                onTap: () => context.push(AppRoutePaths.hrTimeOff),
              ),
              ContentMenuItem(
                icon: Icons.description_outlined,
                label: 'Documents',
                onTap: () => context.push(AppRoutePaths.hrDocuments),
              ),
              ContentMenuItem(
                icon: Icons.bar_chart_outlined,
                label: 'Stats',
                onTap: () => context.push(AppRoutePaths.hrStats),
              ),
              ContentMenuItem(
                icon: Icons.qr_code_scanner,
                label: 'Scan Ticket',
                onTap: () => context.push(AppRoutePaths.hrTicketScanner),
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

class HrHomeContent extends StatelessWidget {
  const HrHomeContent({super.key});

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
          // Example: If you want a button to go to Employees
          // ElevatedButton(
          //   onPressed: () => context.push('/hr/employees'),
          //   child: Text('Go to Employees'),
          // ),

          // If you still want the old menu, keep it:
          const MenuButtonBlock(),
        ],
      ),
    );
  }
}
