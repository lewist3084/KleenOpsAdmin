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
import 'package:shared_widgets/labels/header_info_icon_value.dart';
import 'package:shared_widgets/containers/canvas_top_bookend.dart';
import 'package:shared_widgets/containers/standard_canvas.dart';
import 'package:shared_widgets/drawers/menu_drawer.dart';
import '../screens/marketing_schedule.dart';

class MarketingDeliveryDetailsScreen extends StatelessWidget {
  final DocumentReference<Map<String, dynamic>> docRef;
  const MarketingDeliveryDetailsScreen({super.key, required this.docRef});

  DocumentReference<Map<String, dynamic>> get _companyRef =>
      docRef.parent.parent!;

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
            title: 'Delivery Details',
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
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final data = snapshot.data!.data() ?? {};
              final name = data['name'] as String? ?? '';
              final desc = data['description'] as String? ?? '';
              final frequency = data['frequency'] as String? ?? '';
              final days = List<String>.from(data['day'] ?? []);
              final weeks = List<String>.from(data['week'] ?? []);
              final months = List<String>.from(data['month'] ?? []);
              String timeStr = '';
              final ts = data['time'];
              if (ts is Timestamp) {
                final dt = ts.toDate();
                timeStr = TimeOfDay.fromDateTime(dt).format(context);
              }
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
                          showImage: false,
                          titleHeader: 'Name',
                          title: name,
                          descriptionHeader: 'Description',
                          description: desc,
                        ),
                        ContainerActionWidget(
                          title: 'Schedule',
                          actionText: '',
                          content: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              HeaderInfoIconValue(
                                header: 'Frequency',
                                value: frequency,
                                icon: Icons.repeat,
                              ),
                              const SizedBox(height: 8),
                              HeaderInfoIconValue(
                                header: 'Day',
                                value: days,
                                icon: Icons.calendar_today,
                              ),
                              const SizedBox(height: 8),
                              HeaderInfoIconValue(
                                header: 'Week',
                                value: weeks,
                                icon: Icons.calendar_view_week,
                              ),
                              const SizedBox(height: 8),
                              HeaderInfoIconValue(
                                header: 'Month',
                                value: months,
                                icon: Icons.date_range,
                              ),
                              const SizedBox(height: 8),
                              HeaderInfoIconValue(
                                header: 'Time',
                                value: timeStr,
                                icon: Icons.access_time,
                              ),
                            ],
                          ),
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
                      onPressed: () => showDeliveryScheduleDialog(
                        context: context,
                        companyRef: _companyRef,
                        docRef: docRef,
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
