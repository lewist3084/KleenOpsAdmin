// lib/features/purchasing/tabs/object_vendor_tabs.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/details_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/home_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/home_navbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/drawers/appbar_logout_adapter.dart';
import 'package:shared_widgets/containers/canvas_top_bookend.dart';
import 'package:shared_widgets/containers/standard_canvas.dart';
import 'package:shared_widgets/drawers/menu_drawer.dart';
import 'package:shared_widgets/tabs/standard_tab.dart';
import '../details/purchasing_vendor_details.dart';

class ObjectVendorTabsScreen extends StatelessWidget {
  final DocumentReference<Map<String, dynamic>> companyId;
  final String docId;

  const ObjectVendorTabsScreen({
    super.key,
    required this.companyId,
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
    final bool hideChrome = false;

    Widget buildBottomBar({VoidCallback? onAiPressed}) {
      if (hideChrome) return const SizedBox.shrink();
      final menuSections = MenuDrawerSections(
      );
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DetailsAppBar(
            title: 'Vendor Details',
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
                return buildBottomBar();
              },
            ),
      body: _wrapCanvas(
          ObjectVendorTabs(companyId: companyId, docId: docId),
        ),
    );
  }
}

class ObjectVendorTabs extends StatefulWidget {
  final DocumentReference<Map<String, dynamic>> companyId;
  final String docId;

  const ObjectVendorTabs({
    super.key,
    required this.companyId,
    required this.docId,
  });

  @override
  State<ObjectVendorTabs> createState() => _ObjectVendorTabsState();
}

class _ObjectVendorTabsState extends State<ObjectVendorTabs>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }



  @override
  Widget build(BuildContext context) {
    final bool hideChrome = false;
    final bottomInset =
        (hideChrome ? 16.0 : kBottomNavigationBarHeight + 16.0) +
            MediaQuery.of(context).padding.bottom;

    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Container(
            color: Colors.white,
            child: StandardTabBar(
              controller: _tabController,
              isScrollable: true,
              dividerColor: Colors.grey[300],
              indicatorColor: Theme.of(context).primaryColor,
              indicatorWeight: 3,
              labelColor: Colors.black,
              unselectedLabelColor: Colors.grey[600],
              tabs: const [
                Tab(text: 'Details'),
                Tab(text: 'Charts'),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: bottomInset),
              child: TabBarView(
                physics: const NeverScrollableScrollPhysics(),
                controller: _tabController,
                children: [
                  PurchasingVendorDetails(
                    companyId: widget.companyId,
                    docId: widget.docId,
                  ),
                  const Center(child: Text('Charts Content')),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
