// lib/features/inventory/screens/tasks_reports_inventory.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kleenops_admin/app/routes.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/details_appbar_adapter.dart';
import 'package:kleenops_admin/features/inventory/widgets/inventory_request_list.dart';

class TasksReportsInventoryScreen extends StatelessWidget {
  const TasksReportsInventoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const StandardAppBar(title: 'Inventory Requests'),
      body: const TasksReportsInventoryContent(),
      floatingActionButton: FloatingActionButton(
        // No dedicated tasks-reports route in admin — fall back to the
        // shared inventory request form.
        onPressed: () => context.push(AppRoutePaths.inventoryRequestForm),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class TasksReportsInventoryContent extends StatelessWidget {
  const TasksReportsInventoryContent({super.key});

  @override
  Widget build(BuildContext context) {
    return const InventoryRequestList(
      detailsRoute: AppRoutePaths.inventoryRequestForm,
    );
  }
}
