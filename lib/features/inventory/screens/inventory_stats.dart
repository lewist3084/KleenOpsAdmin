// lib/features/inventory/screens/inventory_stats.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kleenops_admin/app/routes.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/details_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/home_navbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/drawers/appbar_logout_adapter.dart';
import 'package:shared_widgets/containers/canvas_top_bookend.dart';
import 'package:shared_widgets/containers/standard_canvas.dart';
import 'package:shared_widgets/drawers/menu_drawer.dart';

/// Top-level screen with its own Scaffold (app bar + content + bottom nav)
class InventoryStatsScreen extends StatelessWidget {
  const InventoryStatsScreen({super.key});

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
    Widget buildBottomBar({
      MenuDrawerSections? menuSections,
    }) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DetailsAppBar(
            title: 'Inventory Stats',
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
        const InventoryStatsContent(),
      ),
      bottomNavigationBar: Consumer(
        builder: (context, ref, _) {
          final menuSections = MenuDrawerSections(
            actions: [
              ContentMenuItem(
                icon: Icons.inventory_2_outlined,
                label: 'Fulfillment',
                onTap: () => context.push(AppRoutePaths.inventoryFulfillment),
              ),
              ContentMenuItem(
                icon: Icons.home_outlined,
                label: 'Inventory Home',
                onTap: () => context.push(AppRoutePaths.inventoryHome),
              ),
              ContentMenuItem(
                icon: Icons.playlist_add,
                label: 'New Request',
                onTap: () => context.push(AppRoutePaths.inventoryRequestForm),
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

class InventoryStatsContent extends StatelessWidget {
  const InventoryStatsContent({super.key});

  @override
  Widget build(BuildContext context) {
    const bottomInset = 16.0;

    return Padding(
      padding: const EdgeInsets.only(bottom: bottomInset),
      child: const Center(
        child: Text('Stats Content', style: TextStyle(fontSize: 20)),
      ),
    );
  }
}
