import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kleenops_admin/app/routes.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/details_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/home_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/home_navbar_adapter.dart';
import 'package:shared_widgets/containers/container_header.dart';
import 'package:kleenops_admin/widgets/labels/icon_text_checkbox.dart';
import 'package:shared_widgets/dialogs/dialog_action.dart';
import 'package:shared_widgets/containers/canvas_top_bookend.dart';
import 'package:shared_widgets/containers/standard_canvas.dart';
import 'package:shared_widgets/drawers/menu_drawer.dart';

class MarketingDataDetailsScreen extends StatefulWidget {
  final DocumentReference<Map<String, dynamic>> docRef;
  const MarketingDataDetailsScreen({super.key, required this.docRef});

  @override
  State<MarketingDataDetailsScreen> createState() =>
      _MarketingDataDetailsScreenState();
}

class _MarketingDataDetailsScreenState
    extends State<MarketingDataDetailsScreen> {
  Future<void> _showEditDialog(
      {required String currentName, required String currentDesc}) async {
    final nameCtl = TextEditingController(text: currentName);
    final descCtl = TextEditingController(text: currentDesc);
    await showDialog(
      context: context,
      builder: (ctx) => DialogAction(
        title: 'Edit Data',
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtl,
              decoration: const InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descCtl,
              decoration: const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        cancelText: 'Cancel',
        actionText: 'Save',
        onCancel: () => Navigator.of(ctx).pop(),
        onAction: () async {
          final name = nameCtl.text.trim();
          final desc = descCtl.text.trim();
          if (name.isEmpty) return;
          await widget.docRef.update({'name': name, 'description': desc});
          if (mounted) Navigator.of(ctx).pop();
        },
      ),
    );
  }

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
            title: 'Data Details',
            onAiPressed: onAiPressed,
            menuSections: menuSections,
          ),
          const HomeNavBarAdapter(highlightSelected: false),
        ],
      );
    }

    return Scaffold(
      appBar: null,
      bottomNavigationBar: hideChrome
          ? null
          : Consumer(
              builder: (context, ref, _) {
                final menuSections = MenuDrawerSections(
                  actions: [
                    ContentMenuItem(
                      icon: Icons.home_outlined,
                      label: 'Sales Home',
                      onTap: () => context.push(AppRoutePaths.salesHome),
                    ),
                    ContentMenuItem(
                      icon: Icons.sell_outlined,
                      label: 'Sales',
                      onTap: () => context.push(AppRoutePaths.salesSales),
                    ),
                    ContentMenuItem(
                      icon: Icons.campaign_outlined,
                      label: 'Marketing',
                      onTap: () => context.push(AppRoutePaths.salesMarketing),
                    ),
                    ContentMenuItem(
                      icon: Icons.bar_chart_outlined,
                      label: 'Stats',
                      onTap: () => context.push(AppRoutePaths.salesStats),
                    ),
                  ],
                );
                return buildBottomBar(
                  menuSections: menuSections,
                );
              },
            ),
      body: _wrapCanvas(
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: widget.docRef.snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final data = snapshot.data!.data() ?? {};
              final name = data['name'] as String? ?? '';
              final desc = data['description'] as String? ?? '';
              final firstName = data['firstName'] as bool? ?? false;
              final lastName = data['lastName'] as bool? ?? false;
              final email = data['email'] as bool? ?? false;
              final phone = data['phoneNumber'] as bool? ?? false;
              final company = data['company'] as bool? ?? false;
              final bottomPadding =
                  (hideChrome ? 16.0 : kBottomNavigationBarHeight + 16.0) +
                      MediaQuery.of(context).padding.bottom;

              return Stack(
                children: [
                  SingleChildScrollView(
                    padding: EdgeInsets.only(bottom: bottomPadding),
                    child: Column(
                      children: [
                        ContainerHeader(
                          titleHeader: 'MarketData',
                          title: name,
                          descriptionHeader: 'Description',
                          description: desc,
                          trailingChildren: [
                            IconTextCheckbox(
                              text: 'First Name',
                              value: firstName,
                              onChanged: (v) => widget.docRef
                                  .update({'firstName': v ?? false}),
                            ),
                            IconTextCheckbox(
                              text: 'Last Name',
                              value: lastName,
                              onChanged: (v) => widget.docRef
                                  .update({'lastName': v ?? false}),
                            ),
                            IconTextCheckbox(
                              text: 'Email',
                              value: email,
                              onChanged: (v) =>
                                  widget.docRef.update({'email': v ?? false}),
                            ),
                            IconTextCheckbox(
                              text: 'Phone Number',
                              value: phone,
                              onChanged: (v) => widget.docRef
                                  .update({'phoneNumber': v ?? false}),
                            ),
                            IconTextCheckbox(
                              text: 'Company',
                              value: company,
                              onChanged: (v) =>
                                  widget.docRef.update({'company': v ?? false}),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    right: 16,
                    bottom: 16,
                    child: FloatingActionButton(
                      heroTag: null,
                      child: const Icon(Icons.edit),
                      onPressed: () => _showEditDialog(
                        currentName: name,
                        currentDesc: desc,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
    );
  }
}
