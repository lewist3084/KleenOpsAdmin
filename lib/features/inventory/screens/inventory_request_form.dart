// lib/features/inventory/screens/inventory_request_form.dart
//
// Wrapper screen for the InventoryRequestForm widget so the admin
// router can land directly on it.

import 'package:flutter/material.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/details_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/home_navbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/drawers/appbar_logout_adapter.dart';
import 'package:kleenops_admin/features/inventory/forms/inventory_request_form.dart';

class InventoryRequestFormScreen extends StatelessWidget {
  const InventoryRequestFormScreen({super.key, this.docId});

  final String? docId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      drawer: const UserDrawer(),
      body: InventoryRequestForm(docId: docId),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const DetailsAppBar(title: 'New Request'),
          const HomeNavBarAdapter(),
        ],
      ),
    );
  }
}
