// lib/features/inventory/screens/inventory_stats.dart

import 'package:flutter/material.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/details_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/home_navbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/drawers/appbar_logout_adapter.dart';
import 'package:shared_widgets/containers/canvas_top_bookend.dart';
import 'package:shared_widgets/containers/standard_canvas.dart';

class InventoryStatsScreen extends StatelessWidget {
  const InventoryStatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      drawer: const UserDrawer(),
      body: StandardCanvas(
        child: SafeArea(
          top: true,
          bottom: false,
          child: Stack(
            children: [
              const Positioned.fill(
                child: Center(
                  child: Text(
                    'Inventory analytics will appear here.',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              ),
              const Positioned(
                left: 0, right: 0, top: 0,
                child: CanvasTopBookend(),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const DetailsAppBar(title: 'Inventory Stats'),
          const HomeNavBarAdapter(),
        ],
      ),
    );
  }
}
