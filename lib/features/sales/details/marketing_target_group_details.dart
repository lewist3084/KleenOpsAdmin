import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kleenops_admin/app/routes.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/details_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/home_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/home_navbar_adapter.dart';
import 'package:shared_widgets/containers/container_header.dart';
import 'package:shared_widgets/containers/container_action.dart';
import 'package:shared_widgets/lists/standardViewGroup.dart';
import 'package:shared_widgets/tiles/standard_tile_large.dart';
import 'package:shared_widgets/containers/canvas_top_bookend.dart';
import 'package:shared_widgets/containers/standard_canvas.dart';
import 'package:shared_widgets/drawers/menu_drawer.dart';

class MarketingTargetGroupDetailsScreen extends StatelessWidget {
  final DocumentReference<Map<String, dynamic>> companyRef;
  final String docId;
  const MarketingTargetGroupDetailsScreen({
    super.key,
    required this.companyRef,
    required this.docId,
  });

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
    final docRef = FirebaseFirestore.instance.collection('targetGroup').doc(docId);
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
            title: 'Target Group Details',
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
            stream: docRef.snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }
              if (!snapshot.hasData || !snapshot.data!.exists) {
                return const Center(child: CircularProgressIndicator());
              }
              final data = snapshot.data!.data()!;
              final name = data['name'] as String? ?? '';
              final desc = data['description'] as String? ?? '';
              final bottomPadding =
                  (hideChrome ? 16.0 : kBottomNavigationBarHeight + 16.0) +
                      MediaQuery.of(context).padding.bottom;

              final customerQuery = docRef.collection('customer').orderBy('name');

              final customerList = StandardViewGroup(
                queryStream: customerQuery.snapshots(),
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                groupBy: (_) => '',
                itemBuilder: (custDoc) {
                  final custData = custDoc.data();
                  final custName = custData['name'] as String? ?? '';
                  return StandardTileLargeDart(
                    imageUrl: '',
                    firstLine: custName,
                    firstLineIcon: Icons.person_outline,
                  );
                },
                emptyMessage: 'No customers found.',
              );

              return SingleChildScrollView(
                padding: EdgeInsets.only(bottom: bottomPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ContainerHeader(
                      showImage: false,
                      titleHeader: 'Name',
                      title: name,
                      descriptionHeader: 'Description',
                      description: desc,
                    ),
                    ContainerActionWidget(
                      title: 'Customers',
                      actionText: '',
                      content: customerList,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
    );
  }
}




