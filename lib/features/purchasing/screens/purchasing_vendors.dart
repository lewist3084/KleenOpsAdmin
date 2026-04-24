import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:kleenops_admin/app/routes.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/details_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/home_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/home_navbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/drawers/appbar_logout_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/search/search_control_strip_adapter.dart';
import 'package:shared_widgets/tiles/standard_tile_small.dart';
import 'package:shared_widgets/lists/standardView.dart';
import 'package:shared_widgets/dialogs/dialog_action.dart';
import 'package:kleenops_admin/features/auth/providers/auth_provider.dart';
import 'package:kleenops_admin/features/purchasing/tabs/object_vendor_tabs.dart';
import 'package:shared_widgets/services/firestore_service.dart';
import 'package:shared_widgets/containers/canvas_top_bookend.dart';
import 'package:shared_widgets/containers/standard_canvas.dart';
import 'package:shared_widgets/drawers/menu_drawer.dart';

/// Top-level screen with its own Scaffold (app bar + content + bottom nav)
class PurchasingVendorsScreen extends StatefulWidget {
  const PurchasingVendorsScreen({super.key});

  @override
  State<PurchasingVendorsScreen> createState() =>
      _PurchasingVendorsScreenState();
}

class _PurchasingVendorsScreenState extends State<PurchasingVendorsScreen> {
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
            title: 'Vendors',
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
            child: PurchasingVendorsContent(searchVisible: _searchVisible),
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
                icon: Icons.bar_chart_outlined,
                label: 'Stats',
                onTap: () => context.push(AppRoutePaths.purchasingStats),
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

class PurchasingVendorsContent extends ConsumerStatefulWidget {
  const PurchasingVendorsContent({super.key, this.searchVisible = false});

  final bool searchVisible;

  @override
  ConsumerState<PurchasingVendorsContent> createState() =>
      _PurchasingVendorsContentState();
}

class _PurchasingVendorsContentState
    extends ConsumerState<PurchasingVendorsContent> {
  final TextEditingController _searchCtl = TextEditingController();
  String _search = '';

  @override
  void dispose() {
    _searchCtl.dispose();
    super.dispose();
  }

  Future<void> _showAddDialog(
    BuildContext context,
    DocumentReference<Map<String, dynamic>> companyRef,
  ) async {
    final controller = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => DialogAction(
        title: 'New Vendor',
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Name'),
        ),
        cancelText: 'Cancel',
        onCancel: () => Navigator.of(ctx).pop(),
        actionText: 'Add',
        showActionButton: true,
        onAction: () async {
          final name = controller.text.trim();
          if (name.isNotEmpty) {
            final col = FirebaseFirestore.instance.collection('companyCompany');
            final meta = await FirestoreService().buildCreateMeta(col);
            await col.add({'name': name, ...meta});
          }
          Navigator.of(ctx).pop();
        },
      ),
    );
  }

  void _openVendorDetails(
    BuildContext context,
    DocumentReference<Map<String, dynamic>> companyRef,
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute(
        settings: RouteSettings(
          name: '/purchasing/vendor/${doc.id}',
        ),
        builder: (_) => ObjectVendorTabsScreen(
          companyId: companyRef,
          docId: doc.id,
        ),
      ),
    );
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

        final queryStream =
            FirebaseFirestore.instance.collection('companyCompany').orderBy('name').snapshots();

        final list = StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: queryStream,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final docs = snapshot.data!.docs.where((doc) {
              final name = (doc.data()['name'] ?? '').toString().toLowerCase();
              return name.contains(_search.toLowerCase());
            }).toList();

            if (docs.isEmpty) {
              return const Center(child: Text('No vendors found.'));
            }

            return StandardView<QueryDocumentSnapshot<Map<String, dynamic>>>(
              items: docs,
              groupBy: (_) => null,
              headerIcon: null,
              disableGrouping: true,
              onTap: (doc) => _openVendorDetails(context, companyRef, doc),
              itemBuilder: (doc) {
                final name = doc.data()['name'] as String? ?? '';
                return StandardTileSmallDart.iconText(
                  leadingicon: Icons.store_outlined,
                  text: name,
                );
              },
            );
          },
        );

        return Stack(
          children: [
            Column(
              children: [
                if (widget.searchVisible)
                  SearchControlStrip(
                    controller: _searchCtl,
                    hintText: 'SearchÆ’?Ä°',
                    onChanged: (t) => setState(() => _search = t.trim()),
                  ),
                Expanded(child: list),
              ],
            ),
            Positioned(
              right: 16,
              bottom: 16,
              child: FloatingActionButton(
                heroTag: null,
                child: const Icon(Icons.add),
                onPressed: () => _showAddDialog(context, companyRef),
              ),
            ),
          ],
        );
      },
    );
  }
}
