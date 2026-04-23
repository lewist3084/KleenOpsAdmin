// purchasing_requests.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:kleenops_admin/app/routes.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/details_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/home_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/home_navbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/drawers/appbar_logout_adapter.dart';
import 'package:shared_widgets/search/search_control_strip.dart';
import 'package:shared_widgets/lists/standardViewGroup.dart';
import 'package:shared_widgets/tiles/standard_tile_small.dart';
import 'package:kleenops_admin/features/auth/providers/auth_provider.dart';
import 'package:shared_widgets/containers/canvas_top_bookend.dart';
import 'package:shared_widgets/containers/standard_canvas.dart';
import 'package:shared_widgets/drawers/menu_drawer.dart';

class PurchasingRequestsScreen extends StatefulWidget {
  const PurchasingRequestsScreen({super.key});

  @override
  State<PurchasingRequestsScreen> createState() =>
      _PurchasingRequestsScreenState();
}

class _PurchasingRequestsScreenState extends State<PurchasingRequestsScreen> {
  bool _searchVisible = false;

  void _toggleSearch() => setState(() => _searchVisible = !_searchVisible);

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
    final bottomInset =
        (hideChrome ? 16.0 : kBottomNavigationBarHeight + 16.0) +
            MediaQuery.of(context).padding.bottom;

    Widget buildBottomBar({
      VoidCallback? onAiPressed,
      MenuDrawerSections? menuSections,
    }) {
      if (hideChrome) return const SizedBox.shrink();
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DetailsAppBar(
            title: 'Purchasing Requests',
            onAiPressed: onAiPressed,
            menuSections: menuSections,
            onSearchToggle: _toggleSearch,
            searchActive: _searchVisible,
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
          Padding(
            padding: EdgeInsets.only(bottom: bottomInset),
            child: PurchasingRequestsContent(searchVisible: _searchVisible),
          ),
        ),
      bottomNavigationBar: Consumer(
        builder: (context, ref, _) {
          final menuSections = MenuDrawerSections(
            actions: [
              ContentMenuItem(
                icon: Icons.receipt_long_outlined,
                label: 'Orders',
                onTap: () => context.push(AppRoutePaths.purchasingOrders),
              ),
              ContentMenuItem(
                icon: Icons.inventory_2_outlined,
                label: 'Objects',
                onTap: () => context.push(AppRoutePaths.purchasingObjects),
              ),
              ContentMenuItem(
                icon: Icons.store_outlined,
                label: 'Vendors',
                onTap: () => context.push(AppRoutePaths.purchasingVendors),
              ),
              ContentMenuItem(
                icon: Icons.home_outlined,
                label: 'Purchasing Home',
                onTap: () => context.push(AppRoutePaths.purchasingHome),
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

class PurchasingRequestsContent extends ConsumerStatefulWidget {
  const PurchasingRequestsContent({super.key, this.searchVisible = false});

  final bool searchVisible;

  @override
  ConsumerState<PurchasingRequestsContent> createState() =>
      _PurchasingRequestsContentState();
}

class _PurchasingRequestsContentState
    extends ConsumerState<PurchasingRequestsContent> {
  final TextEditingController _searchCtl = TextEditingController();
  String _search = '';

  @override
  void dispose() {
    _searchCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final companyAsync = ref.watch(companyIdProvider);

    return companyAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (companyRef) {
        if (companyRef == null) {
          return const Center(child: Text('No company found.'));
        }

        final categoryRef = FirebaseFirestore.instance
            .collection('timelineCategory')
            .doc('pfT7WgqMpTJHvBKerSXa');

        final query = FirebaseFirestore.instance
            .collection('timeline')
            .where('timelineCategoryId', isEqualTo: categoryRef)
            .orderBy('createdAt', descending: true);

        final list = StandardViewGroup(
          queryStream: query.snapshots(),
          groupBy: (doc) {
            final ts = doc.data()['createdAt'] as Timestamp?;
            if (ts == null) return 'Unknown';
            return DateFormat('yMMMd').format(ts.toDate());
          },
          groupSort: (a, b) => b.compareTo(a),
          headerIcon: null,
          itemBuilder: (doc) {
            final data = doc.data();
            final name = data['name'] ?? '';
            return StandardTileSmallDart.iconText(
              leadingicon: Icons.receipt_long_outlined,
              text: name,
            );
          },
        );

        return Column(
          children: [
            if (widget.searchVisible)
              SearchControlStrip(
                controller: _searchCtl,
                hintText: 'Search…',
                onChanged: (t) => setState(() => _search = t.trim()),
              ),
            Expanded(child: list),
          ],
        );
      },
    );
  }
}


