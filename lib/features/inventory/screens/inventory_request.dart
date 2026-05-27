// lib/features/inventory/screens/inventory_request.dart

import 'package:flutter/material.dart';
import 'package:kleenops_admin/app/routes.dart';
import 'package:kleenops_admin/features/inventory/widgets/inventory_request_list.dart';

class InventoryRequestContent extends StatelessWidget {
  const InventoryRequestContent({super.key});

  @override
  Widget build(BuildContext context) {
    // detailsRoute placeholder — admin has no inventoryRequestDetails route yet.
    return const InventoryRequestList(
      detailsRoute: AppRoutePaths.inventoryRequestForm,
    );
  }
}
