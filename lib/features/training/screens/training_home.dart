// lib/features/training/screens/training_home.dart

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

/// Hub for the Training feature.
class TrainingHome extends StatelessWidget {
  const TrainingHome({super.key});

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
          DetailsAppBar(title: 'Training', menuSections: menuSections),
          const HomeNavBarAdapter(),
        ],
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: null,
      drawer: const UserDrawer(),
      body: _wrapCanvas(const TrainingHomeContent()),
      bottomNavigationBar: Consumer(
        builder: (context, ref, _) {
          final menuSections = MenuDrawerSections(
            actions: [
              ContentMenuItem(
                icon: Icons.groups_outlined,
                label: 'Teams',
                onTap: () => context.push(AppRoutePaths.trainingTeams),
              ),
              ContentMenuItem(
                icon: Icons.person_outline,
                label: 'Employees',
                onTap: () => context.push(AppRoutePaths.trainingEmployees),
              ),
            ],
          );
          return buildBottomBar(menuSections: menuSections);
        },
      ),
    );
  }
}

class TrainingHomeContent extends StatelessWidget {
  const TrainingHomeContent({super.key});

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
