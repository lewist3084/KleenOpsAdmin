// lib/features/processes/screens/processes_home.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kleenops_admin/app/routes.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/menu_button_block_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/details_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/home_navbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/drawers/appbar_logout_adapter.dart';
import 'package:shared_widgets/containers/canvas_top_bookend.dart';
import 'package:shared_widgets/containers/standard_canvas.dart';
import 'package:shared_widgets/drawers/menu_drawer.dart';

/// Hub for the Processes feature.
class ProcessesHome extends StatelessWidget {
  const ProcessesHome({super.key});

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
    Widget buildBottomBar({MenuDrawerSections? menuSections}) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DetailsAppBar(title: 'Processes', menuSections: menuSections),
          const HomeNavBarAdapter(),
        ],
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: null,
      drawer: const UserDrawer(),
      body: _wrapCanvas(const ProcessesHomeContent()),
      bottomNavigationBar: Consumer(
        builder: (context, ref, _) {
          final menuSections = MenuDrawerSections(
            actions: [
              ContentMenuItem(
                icon: Icons.route_outlined,
                label: 'Processes',
                onTap: () => context.push(AppRoutePaths.processesTabs),
              ),
              ContentMenuItem(
                icon: Icons.category_outlined,
                label: 'Categories',
                onTap: () => context.push(AppRoutePaths.processesCategoryList),
              ),
              ContentMenuItem(
                icon: Icons.straighten_outlined,
                label: 'Measurements',
                onTap: () => context.push(AppRoutePaths.processesMeasurements),
              ),
              ContentMenuItem(
                icon: Icons.bar_chart_outlined,
                label: 'Stats',
                onTap: () => context.push(AppRoutePaths.processesStats),
              ),
            ],
          );
          return buildBottomBar(menuSections: menuSections);
        },
      ),
    );
  }
}

class ProcessesHomeContent extends StatelessWidget {
  const ProcessesHomeContent({super.key});

  @override
  Widget build(BuildContext context) {
    const bottomInset = 16.0;
    return SingleChildScrollView(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [MenuButtonBlock()],
      ),
    );
  }
}
